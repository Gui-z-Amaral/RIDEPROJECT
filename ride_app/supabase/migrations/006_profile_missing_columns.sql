-- ─────────────────────────────────────────────────────────────────────────────
-- Colunas de perfil que o app usa mas que não estavam no schema inicial.
-- - city: texto livre (cidade + estado)
-- - photos: galeria de fotos do usuário (array de URLs)
-- Idempotente — pode rodar mesmo se as colunas já existirem.
-- Aplique no SQL Editor do Supabase.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS city TEXT;

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS photos TEXT[] DEFAULT '{}'::TEXT[];
