-- 042 — "Perfil privado" passa a existir no servidor
--
-- Até aqui o interruptor era só de tela: `friend_profile_screen.dart` buscava o
-- perfil INTEIRO e depois escondia. O dado já tinha saído do servidor — aparecia
-- na aba de rede do navegador, e uma chamada direta ao PostgREST devolvia bio,
-- cidade, moto e fotos mesmo com o perfil marcado como privado.
--
-- Por que não fechar `profiles` inteira: `profiles_select USING (true)` é
-- INTENCIONAL. O perfil público de um motociclista mostra motoclubes, viagens
-- concluídas e estilo — é o produto. Além disso 12 consultas do app trazem
-- `profiles(*)` embutido (criador do evento, participantes do rolê, remetente da
-- mensagem); fechar a tabela apagaria o nome das pessoas de metade das telas.
--
-- Então a divisão é por SENSIBILIDADE, não por tabela:
--   profiles         → identidade pública: nome, @, foto, contadores, negócio
--   profile_details  → o que o interruptor promete esconder
--
-- `business_*` fica em `profiles` de propósito: perfil comercial existe para ser
-- encontrado; escondê-lo seria contra a própria finalidade.

-- ── 1. Quem é amigo de quem ─────────────────────────────────────────────────
-- SECURITY DEFINER para não cair em recursão de RLS ao ser usada dentro de uma
-- policy. A amizade é gravada nos dois sentidos, mas a consulta cobre os dois
-- assim mesmo: uma linha órfã não pode virar negativa de acesso silenciosa.
CREATE OR REPLACE FUNCTION public.sao_amigos(a UUID, b UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT a IS NOT NULL AND b IS NOT NULL AND (
    a = b OR EXISTS (
      SELECT 1 FROM friendships f
      WHERE (f.user_id = a AND f.friend_id = b)
         OR (f.user_id = b AND f.friend_id = a)
    ));
$$;
REVOKE ALL ON FUNCTION public.sao_amigos(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sao_amigos(UUID, UUID) TO authenticated;

-- ── 2. A tabela dos campos que o interruptor protege ────────────────────────
CREATE TABLE IF NOT EXISTS profile_details (
  user_id    UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  bio        TEXT,
  city       TEXT,
  moto_model TEXT,
  moto_year  TEXT,
  trip_style TEXT,
  photos     TEXT[] NOT NULL DEFAULT '{}'::TEXT[]
);

-- ── 3. Copia o que já existe ────────────────────────────────────────────────
INSERT INTO profile_details (user_id, bio, city, moto_model, moto_year, trip_style, photos)
SELECT id, bio, city, moto_model, moto_year, trip_style, COALESCE(photos, '{}')
  FROM profiles
ON CONFLICT (user_id) DO NOTHING;

-- ── 4. Só dropa se a cópia estiver completa ─────────────────────────────────
-- Sem isto, um erro na cópia apagaria a bio e a cidade de todo mundo sem aviso.
DO $$
DECLARE faltam INT;
BEGIN
  SELECT count(*) INTO faltam
    FROM profiles p
   WHERE NOT EXISTS (SELECT 1 FROM profile_details d WHERE d.user_id = p.id);
  IF faltam > 0 THEN
    RAISE EXCEPTION 'Copia incompleta: % perfis sem linha em profile_details. Nada foi dropado.', faltam;
  END IF;
END $$;

-- ── 5. RLS: é aqui que o interruptor passa a valer ──────────────────────────
ALTER TABLE profile_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pd_select" ON profile_details;
CREATE POLICY "pd_select" ON profile_details FOR SELECT USING (
  user_id = auth.uid()
  OR EXISTS (SELECT 1 FROM profiles p WHERE p.id = user_id AND NOT p.is_private)
  OR public.sao_amigos(user_id, auth.uid())
);

-- Escrita só do dono, nas quatro operações.
DROP POLICY IF EXISTS "pd_write" ON profile_details;
CREATE POLICY "pd_write" ON profile_details FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Toda conta nova nasce com a linha, senão o primeiro save falha.
CREATE OR REPLACE FUNCTION public.handle_new_profile_details()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profile_details (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_profile_details ON profiles;
CREATE TRIGGER trg_profile_details AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_profile_details();

-- ── 6. nearby_riders: as colunas mudaram de lugar ───────────────────────────
-- A função é SECURITY DEFINER, então ela PULA a RLS de profile_details. Por
-- isso o respeito ao perfil privado vai escrito aqui dentro: quem marcou
-- privado aparece na descoberta (optou por `discoverable`) mas sem moto nem
-- estilo para quem não é amigo.
CREATE OR REPLACE FUNCTION public.nearby_riders(
  p_lat double precision, p_lng double precision, p_limit int DEFAULT 60)
RETURNS TABLE (
  id uuid,
  name text,
  username text,
  avatar_url text,
  moto_model text,
  trip_style text,
  distance_km double precision)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.id, p.name, p.username, p.avatar_url,
    CASE WHEN p.is_private AND NOT public.sao_amigos(p.id, auth.uid())
         THEN NULL ELSE d.moto_model END,
    CASE WHEN p.is_private AND NOT public.sao_amigos(p.id, auth.uid())
         THEN NULL ELSE d.trip_style END,
    6371 * acos(greatest(-1, least(1,
      cos(radians(p_lat)) * cos(radians(rl.lat)) *
      cos(radians(rl.lng) - radians(p_lng)) +
      sin(radians(p_lat)) * sin(radians(rl.lat))
    ))) AS distance_km
  FROM rider_locations rl
  JOIN profiles p ON p.id = rl.user_id
  LEFT JOIN profile_details d ON d.user_id = p.id
  WHERE p.discoverable = true
    AND p.id <> auth.uid()
  ORDER BY distance_km ASC
  LIMIT p_limit;
$$;
REVOKE ALL ON FUNCTION public.nearby_riders(double precision, double precision, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nearby_riders(double precision, double precision, integer)
  TO authenticated;

-- ── 7. Desativar / reativar conta acompanham a mudança ──────────────────────
-- O arquivo guardava `to_jsonb(p)`; agora os campos íntimos vêm da outra
-- tabela. Sem isto, desativar a conta apagaria a bio e a cidade SEM guardar
-- cópia, e reativar traria o perfil pela metade.
CREATE OR REPLACE FUNCTION public.deactivate_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'É preciso estar logado para desativar a conta';
  END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE id = uid AND deactivated_at IS NOT NULL) THEN
    RETURN;
  END IF;

  INSERT INTO profiles_archive (id, data, deactivated_at)
  SELECT p.id,
         to_jsonb(p) || jsonb_build_object('details', to_jsonb(d)),
         NOW()
    FROM profiles p
    LEFT JOIN profile_details d ON d.user_id = p.id
   WHERE p.id = uid
  ON CONFLICT (id) DO UPDATE
    SET data = EXCLUDED.data, deactivated_at = EXCLUDED.deactivated_at;

  UPDATE profiles SET
    name        = 'Usuário inativo',
    username    = 'inativo_' || left(replace(uid::text, '-', ''), 12),
    avatar_url  = NULL,
    business_name               = NULL,
    business_description        = NULL,
    business_banner_url         = NULL,
    business_address_street     = NULL,
    business_address_number     = NULL,
    business_address_neighborhood = NULL,
    business_address_city       = NULL,
    business_address_state      = NULL,
    business_categories         = '{}',
    discoverable = FALSE,
    is_private   = TRUE,
    is_online    = FALSE,
    deactivated_at = NOW()
  WHERE id = uid;

  UPDATE profile_details SET
    bio = NULL, city = NULL, moto_model = NULL,
    moto_year = NULL, trip_style = NULL, photos = '{}'
  WHERE user_id = uid;

  DELETE FROM rider_locations WHERE user_id = uid;
  DELETE FROM device_tokens   WHERE user_id = uid;
END; $$;
REVOKE ALL ON FUNCTION public.deactivate_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deactivate_my_account() TO authenticated;

CREATE OR REPLACE FUNCTION public.reactivate_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); d JSONB; det JSONB;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'É preciso estar logado para reativar a conta';
  END IF;
  SELECT data INTO d FROM profiles_archive WHERE id = uid;
  IF d IS NULL THEN RETURN; END IF;
  det := COALESCE(d->'details', '{}'::jsonb);

  UPDATE profiles SET
    name        = COALESCE(d->>'name', name),
    username    = COALESCE(d->>'username', username),
    avatar_url  = d->>'avatar_url',
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

  -- `details` só existe em arquivos feitos a partir desta migration; um arquivo
  -- antigo tem os campos na raiz. COALESCE cobre os dois formatos.
  INSERT INTO profile_details (user_id, bio, city, moto_model, moto_year, trip_style, photos)
  VALUES (
    uid,
    COALESCE(det->>'bio',        d->>'bio'),
    COALESCE(det->>'city',       d->>'city'),
    COALESCE(det->>'moto_model', d->>'moto_model'),
    COALESCE(det->>'moto_year',  d->>'moto_year'),
    COALESCE(det->>'trip_style', d->>'trip_style'),
    COALESCE(
      ARRAY(SELECT jsonb_array_elements_text(COALESCE(det->'photos', d->'photos'))),
      '{}')
  )
  ON CONFLICT (user_id) DO UPDATE SET
    bio = EXCLUDED.bio, city = EXCLUDED.city,
    moto_model = EXCLUDED.moto_model, moto_year = EXCLUDED.moto_year,
    trip_style = EXCLUDED.trip_style, photos = EXCLUDED.photos;

  DELETE FROM profiles_archive WHERE id = uid;
END; $$;
REVOKE ALL ON FUNCTION public.reactivate_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reactivate_my_account() TO authenticated;

-- ── 8. Só agora as colunas saem de `profiles` ───────────────────────────────
-- Irreversível. O passo 4 já garantiu que cada perfil tem a linha copiada.
ALTER TABLE profiles
  DROP COLUMN IF EXISTS bio,
  DROP COLUMN IF EXISTS city,
  DROP COLUMN IF EXISTS moto_model,
  DROP COLUMN IF EXISTS moto_year,
  DROP COLUMN IF EXISTS trip_style,
  DROP COLUMN IF EXISTS photos;
