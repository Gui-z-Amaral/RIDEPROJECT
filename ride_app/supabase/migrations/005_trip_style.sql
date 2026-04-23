-- ─────────────────────────────────────────────────────────────────────────────
-- Estilo de viagem preferido (persistido no perfil do usuário).
-- Aplique este script no SQL Editor do Supabase.
-- Valores aceitos: 'Curtas' | 'Longas' | 'Rolês' | NULL
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS trip_style TEXT;
