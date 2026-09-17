-- ─────────────────────────────────────────────────────────────────────────────
-- 034: desativação de conta (LGPD) + visibilidade por evento/viagem
--
-- PARTE 1 — Desativação
-- A lei brasileira exige guardar os dados por pelo menos 6 meses, então
-- "excluir perfil" não apaga: desliga. Os dados pessoais saem de `profiles` e
-- vão para `profiles_archive`, que NINGUÉM lê — nem anônimo, nem logado (RLS
-- ligada e nenhuma policy; só o service_role ignora RLS). É essa tabela que
-- cumpre a retenção. Em `profiles` fica "Usuário inativo" e o resto em branco.
--
-- Anonimizar só no app Flutter não serviria: qualquer um com a chave anônima
-- continuaria lendo nome, bio e fotos pela API REST.
--
-- PARTE 2 — Visibilidade
-- Sai o interruptor único do motoclube (`clubs.events_public`); cada evento e
-- cada viagem passa a ter o seu. O trigger que herdava a visibilidade do clube
-- SOBRESCREVIA o valor enviado, então a escolha da tela seria descartada.
-- ─────────────────────────────────────────────────────────────────────────────

-- ══ PARTE 1: DESATIVAÇÃO ════════════════════════════════════════════════════

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_profiles_deactivated
  ON profiles(deactivated_at) WHERE deactivated_at IS NOT NULL;

-- Retenção legal. Sem nenhuma policy de propósito: RLS ligada + zero policies
-- = ninguém lê pela API. Só o service_role (worker/psql) enxerga.
CREATE TABLE IF NOT EXISTS profiles_archive (
  id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  data           JSONB NOT NULL,
  deactivated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE profiles_archive ENABLE ROW LEVEL SECURITY;

-- ── Desativar a própria conta ───────────────────────────────
CREATE OR REPLACE FUNCTION public.deactivate_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'É preciso estar logado para desativar a conta';
  END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE id = uid AND deactivated_at IS NOT NULL) THEN
    RETURN; -- já está desativada
  END IF;

  INSERT INTO profiles_archive (id, data, deactivated_at)
  SELECT p.id, to_jsonb(p), NOW() FROM profiles p WHERE p.id = uid
  ON CONFLICT (id) DO UPDATE
    SET data = EXCLUDED.data, deactivated_at = EXCLUDED.deactivated_at;

  UPDATE profiles SET
    name        = 'Usuário inativo',
    -- username é UNIQUE NOT NULL: não pode ficar nulo nem repetir.
    username    = 'inativo_' || left(replace(uid::text, '-', ''), 12),
    avatar_url  = NULL,
    bio         = NULL,
    city        = NULL,
    moto_model  = NULL,
    moto_year   = NULL,
    trip_style  = NULL,
    photos      = '{}',
    business_name               = NULL,
    business_description        = NULL,
    business_banner_url         = NULL,
    business_address_street     = NULL,
    business_address_number     = NULL,
    business_address_neighborhood = NULL,
    business_address_city       = NULL,
    business_address_state      = NULL,
    business_categories         = '{}',
    discoverable = FALSE,   -- some da busca por proximidade
    is_private   = TRUE,
    is_online    = FALSE,
    deactivated_at = NOW()
  WHERE id = uid;

  -- Localização e push: desligamento total.
  DELETE FROM rider_locations WHERE user_id = uid;
  DELETE FROM device_tokens   WHERE user_id = uid;
END; $$;

REVOKE ALL ON FUNCTION public.deactivate_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deactivate_my_account() TO authenticated;

-- ── Reativar ao voltar a logar ──────────────────────────────
CREATE OR REPLACE FUNCTION public.reactivate_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); d JSONB;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'É preciso estar logado para reativar a conta';
  END IF;
  SELECT data INTO d FROM profiles_archive WHERE id = uid;
  IF d IS NULL THEN RETURN; END IF;

  UPDATE profiles SET
    name        = COALESCE(d->>'name', name),
    username    = COALESCE(d->>'username', username),
    avatar_url  = d->>'avatar_url',
    bio         = d->>'bio',
    city        = d->>'city',
    moto_model  = d->>'moto_model',
    moto_year   = d->>'moto_year',
    trip_style  = d->>'trip_style',
    photos      = COALESCE(
                    ARRAY(SELECT jsonb_array_elements_text(d->'photos')),
                    '{}'),
    business_name               = d->>'business_name',
    business_description        = d->>'business_description',
    business_banner_url         = d->>'business_banner_url',
    business_address_street     = d->>'business_address_street',
    business_address_number     = d->>'business_address_number',
    business_address_neighborhood = d->>'business_address_neighborhood',
    business_address_city       = d->>'business_address_city',
    business_address_state      = d->>'business_address_state',
    business_categories         = COALESCE(
                    ARRAY(SELECT jsonb_array_elements_text(d->'business_categories')),
                    '{}'),
    discoverable = COALESCE((d->>'discoverable')::boolean, TRUE),
    is_private   = COALESCE((d->>'is_private')::boolean, FALSE),
    deactivated_at = NULL
  WHERE id = uid;

  DELETE FROM profiles_archive WHERE id = uid;
