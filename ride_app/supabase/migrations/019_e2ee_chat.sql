-- ─────────────────────────────────────────────────────────────────────────────
-- Criptografia ponta a ponta (E2EE) do chat
--
-- As mensagens passam a ser cifradas no CLIENTE (X25519 ECDH + AES-GCM). O
-- servidor guarda só o texto cifrado — não consegue ler. Aqui guardamos apenas
-- a CHAVE PÚBLICA de cada usuário (valor público, seguro de ler); a chave
-- privada nunca sai do aparelho (flutter_secure_storage).
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS user_keys (
    user_id    UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    public_key TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE user_keys ENABLE ROW LEVEL SECURITY;

-- Qualquer autenticado lê (precisa da chave pública dos contatos pra cifrar).
DROP POLICY IF EXISTS "user_keys_select" ON user_keys;
CREATE POLICY "user_keys_select" ON user_keys FOR SELECT USING (auth.uid() IS NOT NULL);

-- Cada um gerencia só a própria chave.
DROP POLICY IF EXISTS "user_keys_insert" ON user_keys;
CREATE POLICY "user_keys_insert" ON user_keys FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "user_keys_update" ON user_keys;
CREATE POLICY "user_keys_update" ON user_keys FOR UPDATE USING (auth.uid() = user_id);

-- Apaga o histórico antigo em texto puro (decisão: começar limpo com E2EE).
TRUNCATE TABLE messages;
