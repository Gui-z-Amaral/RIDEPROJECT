-- ─────────────────────────────────────────────────────────────────────────────
-- Trip photos + featured highlights (DESTAQUES)
-- Aplique este script no SQL Editor do Supabase.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Table: trip_photos ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trip_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS trip_photos_trip_idx ON trip_photos(trip_id);
CREATE INDEX IF NOT EXISTS trip_photos_user_idx ON trip_photos(uploaded_by);

ALTER TABLE trip_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "trip_photos_select" ON trip_photos FOR SELECT USING (true);

CREATE POLICY "trip_photos_insert" ON trip_photos FOR INSERT
    WITH CHECK (auth.uid() = uploaded_by);

CREATE POLICY "trip_photos_delete" ON trip_photos FOR DELETE
    USING (auth.uid() = uploaded_by);

-- ── Table: featured_photos ─────────────────────────────────────────────────
-- Um destaque ativo por usuário (PRIMARY KEY user_id garante unicidade).
-- Inserir um novo destaque sobrepõe o anterior via UPSERT.
-- expires_at = featured_at + 7 dias (filtrado nas queries).
CREATE TABLE IF NOT EXISTS featured_photos (
    user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    trip_id UUID REFERENCES trips(id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    featured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '7 days')
);

CREATE INDEX IF NOT EXISTS featured_photos_expires_idx
    ON featured_photos(expires_at);

ALTER TABLE featured_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "featured_photos_select" ON featured_photos FOR SELECT USING (true);

CREATE POLICY "featured_photos_upsert_insert" ON featured_photos FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "featured_photos_upsert_update" ON featured_photos FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "featured_photos_delete" ON featured_photos FOR DELETE
    USING (auth.uid() = user_id);

-- ── Storage bucket: trip-photos (público para leitura) ─────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('trip-photos', 'trip-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Apenas o dono pode subir / deletar; leitura pública (bucket é público).
CREATE POLICY "trip_photos_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'trip-photos'
        AND auth.role() = 'authenticated'
    );

CREATE POLICY "trip_photos_storage_delete"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'trip-photos'
        AND auth.uid() = owner
    );
