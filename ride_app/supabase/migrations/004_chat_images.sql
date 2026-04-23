-- ─────────────────────────────────────────────────────────────────────────────
-- Chat images: coluna image_url + bucket público chat-images
-- Aplique este script no SQL Editor do Supabase.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Column: messages.image_url ──────────────────────────────────────────────
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Permitir conteúdo vazio quando há apenas imagem
ALTER TABLE messages
    ALTER COLUMN content DROP NOT NULL;

-- ── Storage bucket: chat-images (público para leitura) ──────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-images', 'chat-images', true)
ON CONFLICT (id) DO NOTHING;

-- Apenas usuários autenticados podem subir; leitura pública (bucket é público).
DROP POLICY IF EXISTS "chat_images_storage_insert" ON storage.objects;
CREATE POLICY "chat_images_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'chat-images'
        AND auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "chat_images_storage_delete" ON storage.objects;
CREATE POLICY "chat_images_storage_delete"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'chat-images'
        AND auth.uid() = owner
    );
