-- 030 — E2EE multi-dispositivo (app + web)
--
-- Problema: user_keys tinha UMA chave por usuário. Ao logar em outro
-- dispositivo (ex.: a web), o app gerava um par novo e o upsert sobrescrevia a
-- chave pública — o aparelho anterior passava a não decifrar nada
-- ("último dispositivo que logou ganha").
--
-- Solução: cada aparelho publica a PRÓPRIA chave pública, identificada por
-- device_id. Ao enviar, o cliente monta um envelope com uma cópia cifrada para
-- cada dispositivo do destinatário e para os outros dispositivos do remetente.

ALTER TABLE user_keys ADD COLUMN IF NOT EXISTS device_id TEXT;

-- Linhas antigas viram o dispositivo 'legacy'.
UPDATE user_keys SET device_id = 'legacy' WHERE device_id IS NULL;
ALTER TABLE user_keys ALTER COLUMN device_id SET NOT NULL;

-- A chave passa a ser (user_id, device_id)
ALTER TABLE user_keys DROP CONSTRAINT IF EXISTS user_keys_pkey;
ALTER TABLE user_keys ADD CONSTRAINT user_keys_pkey PRIMARY KEY (user_id, device_id);

CREATE INDEX IF NOT EXISTS idx_user_keys_user ON user_keys(user_id);

-- Novo: o aparelho pode remover a própria chave (logout/descadastro).
-- As policies de SELECT/INSERT/UPDATE da 019 continuam valendo.
DROP POLICY IF EXISTS "user_keys_delete" ON user_keys;
CREATE POLICY "user_keys_delete" ON user_keys FOR DELETE USING (auth.uid() = user_id);

-- Mensagens antigas estão no formato de ciphertext único e ficariam ilegíveis
-- para sempre no novo formato de envelope. Mesma decisão da 019 ao introduzir
-- o E2EE: começar limpo.
TRUNCATE TABLE messages;
