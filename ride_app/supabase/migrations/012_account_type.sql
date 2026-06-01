-- ─────────────────────────────────────────────────────────────────────────────
-- Tipo de conta (pessoal vs empresa)
--
-- Usado nas Configurações do perfil: o usuário pode mudar a conta para
-- "empresa". Perfis empresa poderão futuramente criar eventos com programação
-- que aparecem na tela inicial.
--
--   'personal' (default) | 'business'
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS account_type TEXT NOT NULL DEFAULT 'personal';

-- Restringe aos valores válidos (idempotente — só cria a constraint uma vez).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'profiles_account_type_check'
    ) THEN
        ALTER TABLE profiles
            ADD CONSTRAINT profiles_account_type_check
            CHECK (account_type IN ('personal', 'business'));
    END IF;
END
$$;
