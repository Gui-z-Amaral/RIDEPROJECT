-- ─────────────────────────────────────────────────────────────────────────────
-- Corrige RLS de storage.objects que usava auth.role() = 'authenticated'.
--
-- Nesse self-hosted, o Storage API não está passando o claim "role" do jeito
-- que essas policies esperavam, causando 403 "new row violates row-level
-- security policy" ao subir foto de perfil/banner (mesmo com a policy
-- existindo). Troca para auth.uid() IS NOT NULL, que já é usado com sucesso
-- em outras tabelas do projeto (ex: notif_insert, ride_loc_insert).
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── avatars (foto de perfil, banner de empresa, banner de evento) ───────────
DROP POLICY IF EXISTS "avatars_storage_insert" ON storage.objects;
CREATE POLICY "avatars_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars'
        AND auth.uid() IS NOT NULL
    );

DROP POLICY IF EXISTS "avatars_storage_update" ON storage.objects;
CREATE POLICY "avatars_storage_update"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'avatars'
        AND auth.uid() IS NOT NULL
    );

-- ── trip-photos (fotos de viagem/rolê ao finalizar) ──────────────────────────
DROP POLICY IF EXISTS "trip_photos_storage_insert" ON storage.objects;
CREATE POLICY "trip_photos_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'trip-photos'
        AND auth.uid() IS NOT NULL
    );

-- ── chat-images (imagens enviadas no chat) ───────────────────────────────────
DROP POLICY IF EXISTS "chat_images_storage_insert" ON storage.objects;
CREATE POLICY "chat_images_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'chat-images'
        AND auth.uid() IS NOT NULL
    );

-- ── user-photos ("Suas Fotos" no perfil) ─────────────────────────────────────
DROP POLICY IF EXISTS "user_photos_storage_insert" ON storage.objects;
CREATE POLICY "user_photos_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'user-photos'
        AND auth.uid() IS NOT NULL
    );
