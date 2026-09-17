-- ─────────────────────────────────────────────────────────────────────────────
-- 036: chave de chat por CONTA, no lugar de chave por aparelho
--
-- Por quê: com a chave só no aparelho, limpar os dados do navegador ou trocar
-- de celular tornava todo o histórico ilegível ("🔒 Mensagem cifrada"), sem
-- nada que o usuário pudesse fazer. No teste real um aparelho gerou TRÊS
-- identidades em quatro minutos, e havia 23 chaves para 13 pessoas.
--
-- TROCA DE GARANTIA, EXPLÍCITA: a chave privada passa a ficar no servidor, o
-- que significa que quem tiver acesso ao banco consegue decifrar as mensagens.
-- Deixa de ser criptografia ponta a ponta e passa a ser "cifrado no banco":
-- um vazamento apenas da tabela `messages` continua inútil sem `user_chat_keys`,
-- mas o servidor não é mais cego. NÃO divulgar como "ponta a ponta".
--
-- As duas metades ficam em TABELAS SEPARADAS de propósito: a pública precisa
-- ser lida por quem vai enviar mensagem para a pessoa, a privada só pelo dono.
-- Juntas na mesma tabela, uma policy de leitura ou um `select('*')` distraído
-- vazaria a privada.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Pública: uma por usuário, legível por quem vai cifrar para ela ───────
-- A tabela já existia com (user_id, device_id). Volta a ser uma linha por
-- usuário. As chaves antigas não servem para nada: as privadas correspondentes
-- se perderam com os aparelhos.
DELETE FROM user_keys;
ALTER TABLE user_keys DROP CONSTRAINT IF EXISTS user_keys_pkey;
ALTER TABLE user_keys DROP COLUMN IF EXISTS device_id;
ALTER TABLE user_keys ADD PRIMARY KEY (user_id);

-- ── 2. Privada: só o dono ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_chat_keys (
  user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  private_key TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE user_chat_keys ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_chat_keys_select" ON user_chat_keys;
CREATE POLICY "user_chat_keys_select" ON user_chat_keys FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_chat_keys_insert" ON user_chat_keys;
CREATE POLICY "user_chat_keys_insert" ON user_chat_keys FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Sem policy de UPDATE nem DELETE: trocar a chave privada tornaria o histórico
-- ilegível, que é exatamente o problema que esta migration resolve.

-- ── 3. Mensagens antigas ───────────────────────────────────────────────────
-- Cifradas para aparelhos cujas chaves privadas não existem mais: são
-- irrecuperáveis por qualquer caminho e ficariam como 🔒 para sempre.
-- São 46 mensagens de teste, em 3 conversas. A migration 030 fez o mesmo pelo
-- mesmo motivo.
TRUNCATE TABLE messages;