END; $$;

REVOKE ALL ON FUNCTION public.reactivate_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reactivate_my_account() TO authenticated;

-- ── Apagar de vez depois da retenção ────────────────────────
-- Chamada por tarefa agendada na VPS (o pg_cron não está instalado e exigiria
-- reiniciar o Postgres). Apagar de auth.users cascateia para profiles e
-- profiles_archive.
CREATE OR REPLACE FUNCTION public.purge_deactivated_accounts(
  older_than INTERVAL DEFAULT '6 months'
) RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n INT;
BEGIN
  WITH alvos AS (
    SELECT id FROM profiles
    WHERE deactivated_at IS NOT NULL AND deactivated_at < NOW() - older_than
  ), apagados AS (
    DELETE FROM auth.users WHERE id IN (SELECT id FROM alvos) RETURNING 1
  )
  SELECT count(*) INTO n FROM apagados;
  RETURN n;
END; $$;

-- ATENCAO: revogar de PUBLIC NAO basta. O Supabase concede EXECUTE direto aos
-- papeis `anon` e `authenticated` em toda funcao nova do schema `public`, e
-- REVOKE ... FROM PUBLIC nao mexe em concessao direta a um papel. Sem as linhas
-- abaixo, qualquer pessoa com a chave anonima chamaria estas funcoes.
REVOKE ALL ON FUNCTION public.purge_deactivated_accounts(INTERVAL)
  FROM PUBLIC, anon, authenticated;

-- ══ PARTE 2: VISIBILIDADE POR EVENTO E POR VIAGEM ═══════════════════════════

-- O trigger herdava do clube e sobrescrevia o que a tela mandasse.
DROP TRIGGER IF EXISTS trg_event_visibility     ON events;
DROP TRIGGER IF EXISTS trg_sync_club_events_vis ON clubs;
DROP FUNCTION IF EXISTS public.set_event_visibility();
DROP FUNCTION IF EXISTS public.sync_club_events_visibility();

-- Viagem ganha o mesmo interruptor do evento.
ALTER TABLE trips ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true;
CREATE INDEX IF NOT EXISTS idx_trips_public ON trips(is_public);

-- Backfill: viagem de clube herda a visibilidade que o clube tinha até agora;
-- viagem pessoal continua pública.
UPDATE trips t SET is_public = COALESCE(
  (SELECT c.events_public FROM clubs c WHERE c.id = t.club_id), TRUE)
WHERE t.club_id IS NOT NULL;

-- ── Policies ────────────────────────────────────────────────
-- Inclui o CRIADOR: sem isso, um evento pessoal marcado como privado ficaria
-- invisível até para quem o criou.
DROP POLICY IF EXISTS "events_select" ON events;
CREATE POLICY "events_select" ON events FOR SELECT
  USING (
    is_public
    OR creator_id = auth.uid()
    OR (club_id IS NOT NULL AND public.is_club_member(club_id, auth.uid()))
  );

DROP POLICY IF EXISTS "trips_select" ON trips;
CREATE POLICY "trips_select" ON trips FOR SELECT
  USING (
    is_public
    OR creator_id = auth.uid()
    OR EXISTS (SELECT 1 FROM trip_participants tp
               WHERE tp.trip_id = trips.id AND tp.user_id = auth.uid())
    OR (club_id IS NOT NULL AND public.is_club_member(club_id, auth.uid()))
  );

-- `clubs.events_public` fica no banco por ora, sem uso: some da interface
-- nesta entrega e a coluna é removida numa migration seguinte, depois de
-- confirmado que nada mais a lê. Derrubar coluna é irreversível.
