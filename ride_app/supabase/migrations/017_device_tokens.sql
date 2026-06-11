-- ─────────────────────────────────────────────────────────────────────────────
-- device_tokens — tokens FCM por usuário (push notifications)
--
-- Um usuário pode ter vários aparelhos. PK no token: se o mesmo aparelho logar
-- com outra conta, o upsert (onConflict: token) move o token para o novo dono,
-- evitando token órfão apontando pra conta errada.
--
-- O worker de push (rideapp-push-worker na VPS) lê esta tabela com service_role
-- (ignora RLS) pra descobrir pra quais aparelhos enviar quando entra uma linha
-- em notifications.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS device_tokens (
    token      TEXT PRIMARY KEY,
    user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    platform   TEXT NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- App: cada usuário gerencia só os próprios tokens.
DROP POLICY IF EXISTS "device_tokens_select" ON device_tokens;
CREATE POLICY "device_tokens_select" ON device_tokens FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "device_tokens_insert" ON device_tokens;
CREATE POLICY "device_tokens_insert" ON device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "device_tokens_update" ON device_tokens;
CREATE POLICY "device_tokens_update" ON device_tokens FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "device_tokens_delete" ON device_tokens;
CREATE POLICY "device_tokens_delete" ON device_tokens FOR DELETE USING (auth.uid() = user_id);
