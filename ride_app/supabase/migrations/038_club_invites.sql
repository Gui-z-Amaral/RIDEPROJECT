-- ─────────────────────────────────────────────────────────────────────────────
-- 038: convites de motoclube por link
--
-- Hoje só existe convite direto (club_members com status 'invited'), que exige
-- achar a pessoa no app. O dono/gerente precisa de um LINK para mandar no
-- WhatsApp, em três formatos:
--   permanent — vale para sempre, para colocar na bio do clube
--   single    — uma pessoa só; queima no primeiro uso
--   temporary — expira em 1 hora, para um encontro pontual
--
-- ── SEGURANÇA ───────────────────────────────────────────────────────────────
-- O token é a credencial: quem o tem, entra. Por isso:
--  - token com 16 bytes aleatórios (32 hex). Não é sequencial nem adivinhável;
--  - a tabela NÃO é acessível pela API (`REVOKE`): sem isso, qualquer pessoa
--    logada listaria os tokens de todos os clubes e entraria em qualquer um.
--    Tudo passa pelas funções abaixo;
--  - validade e uso são conferidos NO SERVIDOR. Checar no app seria teatro:
--    bastaria chamar o endpoint direto;
--  - o convite de uso único é queimado com UPDATE condicional
--    (`WHERE used_by IS NULL`), que é atômico. Duas pessoas tocando no mesmo
--    link ao mesmo tempo: uma entra, a outra recebe "já utilizado".
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS club_invites (
  token      TEXT PRIMARY KEY,
  club_id    UUID REFERENCES clubs(id)    ON DELETE CASCADE NOT NULL,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  kind       TEXT NOT NULL CHECK (kind IN ('permanent','single','temporary')),
  expires_at TIMESTAMPTZ,                  -- só para 'temporary'
  used_by    UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- só para 'single'
  used_at    TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_club_invites_club ON club_invites(club_id);

ALTER TABLE club_invites ENABLE ROW LEVEL SECURITY;
-- Sem policy de propósito: o acesso é só pelas funções SECURITY DEFINER.
REVOKE ALL ON TABLE club_invites FROM anon, authenticated;

-- ── Criar ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.club_invite_create(
  p_club_id UUID, p_kind TEXT
) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); t TEXT; exp TIMESTAMPTZ;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'É preciso estar logado'; END IF;
  IF NOT public.is_club_admin(p_club_id, uid) THEN
    RAISE EXCEPTION 'Só quem administra o motoclube pode criar convites';
  END IF;
  IF p_kind NOT IN ('permanent','single','temporary') THEN
    RAISE EXCEPTION 'Tipo de convite inválido';
  END IF;

  IF p_kind = 'temporary' THEN exp := NOW() + INTERVAL '1 hour'; END IF;
  t := encode(extensions.gen_random_bytes(16), 'hex');

  INSERT INTO club_invites (token, club_id, created_by, kind, expires_at)
  VALUES (t, p_club_id, uid, p_kind, exp);
  RETURN t;
END; $$;

