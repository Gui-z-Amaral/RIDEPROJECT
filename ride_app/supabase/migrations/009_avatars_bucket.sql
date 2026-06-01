-- ─────────────────────────────────────────────────────────────────────────────
-- Bucket de avatares (storage)
--
-- Usado em edit_profile_screen quando o usuário troca a foto de perfil:
-- _db.storage.from('avatars').uploadBinary('<uid>/avatar.jpg', bytes, ...)
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- Cria o bucket público (leitura pública, upload só autenticado).
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Qualquer authenticated pode subir. Como o caminho é "<uid>/avatar.jpg"
-- (upsert=true), cada usuário só sobrescreve o próprio.
DROP POLICY IF EXISTS "avatars_storage_insert" ON storage.objects;
CREATE POLICY "avatars_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars'
        AND auth.role() = 'authenticated'
    );

-- Permite upsert (UPDATE) na própria pasta.
DROP POLICY IF EXISTS "avatars_storage_update" ON storage.objects;
CREATE POLICY "avatars_storage_update"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'avatars'
        AND auth.role() = 'authenticated'
    );

-- Permite que o dono delete seu próprio avatar.
DROP POLICY IF EXISTS "avatars_storage_delete" ON storage.objects;
CREATE POLICY "avatars_storage_delete"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'avatars'
        AND auth.uid() = owner
    );
