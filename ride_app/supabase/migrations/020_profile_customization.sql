-- ─────────────────────────────────────────────────────────────────────────────
-- Personalização de perfil (banner, moldura do avatar, cores)
--
-- Uma linha por usuário. Colunas de cor são opcionais (NULL = usa o padrão
-- do app). Visível também para quem visita o perfil (select público),
-- como no Discord/Facebook.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS profile_customizations (
    user_id          UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    banner_url       TEXT,
    avatar_frame     TEXT NOT NULL DEFAULT 'none',
    background_color TEXT,
    text_color       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE profile_customizations ENABLE ROW LEVEL SECURITY;

-- Qualquer autenticado vê (precisa aparecer pra quem visita o perfil).
DROP POLICY IF EXISTS "profile_customizations_select" ON profile_customizations;
CREATE POLICY "profile_customizations_select" ON profile_customizations
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Cada um gerencia só a própria personalização.
DROP POLICY IF EXISTS "profile_customizations_insert" ON profile_customizations;
CREATE POLICY "profile_customizations_insert" ON profile_customizations
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "profile_customizations_update" ON profile_customizations;
CREATE POLICY "profile_customizations_update" ON profile_customizations
    FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "profile_customizations_delete" ON profile_customizations;
CREATE POLICY "profile_customizations_delete" ON profile_customizations
    FOR DELETE USING (auth.uid() = user_id);