-- ── Prévia (tela de quem recebeu o link) ────────────────────
-- Aberta a quem não está logado de propósito: a pessoa precisa ver de qual
-- clube é o convite ANTES de criar conta. Devolve só o que já é público no
-- perfil do clube — nunca a lista de membros nem quem criou o convite.
CREATE OR REPLACE FUNCTION public.club_invite_preview(p_token TEXT)
RETURNS TABLE (club_id UUID, name TEXT, avatar_url TEXT, city TEXT,
               state_uf TEXT, members INT, status TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv club_invites%ROWTYPE; st TEXT;
BEGIN
  SELECT * INTO inv FROM club_invites WHERE token = p_token;
  IF inv.token IS NULL THEN
    RETURN QUERY SELECT NULL::UUID, NULL::TEXT, NULL::TEXT, NULL::TEXT,
                        NULL::TEXT, 0, 'invalido';
    RETURN;
  END IF;

  st := CASE
    WHEN inv.revoked_at IS NOT NULL                       THEN 'revogado'
    WHEN inv.expires_at IS NOT NULL
         AND inv.expires_at < NOW()                       THEN 'expirado'
    WHEN inv.kind = 'single' AND inv.used_by IS NOT NULL  THEN 'usado'
    ELSE 'valido'
  END;

  RETURN QUERY
  SELECT c.id, c.name, c.avatar_url, c.city, c.state_uf,
         (SELECT count(*)::INT FROM club_members m
           WHERE m.club_id = c.id AND m.status = 'active'),
         st
  FROM clubs c WHERE c.id = inv.club_id;
END; $$;

-- ── Aceitar ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.club_invite_accept(p_token TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); inv club_invites%ROWTYPE; queimado INT;
BEGIN
  IF uid IS NULL THEN RETURN 'sem_sessao'; END IF;

  SELECT * INTO inv FROM club_invites WHERE token = p_token;
  IF inv.token IS NULL     THEN RETURN 'invalido'; END IF;
  IF inv.revoked_at IS NOT NULL THEN RETURN 'revogado'; END IF;
  IF inv.expires_at IS NOT NULL AND inv.expires_at < NOW() THEN
    RETURN 'expirado';
  END IF;

  -- Já é membro: não consome o convite de uso único.
  IF EXISTS (SELECT 1 FROM club_members
              WHERE club_id = inv.club_id AND user_id = uid
                AND status = 'active') THEN
    RETURN 'ja_membro';
  END IF;

  IF inv.kind = 'single' THEN
    -- Atômico: quem ganhar a corrida leva. O WHERE garante que só uma
    -- transação consegue marcar como usado.
    UPDATE club_invites SET used_by = uid, used_at = NOW()
     WHERE token = p_token AND used_by IS NULL;
    GET DIAGNOSTICS queimado = ROW_COUNT;
    IF queimado = 0 THEN RETURN 'usado'; END IF;
  END IF;

  INSERT INTO club_members (club_id, user_id, role, status, invited_by)
  VALUES (inv.club_id, uid, 'member', 'active', inv.created_by)
  ON CONFLICT (club_id, user_id)
    DO UPDATE SET status = 'active';

  RETURN 'entrou';
END; $$;

-- ── Listar e revogar (painel do admin) ──────────────────────
CREATE OR REPLACE FUNCTION public.club_invites_list(p_club_id UUID)
RETURNS TABLE (token TEXT, kind TEXT, expires_at TIMESTAMPTZ,
               used_at TIMESTAMPTZ, created_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_club_admin(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Só quem administra o motoclube pode ver os convites';
  END IF;
  RETURN QUERY
  SELECT i.token, i.kind, i.expires_at, i.used_at, i.created_at
  FROM club_invites i
  WHERE i.club_id = p_club_id AND i.revoked_at IS NULL
  ORDER BY i.created_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.club_invite_revoke(p_token TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv club_invites%ROWTYPE;
BEGIN
  SELECT * INTO inv FROM club_invites WHERE token = p_token;
  IF inv.token IS NULL THEN RETURN; END IF;
  IF NOT public.is_club_admin(inv.club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Só quem administra o motoclube pode revogar convites';
  END IF;
  UPDATE club_invites SET revoked_at = NOW() WHERE token = p_token;
END; $$;

-- ── Permissões ──────────────────────────────────────────────
-- Lembrete das migrations 035 e 037: REVOKE de PUBLIC não basta, porque o
-- Supabase concede EXECUTE direto a anon e authenticated em toda função nova.
REVOKE ALL ON FUNCTION public.club_invite_create(UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_invite_accept(TEXT)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_invites_list(UUID)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_invite_revoke(TEXT)       FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.club_invite_create(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_invite_accept(TEXT)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_invites_list(UUID)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_invite_revoke(TEXT)       TO authenticated;

-- A prévia continua aberta ao anônimo: é o que permite a tela "o Motoclube X
-- te convidou" aparecer antes de a pessoa criar conta.
GRANT EXECUTE ON FUNCTION public.club_invite_preview(TEXT) TO anon, authenticated;
