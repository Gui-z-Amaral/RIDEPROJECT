-- ─────────────────────────────────────────────────────────────────────────────
-- Perfil empresa
--
-- Quando o usuário troca account_type para 'business' nas Configurações,
-- ele pode editar os campos abaixo numa tela dedicada (EditBusinessProfileScreen).
-- Os campos pessoais (name, bio) NÃO são sobrescritos — alternar entre os tipos
-- preserva os dois conjuntos.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS business_name                 TEXT,
    ADD COLUMN IF NOT EXISTS business_description          TEXT,
    ADD COLUMN IF NOT EXISTS business_banner_url           TEXT,
    ADD COLUMN IF NOT EXISTS business_address_street       TEXT,
    ADD COLUMN IF NOT EXISTS business_address_number       TEXT,
    ADD COLUMN IF NOT EXISTS business_address_neighborhood TEXT,
    ADD COLUMN IF NOT EXISTS business_address_city         TEXT,
    ADD COLUMN IF NOT EXISTS business_address_state        TEXT,
    ADD COLUMN IF NOT EXISTS business_categories           TEXT[] NOT NULL DEFAULT '{}';
