-- ─────────────────────────────────────────────────────────────────────────────
-- 037: chave do chat cifrada no banco + índices em chaves estrangeiras
--
-- PARTE 1 — Chave privada cifrada em repouso
-- Depois da 036 a chave privada do chat passou a ficar no servidor (para o
-- histórico sobreviver a trocar de aparelho). Ela estava em texto puro, então
-- um BACKUP VAZADO ou uma consulta indevida à tabela entregava tudo.
--
-- Agora a coluna guarda `pgp_sym_encrypt(chave, embrulho)`. O "embrulho" é um
-- segredo guardado no Vault, que por sua vez é cifrado com a chave-mestra em
-- /etc/postgresql-custom/pgsodium_root.key — um arquivo de 64 bytes, modo 600,
-- que NÃO sai no pg_dump. Logo: um dump do banco, sozinho, é inútil.
--
-- O que isto NÃO resolve, para não haver ilusão: quem tem root na VPS lê o
-- arquivo e o banco; e quem tem a service_role continua passando por cima da
-- RLS. O ganho é contra compromisso PARCIAL (backup extraviado, SQL injection,
-- leitura acidental) — que é o incidente mais comum numa operação pequena.
--
-- ⚠️ NOVO PONTO ÚNICO DE FALHA: perder o pgsodium_root.key torna TODAS as
-- mensagens ilegíveis para sempre. Ele precisa entrar no backup com o mesmo
-- cuidado da keystore do Android.
--
-- A tabela deixa de ser lida direto: o app passa por duas funções, que é
-- também onde dá para auditar ou limitar no futuro.
--
-- PARTE 2 — Índices
-- Cinco chaves estrangeiras sem índice. Hoje não custa nada (tabelas pequenas),
-- mas APAGAR UM USUÁRIO obriga o Postgres a varrer cada uma delas para conferir
-- as referências — e a exclusão automática de contas aos 6 meses (034) fez
-- disso rotina.
-- ─────────────────────────────────────────────────────────────────────────────

-- Nota: as chamadas do pgcrypto vao qualificadas com `extensions.` porque as
-- funcoes fixam `search_path = public` (protecao contra sequestro de schema).
-- Alargar o search_path resolveria, mas abriria justamente a brecha que a
-- fixacao evita.

-- ══ PARTE 1: CHAVE CIFRADA EM REPOUSO ══════════════════════════════════════

-- Segredo que embrulha as chaves. Criado uma única vez; se já existir, mantém
-- (recriar tornaria ilegível tudo que foi cifrado com o anterior).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'chat_key_wrap') THEN
    PERFORM vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'chat_key_wrap',
      'Embrulha as chaves privadas do chat (tabela user_chat_keys)');
  END IF;
END $$;

-- Grava a chave privada CIFRADA e publica a pública. Uma função só para as
-- duas metades: separadas, um erro no meio deixaria a pessoa com chave pública
-- publicada e privada ausente — todos cifrariam para algo que ela não abre.
CREATE OR REPLACE FUNCTION public.chat_key_set(p_private TEXT, p_public TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); wrap TEXT;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'É preciso estar logado';
  END IF;
  -- Não deixa sobrescrever: trocar a chave tornaria o histórico ilegível.
  IF EXISTS (SELECT 1 FROM user_chat_keys WHERE user_id = uid) THEN
    RETURN;
  END IF;

  SELECT decrypted_secret INTO wrap
  FROM vault.decrypted_secrets WHERE name = 'chat_key_wrap';
  IF wrap IS NULL THEN
    RAISE EXCEPTION 'Segredo de embrulho ausente';
  END IF;

  INSERT INTO user_chat_keys (user_id, private_key)
  VALUES (uid, encode(extensions.pgp_sym_encrypt(p_private, wrap), 'base64'));

  INSERT INTO user_keys (user_id, public_key, updated_at)
  VALUES (uid, p_public, NOW())
  ON CONFLICT (user_id) DO UPDATE SET public_key = EXCLUDED.public_key,
                                      updated_at = NOW();
END; $$;

-- Devolve a chave privada decifrada, e SÓ a de quem chama.
CREATE OR REPLACE FUNCTION public.chat_key_get()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); wrap TEXT; guardada TEXT;
BEGIN
  IF uid IS NULL THEN RETURN NULL; END IF;

  SELECT private_key INTO guardada FROM user_chat_keys WHERE user_id = uid;
  IF guardada IS NULL THEN RETURN NULL; END IF;

  SELECT decrypted_secret INTO wrap
  FROM vault.decrypted_secrets WHERE name = 'chat_key_wrap';
  IF wrap IS NULL THEN RETURN NULL; END IF;

  RETURN extensions.pgp_sym_decrypt(decode(guardada, 'base64'), wrap);
END; $$;

-- Lembrete da 035: revogar de PUBLIC não basta — o Supabase concede EXECUTE
-- direto a anon e authenticated em toda função nova do schema public.
REVOKE ALL ON FUNCTION public.chat_key_set(TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.chat_key_get()           FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_key_set(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_key_get()           TO authenticated;

-- A tabela sai do alcance da API: só as funções acima tocam nela. Sem isto,
-- um `select('*')` distraído no app devolveria a coluna cifrada e, pior, a
-- superfície continuaria existindo.
REVOKE ALL ON TABLE user_chat_keys FROM anon, authenticated;

-- As policies deixam de ser o que protege (não há mais acesso direto), mas
-- ficam como segunda barreira caso alguém conceda acesso de novo por engano.

-- ══ PARTE 2: ÍNDICES EM CHAVES ESTRANGEIRAS ════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_trips_creator          ON trips(creator_id);
CREATE INDEX IF NOT EXISTS idx_rides_creator          ON rides(creator_id);
CREATE INDEX IF NOT EXISTS idx_ride_locations_user    ON ride_locations(user_id);
CREATE INDEX IF NOT EXISTS idx_event_participants_user ON event_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_club_members_invited_by ON club_members(invited_by);
