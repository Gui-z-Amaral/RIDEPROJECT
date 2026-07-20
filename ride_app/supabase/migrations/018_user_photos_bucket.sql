-- ─────────────────────────────────────────────────────────────────────────────
-- Bucket de fotos do perfil (user-photos)
--
-- Usado em profile_screen ("Suas Fotos" → Adicionar):
--   storage.from('user-photos').uploadBinary('<uid>/<timestamp>.jpg', ...)
--
-- Existia só no Supabase antigo (criado à mão no painel) e ficou de fora na
-- migração da VPS — por isso o upload de foto de perfil falhava com
-- "Bucket not found".
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- Cria o bucket público (leitura pública, upload só autenticado).
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-photos', 'user-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Upload: qualquer autenticado (o caminho é sempre "<uid>/<timestamp>.jpg").
DROP POLICY IF EXISTS "user_photos_storage_insert" ON storage.objects;
CREATE POLICY "user_photos_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'user-photos'
        AND auth.role() = 'authenticated'
    );

-- Dono pode apagar as próprias fotos.
DROP POLICY IF EXISTS "user_photos_storage_delete" ON storage.objects;
CREATE POLICY "user_photos_storage_delete"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'user-photos'
        AND auth.uid() = owner
    );
