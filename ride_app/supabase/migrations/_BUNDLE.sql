-- =============================================================================
-- Bundle de TODAS as migrations (001 a 010)
-- Gerado automaticamente — nao edite a mao. Modifique os arquivos individuais.
-- =============================================================================


-- ////////////////////////////////////////////////////////////////////////////
-- 001_initial_schema.sql
-- ////////////////////////////////////////////////////////////////////////////

-- ============================================================
-- RIDE APP — Schema inicial
-- Execute no Supabase Dashboard > SQL Editor
-- ============================================================

-- ── 1. PROFILES (estende auth.users) ────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id            UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  username      TEXT UNIQUE NOT NULL,
  name          TEXT NOT NULL,
  avatar_url    TEXT,
  bio           TEXT,
  moto_model    TEXT,
  moto_year     TEXT,
  friends_count INT  DEFAULT 0,
  trips_count   INT  DEFAULT 0,
  is_online     BOOLEAN DEFAULT FALSE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. FRIENDSHIPS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS friendships (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  friend_id  UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- ── 3. FRIEND REQUESTS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS friend_requests (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  from_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  to_user_id   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  status       TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(from_user_id, to_user_id)
);

-- ── 4. TRIPS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trips (
  id                  UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  creator_id          UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title               TEXT NOT NULL,
  description         TEXT,
  origin_lat          DOUBLE PRECISION NOT NULL,
  origin_lng          DOUBLE PRECISION NOT NULL,
  origin_address      TEXT,
  origin_label        TEXT,
  destination_lat     DOUBLE PRECISION NOT NULL,
  destination_lng     DOUBLE PRECISION NOT NULL,
  destination_address TEXT,
  destination_label   TEXT,
  status              TEXT DEFAULT 'planned' CHECK (status IN ('planned','active','completed','cancelled')),
  route_type          TEXT DEFAULT 'none',
  scheduled_at        TIMESTAMPTZ,
  estimated_distance  DOUBLE PRECISION,
  estimated_duration  TEXT,
  cover_image         TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ── 5. TRIP PARTICIPANTS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS trip_participants (
  id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id   UUID REFERENCES trips(id)    ON DELETE CASCADE NOT NULL,
  user_id   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(trip_id, user_id)
);

-- ── 6. RIDES ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rides (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  creator_id       UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  title            TEXT NOT NULL,
  meeting_lat      DOUBLE PRECISION NOT NULL,
  meeting_lng      DOUBLE PRECISION NOT NULL,
  meeting_address  TEXT,
  meeting_label    TEXT,
  status           TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled','waiting','active','completed','cancelled')),
  scheduled_at     TIMESTAMPTZ,
  is_immediate     BOOLEAN DEFAULT FALSE,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ── 7. RIDE PARTICIPANTS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS ride_participants (
  id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ride_id   UUID REFERENCES rides(id)    ON DELETE CASCADE NOT NULL,
  user_id   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ride_id, user_id)
);

-- ── 8. MESSAGES ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_id   TEXT NOT NULL,
  sender_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content   TEXT NOT NULL,
  is_read   BOOLEAN DEFAULT FALSE,
  sent_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── INDEXES ──────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_friendships_user    ON friendships(user_id);
CREATE INDEX IF NOT EXISTS idx_friendships_friend  ON friendships(friend_id);
CREATE INDEX IF NOT EXISTS idx_freq_to             ON friend_requests(to_user_id);
CREATE INDEX IF NOT EXISTS idx_freq_from           ON friend_requests(from_user_id);
CREATE INDEX IF NOT EXISTS idx_trip_part_trip      ON trip_participants(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_part_user      ON trip_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_ride_part_ride      ON ride_participants(ride_id);
CREATE INDEX IF NOT EXISTS idx_ride_part_user      ON ride_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_chat       ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender     ON messages(sender_id);

-- ── ROW LEVEL SECURITY ───────────────────────────────────────
ALTER TABLE profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships      ENABLE ROW LEVEL SECURITY;
ALTER TABLE friend_requests  ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips             ENABLE ROW LEVEL SECURITY;
ALTER TABLE trip_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE rides             ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages          ENABLE ROW LEVEL SECURITY;

-- profiles
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (auth.uid() = id);

-- friendships
CREATE POLICY "friendships_select" ON friendships FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY "friendships_insert" ON friendships FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "friendships_delete" ON friendships FOR DELETE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- friend_requests
CREATE POLICY "freq_select" ON friend_requests FOR SELECT
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);
CREATE POLICY "freq_insert" ON friend_requests FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);
CREATE POLICY "freq_update" ON friend_requests FOR UPDATE
  USING (auth.uid() = to_user_id);
CREATE POLICY "freq_delete" ON friend_requests FOR DELETE
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

-- trips
CREATE POLICY "trips_select" ON trips FOR SELECT USING (true);
CREATE POLICY "trips_insert" ON trips FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "trips_update" ON trips FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "trips_delete" ON trips FOR DELETE USING (auth.uid() = creator_id);

-- trip_participants
CREATE POLICY "trip_part_select" ON trip_participants FOR SELECT USING (true);
CREATE POLICY "trip_part_insert" ON trip_participants FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "trip_part_delete" ON trip_participants FOR DELETE USING (auth.uid() = user_id);

-- rides
CREATE POLICY "rides_select" ON rides FOR SELECT USING (true);
CREATE POLICY "rides_insert" ON rides FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "rides_update" ON rides FOR UPDATE USING (auth.uid() = creator_id);
CREATE POLICY "rides_delete" ON rides FOR DELETE USING (auth.uid() = creator_id);

-- ride_participants
CREATE POLICY "ride_part_select" ON ride_participants FOR SELECT USING (true);
CREATE POLICY "ride_part_insert" ON ride_participants FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "ride_part_delete" ON ride_participants FOR DELETE USING (auth.uid() = user_id);

-- messages
CREATE POLICY "messages_select" ON messages FOR SELECT
  USING (auth.uid() IS NOT NULL);
CREATE POLICY "messages_insert" ON messages FOR INSERT
  WITH CHECK (auth.uid() = sender_id);

-- ── TRIGGER: cria profile automaticamente no cadastro ────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, username, name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username',
             lower(regexp_replace(COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email,'@',1)), '\s+', '_', 'g'))),
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email,'@',1)),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── FUNÇÃO: atualizar contagem de viagens ────────────────────
CREATE OR REPLACE FUNCTION public.update_trips_count(p_user_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE profiles
  SET trips_count = (
    SELECT COUNT(*) FROM trip_participants WHERE user_id = p_user_id
  )
  WHERE id = p_user_id;
END;
$$;

-- ── FUNÇÃO: contagem de amigos ────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_friends_count(p_user_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE profiles
  SET friends_count = (
    SELECT COUNT(*) FROM friendships
    WHERE user_id = p_user_id OR friend_id = p_user_id
  )
  WHERE id = p_user_id;
END;
$$;


-- ////////////////////////////////////////////////////////////////////////////
-- 002_notifications.sql
-- ////////////////////////////////////////////////////////////////////////////

-- ── NOTIFICATIONS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type       TEXT NOT NULL DEFAULT 'general',
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  data       JSONB DEFAULT '{}',
  is_read    BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user   ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Cada usuário lê apenas as próprias notificações
CREATE POLICY "notif_select" ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Qualquer usuário autenticado pode criar notificação para outro (convite)
CREATE POLICY "notif_insert" ON notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Usuário pode marcar as suas como lidas
CREATE POLICY "notif_update" ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Usuário pode deletar as suas
CREATE POLICY "notif_delete" ON notifications FOR DELETE
  USING (auth.uid() = user_id);


-- ////////////////////////////////////////////////////////////////////////////
-- 003_trip_photos_and_highlights.sql
-- ////////////////////////////////////////////////////////////////////////////

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


-- ////////////////////////////////////////////////////////////////////////////
-- 004_chat_images.sql
-- ////////////////////////////////////////////////////////////////////////////

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


-- ////////////////////////////////////////////////////////////////////////////
-- 005_trip_style.sql
-- ////////////////////////////////////////////////////////////////////////////

-- ─────────────────────────────────────────────────────────────────────────────
-- Estilo de viagem preferido (persistido no perfil do usuário).
-- Aplique este script no SQL Editor do Supabase.
-- Valores aceitos: 'Curtas' | 'Longas' | 'Rolês' | NULL
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS trip_style TEXT;


-- ////////////////////////////////////////////////////////////////////////////
-- 006_profile_missing_columns.sql
-- ////////////////////////////////////////////////////////////////////////////

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


-- ////////////////////////////////////////////////////////////////////////////
-- 007_session_columns_and_locations.sql
-- ////////////////////////////////////////////////////////////////////////////

-- ─────────────────────────────────────────────────────────────────────────────
-- Colunas de sessão (status/left_at) em participantes + tabela ride_locations.
--
-- Essas mudanças foram aplicadas manualmente no Supabase antigo, mas nunca
-- versionadas. Esta migração reúne tudo num único script idempotente.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. ride_participants: status de confirmação + soft delete ───────────────
-- status: 'waiting' (default) | 'confirmed' | 'declined'
-- left_at: timestamp do soft delete usado por RideHistoryEntry.isActive
ALTER TABLE ride_participants
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'waiting';

ALTER TABLE ride_participants
    ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ;

-- Permite ao próprio usuário atualizar seu status (confirmar / recusar / sair)
DROP POLICY IF EXISTS "ride_part_update" ON ride_participants;
CREATE POLICY "ride_part_update" ON ride_participants FOR UPDATE
    USING (auth.uid() = user_id);

-- ── 2. trip_participants: mesmo padrão de status ────────────────────────────
ALTER TABLE trip_participants
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'waiting';

DROP POLICY IF EXISTS "trip_part_update" ON trip_participants;
CREATE POLICY "trip_part_update" ON trip_participants FOR UPDATE
    USING (auth.uid() = user_id);

-- ── 3. ride_locations: posição em tempo real dos participantes ──────────────
-- Uma linha por (ride_id, user_id), atualizada pelo GPS via upsert.
CREATE TABLE IF NOT EXISTS ride_locations (
    ride_id    UUID REFERENCES rides(id) ON DELETE CASCADE NOT NULL,
    user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    lat        DOUBLE PRECISION NOT NULL,
    lng        DOUBLE PRECISION NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (ride_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_ride_locations_ride ON ride_locations(ride_id);

ALTER TABLE ride_locations ENABLE ROW LEVEL SECURITY;

-- Qualquer participante do rolê pode ler as localizações dos outros.
-- (Simplificação: qualquer authenticated lê. Se quiser restringir só aos
-- participantes, troca o USING por um EXISTS em ride_participants.)
DROP POLICY IF EXISTS "ride_loc_select" ON ride_locations;
CREATE POLICY "ride_loc_select" ON ride_locations FOR SELECT
    USING (auth.uid() IS NOT NULL);

-- Cada usuário só publica a SUA própria localização.
DROP POLICY IF EXISTS "ride_loc_insert" ON ride_locations;
CREATE POLICY "ride_loc_insert" ON ride_locations FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "ride_loc_update" ON ride_locations;
CREATE POLICY "ride_loc_update" ON ride_locations FOR UPDATE
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "ride_loc_delete" ON ride_locations;
CREATE POLICY "ride_loc_delete" ON ride_locations FOR DELETE
    USING (auth.uid() = user_id);


-- ////////////////////////////////////////////////////////////////////////////
-- 008_invite_ride_participants_rpc.sql
-- ////////////////////////////////////////////////////////////////////////////

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC invite_ride_participants
--
-- Permite ao CRIADOR do rolê adicionar amigos em ride_participants. A política
-- RLS dessa tabela só deixa o próprio usuário se inserir (auth.uid() = user_id),
-- então sem essa função o batch insert em createRide falha silenciosamente e
-- os convidados nunca entram no rolê.
--
-- Esta função roda com SECURITY DEFINER (privilégios do dono da função) mas
-- restringe acesso checando que o auth.uid() é o creator_id do rolê.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.invite_ride_participants(
    p_ride_id UUID,
    p_user_ids UUID[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Só o criador do rolê pode convidar
    IF NOT EXISTS (
        SELECT 1 FROM rides
        WHERE id = p_ride_id AND creator_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only the ride creator can invite participants';
    END IF;

    -- Insere (ou ignora duplicatas) cada user_id como participante com
    -- status 'waiting' — o usuário convidado depois confirma/recusa.
    INSERT INTO ride_participants (ride_id, user_id, status)
    SELECT p_ride_id, unnest(p_user_ids), 'waiting'
    ON CONFLICT (ride_id, user_id) DO NOTHING;
END;
$$;

-- Permite que usuários autenticados chamem a RPC.
GRANT EXECUTE ON FUNCTION public.invite_ride_participants(UUID, UUID[])
    TO authenticated;


-- ////////////////////////////////////////////////////////////////////////////
-- 009_avatars_bucket.sql
-- ////////////////////////////////////////////////////////////////////////////

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


-- ////////////////////////////////////////////////////////////////////////////
-- 010_realtime_publications.sql
-- ////////////////////////////////////////////////////////////////////////////

-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime publications
--
-- O Supabase usa a publication "supabase_realtime" para entregar mudanças
-- via WebSocket. Em self-hosted essa publication já existe (criada pelo
-- entrypoint do container realtime), mas as tabelas precisam ser
-- explicitamente adicionadas.
--
-- O app inscreve nas seguintes tabelas:
--   - messages           (chat)
--   - notifications      (sininho)
--   - ride_participants  (status na waiting screen)
--   - ride_locations     (mapa em sessão ativa)
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- Cria a publication se ainda não existir (failsafe; normalmente já existe).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END
$$;

-- Adiciona cada tabela à publication (idempotente).
-- ALTER PUBLICATION ... ADD TABLE não tem IF NOT EXISTS, então tratamos
-- a exceção "relation already member" individualmente.
DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY[
        'messages',
        'notifications',
        'ride_participants',
        'trip_participants',
        'ride_locations'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables
    LOOP
        BEGIN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
        EXCEPTION
            WHEN duplicate_object THEN
                -- tabela já está na publication, segue
                NULL;
            WHEN undefined_table THEN
                -- tabela não existe ainda (aplique a migração que cria antes)
                RAISE NOTICE 'Tabela % não encontrada — pulei', tbl;
        END;
    END LOOP;
END
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- 011_fix_friendships_insert_policy.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Ao aceitar um convite, acceptFriendRequest insere as DUAS linhas da amizade
-- bidirecional num único upsert. A política antiga (auth.uid() = user_id) só
-- aprovava uma delas; como é INSERT em batch, a linha reprovada derrubava o
-- statement inteiro e nenhuma amizade era criada. Liberar os dois lados resolve.
DROP POLICY IF EXISTS "friendships_insert" ON friendships;
CREATE POLICY "friendships_insert" ON friendships FOR INSERT
    WITH CHECK (auth.uid() = user_id OR auth.uid() = friend_id);

-- ═════════════════════════════════════════════════════════════════════════════
-- 012_account_type.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Tipo de conta (pessoal vs empresa). Perfis empresa poderão futuramente criar
-- eventos com programação na tela inicial.
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS account_type TEXT NOT NULL DEFAULT 'personal';

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

-- ═════════════════════════════════════════════════════════════════════════════
-- 013_business_profile.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Campos do perfil empresa. Mantidos separados dos campos pessoais (name, bio)
-- pra que alternar account_type não sobrescreva nada.
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

-- ═════════════════════════════════════════════════════════════════════════════
-- 014_events.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Eventos criados por perfis empresa (local, data, programação). Aparecem na
-- home filtrados pela UF do usuário e na busca. "Tenho interesse" com contador
-- mantido por trigger em events.interests_count.
CREATE TABLE IF NOT EXISTS events (
    id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    creator_id      UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    title           TEXT NOT NULL,
    description     TEXT,
    banner_url      TEXT,
    lat             DOUBLE PRECISION,
    lng             DOUBLE PRECISION,
    address         TEXT,
    location_label  TEXT,
    state_uf        TEXT,
    city            TEXT,
    starts_at       TIMESTAMPTZ NOT NULL,
    ends_at         TIMESTAMPTZ,
    interests_count INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_events_state_starts ON events(state_uf, starts_at);
CREATE INDEX IF NOT EXISTS idx_events_creator       ON events(creator_id);

CREATE TABLE IF NOT EXISTS event_schedule_items (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id    UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    position    INT NOT NULL DEFAULT 0,
    time_label  TEXT,
    title       TEXT NOT NULL,
    description TEXT
);
CREATE INDEX IF NOT EXISTS idx_event_schedule_event ON event_schedule_items(event_id);

CREATE TABLE IF NOT EXISTS event_interests (
    event_id   UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_event_interests_user ON event_interests(user_id);

CREATE OR REPLACE FUNCTION public.sync_event_interests_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE events SET interests_count = interests_count + 1 WHERE id = NEW.event_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE events SET interests_count = GREATEST(interests_count - 1, 0) WHERE id = OLD.event_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_event_interests_count ON event_interests;
CREATE TRIGGER trg_event_interests_count
    AFTER INSERT OR DELETE ON event_interests
    FOR EACH ROW EXECUTE FUNCTION public.sync_event_interests_count();

ALTER TABLE events               ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_schedule_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_interests      ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "events_select" ON events;
CREATE POLICY "events_select" ON events FOR SELECT USING (true);
DROP POLICY IF EXISTS "events_insert" ON events;
CREATE POLICY "events_insert" ON events FOR INSERT
    WITH CHECK (
        auth.uid() = creator_id
        AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND account_type = 'business')
    );
DROP POLICY IF EXISTS "events_update" ON events;
CREATE POLICY "events_update" ON events FOR UPDATE USING (auth.uid() = creator_id);
DROP POLICY IF EXISTS "events_delete" ON events;
CREATE POLICY "events_delete" ON events FOR DELETE USING (auth.uid() = creator_id);

DROP POLICY IF EXISTS "event_schedule_select" ON event_schedule_items;
CREATE POLICY "event_schedule_select" ON event_schedule_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "event_schedule_write" ON event_schedule_items;
CREATE POLICY "event_schedule_write" ON event_schedule_items FOR ALL
    USING (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.creator_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.creator_id = auth.uid()));

DROP POLICY IF EXISTS "event_interests_select" ON event_interests;
CREATE POLICY "event_interests_select" ON event_interests FOR SELECT USING (true);
DROP POLICY IF EXISTS "event_interests_insert" ON event_interests;
CREATE POLICY "event_interests_insert" ON event_interests FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "event_interests_delete" ON event_interests;
CREATE POLICY "event_interests_delete" ON event_interests FOR DELETE USING (auth.uid() = user_id);

DO $$
BEGIN
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.events;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
    BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.event_interests;
    EXCEPTION WHEN duplicate_object THEN NULL; END;
END
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- 015_event_sponsors_participants.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Patrocinadores (texto + logo) e participantes extras (usuários do app).
-- Gerenciados pelo criador do evento.
CREATE TABLE IF NOT EXISTS event_sponsors (
    id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id  UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    position  INT NOT NULL DEFAULT 0,
    name      TEXT NOT NULL,
    logo_url  TEXT
);
CREATE INDEX IF NOT EXISTS idx_event_sponsors_event ON event_sponsors(event_id);

CREATE TABLE IF NOT EXISTS event_participants (
    event_id  UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    user_id   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_event_participants_event ON event_participants(event_id);

ALTER TABLE event_sponsors      ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "event_sponsors_select" ON event_sponsors;
CREATE POLICY "event_sponsors_select" ON event_sponsors FOR SELECT USING (true);
DROP POLICY IF EXISTS "event_sponsors_write" ON event_sponsors;
CREATE POLICY "event_sponsors_write" ON event_sponsors FOR ALL
    USING (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.creator_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.creator_id = auth.uid()));

DROP POLICY IF EXISTS "event_participants_select" ON event_participants;
CREATE POLICY "event_participants_select" ON event_participants FOR SELECT USING (true);
DROP POLICY IF EXISTS "event_participants_write" ON event_participants;
CREATE POLICY "event_participants_write" ON event_participants FOR ALL
    USING (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.creator_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM events e WHERE e.id = event_id AND e.creator_id = auth.uid()));


-- ═════════════════════════════════════════════════════════════════════════════
-- 016_session_photos_fk.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Permite que fotos de ROLÊ usem trip_photos/featured_photos (a FK rígida pra
-- trips rejeitava ids de rolê com "not present in table trips").
ALTER TABLE trip_photos
    DROP CONSTRAINT IF EXISTS trip_photos_trip_id_fkey;
ALTER TABLE featured_photos
    DROP CONSTRAINT IF EXISTS featured_photos_trip_id_fkey;

-- ═════════════════════════════════════════════════════════════════════════════
-- 017_device_tokens.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Tokens FCM por usuário (push). PK no token; worker lê via service_role.
CREATE TABLE IF NOT EXISTS device_tokens (
    token      TEXT PRIMARY KEY,
    user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    platform   TEXT NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "device_tokens_select" ON device_tokens;
CREATE POLICY "device_tokens_select" ON device_tokens FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "device_tokens_insert" ON device_tokens;
CREATE POLICY "device_tokens_insert" ON device_tokens FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "device_tokens_update" ON device_tokens;
CREATE POLICY "device_tokens_update" ON device_tokens FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "device_tokens_delete" ON device_tokens;
CREATE POLICY "device_tokens_delete" ON device_tokens FOR DELETE USING (auth.uid() = user_id);

-- ═════════════════════════════════════════════════════════════════════════════
-- 018_user_photos_bucket.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Bucket de fotos do perfil ("Suas Fotos"). Ficou de fora na migração da VPS
-- (era criado à mão no painel antigo) → upload falhava com "Bucket not found".
INSERT INTO storage.buckets (id, name, public)
VALUES ('user-photos', 'user-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "user_photos_storage_insert" ON storage.objects;
CREATE POLICY "user_photos_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'user-photos'
        AND auth.role() = 'authenticated'
    );

DROP POLICY IF EXISTS "user_photos_storage_delete" ON storage.objects;
CREATE POLICY "user_photos_storage_delete"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'user-photos'
        AND auth.uid() = owner
    );

-- ═════════════════════════════════════════════════════════════════════════════
-- 019_e2ee_chat.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Criptografia ponta a ponta do chat: guarda só a chave pública de cada
-- usuário. Mensagens cifradas no cliente; servidor não lê. Apaga histórico
-- antigo em texto puro.
CREATE TABLE IF NOT EXISTS user_keys (
    user_id    UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    public_key TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE user_keys ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_keys_select" ON user_keys;
CREATE POLICY "user_keys_select" ON user_keys FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "user_keys_insert" ON user_keys;
CREATE POLICY "user_keys_insert" ON user_keys FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "user_keys_update" ON user_keys;
CREATE POLICY "user_keys_update" ON user_keys FOR UPDATE USING (auth.uid() = user_id);
TRUNCATE TABLE messages;

-- ═════════════════════════════════════════════════════════════════════════════
-- 020_profile_customization.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Personalização de perfil: banner, moldura do avatar, cor de fundo e de texto.
-- Colunas de cor são opcionais (NULL = usa o padrão do app). Visível também
-- para quem visita o perfil.
CREATE TABLE IF NOT EXISTS profile_customizations (
    user_id          UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    banner_url       TEXT,
    avatar_frame     TEXT NOT NULL DEFAULT 'none',
    background_color TEXT,
    text_color       TEXT,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE profile_customizations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "profile_customizations_select" ON profile_customizations;
CREATE POLICY "profile_customizations_select" ON profile_customizations
    FOR SELECT USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS "profile_customizations_insert" ON profile_customizations;
CREATE POLICY "profile_customizations_insert" ON profile_customizations
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "profile_customizations_update" ON profile_customizations;
CREATE POLICY "profile_customizations_update" ON profile_customizations
    FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "profile_customizations_delete" ON profile_customizations;
CREATE POLICY "profile_customizations_delete" ON profile_customizations
    FOR DELETE USING (auth.uid() = user_id);

-- ═════════════════════════════════════════════════════════════════════════════
-- 021_rides_count.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Contagem de rolês criados/participados (mesmo padrão de trips_count).
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS rides_count INT DEFAULT 0;

CREATE OR REPLACE FUNCTION public.update_rides_count(p_user_id UUID)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE profiles
  SET rides_count = (
    SELECT COUNT(*) FROM ride_participants WHERE user_id = p_user_id
  )
  WHERE id = p_user_id;
END;
$$;

SELECT public.update_rides_count(id) FROM profiles;

-- ═════════════════════════════════════════════════════════════════════════════
-- 022_fix_storage_rls_authrole.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Corrige RLS de storage.objects que usava auth.role() = 'authenticated'.
-- Troca para auth.uid() IS NOT NULL (mesmo padrão já usado em outras tabelas).
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

DROP POLICY IF EXISTS "trip_photos_storage_insert" ON storage.objects;
CREATE POLICY "trip_photos_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'trip-photos'
        AND auth.uid() IS NOT NULL
    );

DROP POLICY IF EXISTS "chat_images_storage_insert" ON storage.objects;
CREATE POLICY "chat_images_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'chat-images'
        AND auth.uid() IS NOT NULL
    );

DROP POLICY IF EXISTS "user_photos_storage_insert" ON storage.objects;
CREATE POLICY "user_photos_storage_insert"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'user-photos'
        AND auth.uid() IS NOT NULL
    );

-- ═════════════════════════════════════════════════════════════════════════════
-- 023_clubs.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────────────────────
-- Motoclubes: clubes, membros/convites, eventos e viagens do clube, roteiro de
-- viagem e lista de presença (RSVP + check-in).
--
-- Reaproveita as tabelas existentes: eventos e viagens ganham um club_id
-- opcional; a lista de presença usa colunas novas nos participantes.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. clubs ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clubs (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  name        TEXT NOT NULL,
  description TEXT,
  avatar_url  TEXT,
  banner_url  TEXT,
  city        TEXT,
  state_uf    TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_clubs_owner ON clubs(owner_id);
CREATE INDEX IF NOT EXISTS idx_clubs_state ON clubs(state_uf);

-- ── 2. club_members (membros + convites) ────────────────────
-- status: 'invited' = convidado, aguardando aceite | 'active' = membro
CREATE TABLE IF NOT EXISTS club_members (
  club_id    UUID REFERENCES clubs(id) ON DELETE CASCADE NOT NULL,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  role       TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner','admin','member')),
  status     TEXT NOT NULL DEFAULT 'active'  CHECK (status IN ('invited','active')),
  invited_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (club_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_club_members_user ON club_members(user_id);

-- ── 3. Helpers (SECURITY DEFINER evita recursão de RLS) ─────
CREATE OR REPLACE FUNCTION public.is_club_member(p_club UUID, p_user UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (SELECT 1 FROM club_members
    WHERE club_id = p_club AND user_id = p_user AND status = 'active');
$$;
CREATE OR REPLACE FUNCTION public.is_club_admin(p_club UUID, p_user UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (SELECT 1 FROM club_members
    WHERE club_id = p_club AND user_id = p_user
      AND status = 'active' AND role IN ('owner','admin'));
$$;

-- ── 4. Trigger: dono vira membro (owner/active) ao criar clube
CREATE OR REPLACE FUNCTION public.handle_new_club()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO club_members (club_id, user_id, role, status)
  VALUES (NEW.id, NEW.owner_id, 'owner', 'active')
  ON CONFLICT (club_id, user_id) DO NOTHING;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_new_club ON clubs;
CREATE TRIGGER trg_new_club AFTER INSERT ON clubs
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_club();

-- ── 5. RLS: clubs ───────────────────────────────────────────
ALTER TABLE clubs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "clubs_select" ON clubs;
CREATE POLICY "clubs_select" ON clubs FOR SELECT USING (true);
DROP POLICY IF EXISTS "clubs_insert" ON clubs;
CREATE POLICY "clubs_insert" ON clubs FOR INSERT WITH CHECK (auth.uid() = owner_id);
DROP POLICY IF EXISTS "clubs_update" ON clubs;
CREATE POLICY "clubs_update" ON clubs FOR UPDATE USING (public.is_club_admin(id, auth.uid()));
DROP POLICY IF EXISTS "clubs_delete" ON clubs;
CREATE POLICY "clubs_delete" ON clubs FOR DELETE USING (auth.uid() = owner_id);

-- ── 6. RLS: club_members ────────────────────────────────────
ALTER TABLE club_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "club_members_select" ON club_members;
CREATE POLICY "club_members_select" ON club_members FOR SELECT USING (true);
DROP POLICY IF EXISTS "club_members_insert" ON club_members;   -- admin convida
CREATE POLICY "club_members_insert" ON club_members FOR INSERT
  WITH CHECK (public.is_club_admin(club_id, auth.uid()));
DROP POLICY IF EXISTS "club_members_update" ON club_members;   -- aceitar convite / mudar papel
CREATE POLICY "club_members_update" ON club_members FOR UPDATE
  USING (user_id = auth.uid() OR public.is_club_admin(club_id, auth.uid()));
DROP POLICY IF EXISTS "club_members_delete" ON club_members;   -- sair / remover
CREATE POLICY "club_members_delete" ON club_members FOR DELETE
  USING (user_id = auth.uid() OR public.is_club_admin(club_id, auth.uid()));

-- ── 7. Eventos e viagens do clube (reusa tabelas existentes) ─
ALTER TABLE events ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES clubs(id) ON DELETE CASCADE;
ALTER TABLE trips  ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES clubs(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_events_club ON events(club_id);
CREATE INDEX IF NOT EXISTS idx_trips_club  ON trips(club_id);

-- events: empresa OU admin de clube pode criar/editar evento do clube
DROP POLICY IF EXISTS "events_insert" ON events;
CREATE POLICY "events_insert" ON events FOR INSERT WITH CHECK (
  auth.uid() = creator_id AND (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND account_type = 'business')
    OR (club_id IS NOT NULL AND public.is_club_admin(club_id, auth.uid()))
  ));
DROP POLICY IF EXISTS "events_update" ON events;
CREATE POLICY "events_update" ON events FOR UPDATE USING (
  auth.uid() = creator_id OR (club_id IS NOT NULL AND public.is_club_admin(club_id, auth.uid())));
DROP POLICY IF EXISTS "events_delete" ON events;
CREATE POLICY "events_delete" ON events FOR DELETE USING (
  auth.uid() = creator_id OR (club_id IS NOT NULL AND public.is_club_admin(club_id, auth.uid())));

-- trips: admin de clube também edita/exclui viagem do clube
DROP POLICY IF EXISTS "trips_update" ON trips;
CREATE POLICY "trips_update" ON trips FOR UPDATE USING (
  auth.uid() = creator_id OR (club_id IS NOT NULL AND public.is_club_admin(club_id, auth.uid())));
DROP POLICY IF EXISTS "trips_delete" ON trips;
CREATE POLICY "trips_delete" ON trips FOR DELETE USING (
  auth.uid() = creator_id OR (club_id IS NOT NULL AND public.is_club_admin(club_id, auth.uid())));

-- ── 8. Roteiro de viagem (eventos já têm event_schedule_items)
CREATE TABLE IF NOT EXISTS trip_schedule_items (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id     UUID REFERENCES trips(id) ON DELETE CASCADE NOT NULL,
  position    INT NOT NULL DEFAULT 0,
  time_label  TEXT,
  title       TEXT NOT NULL,
  description TEXT
);
CREATE INDEX IF NOT EXISTS idx_trip_schedule_trip ON trip_schedule_items(trip_id);
ALTER TABLE trip_schedule_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "trip_schedule_select" ON trip_schedule_items;
CREATE POLICY "trip_schedule_select" ON trip_schedule_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "trip_schedule_write" ON trip_schedule_items;
CREATE POLICY "trip_schedule_write" ON trip_schedule_items FOR ALL
  USING (EXISTS (SELECT 1 FROM trips t WHERE t.id = trip_id AND (
    t.creator_id = auth.uid() OR (t.club_id IS NOT NULL AND public.is_club_admin(t.club_id, auth.uid())))))
  WITH CHECK (EXISTS (SELECT 1 FROM trips t WHERE t.id = trip_id AND (
    t.creator_id = auth.uid() OR (t.club_id IS NOT NULL AND public.is_club_admin(t.club_id, auth.uid())))));

-- ── 9. Lista de presença (RSVP + check-in) ──────────────────
-- rsvp: 'going' | 'maybe' | 'declined' ; checked_in marcado pelo líder no dia.
ALTER TABLE event_participants ADD COLUMN IF NOT EXISTS rsvp TEXT CHECK (rsvp IN ('going','maybe','declined'));
ALTER TABLE event_participants ADD COLUMN IF NOT EXISTS checked_in BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE trip_participants  ADD COLUMN IF NOT EXISTS rsvp TEXT CHECK (rsvp IN ('going','maybe','declined'));
ALTER TABLE trip_participants  ADD COLUMN IF NOT EXISTS checked_in BOOLEAN NOT NULL DEFAULT FALSE;

-- event_participants: usuário gerencia a PRÓPRIA linha (auto-RSVP).
-- (trip_participants já permite self insert/update/delete.)
DROP POLICY IF EXISTS "event_participants_self" ON event_participants;
CREATE POLICY "event_participants_self" ON event_participants FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- ── 10. Realtime (roster e presença ao vivo) ────────────────
DO $$
BEGIN
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.club_members; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.clubs;        EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;

-- ═════════════════════════════════════════════════════════════════════════════
-- 024_harden_function_search_path.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────────────────────
-- Hardening: fixa o search_path das funções SECURITY DEFINER/trigger.
--
-- Resolve o aviso do linter "function_search_path_mutable" (risco de injeção de
-- search_path em funções SECURITY DEFINER). Não altera comportamento: todas as
-- funções referenciam apenas objetos do schema public.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.update_trips_count(uuid)        SET search_path = public;
ALTER FUNCTION public.update_friends_count(uuid)      SET search_path = public;
ALTER FUNCTION public.sync_event_interests_count()    SET search_path = public;
ALTER FUNCTION public.update_rides_count(uuid)        SET search_path = public;
ALTER FUNCTION public.is_club_member(uuid, uuid)      SET search_path = public;
ALTER FUNCTION public.is_club_admin(uuid, uuid)       SET search_path = public;
ALTER FUNCTION public.handle_new_club()               SET search_path = public;

-- ═════════════════════════════════════════════════════════════════════════════
-- 025_fix_event_interests_count.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────────────────────
-- Corrige o contador de interesse dos eventos.
--
-- O trigger sync_event_interests_count fazia UPDATE em events, mas rodava com
-- os privilégios de quem marcava interesse. Como a policy events_update só
-- permite o criador/admin editar o evento, o UPDATE do contador era bloqueado
-- pelo RLS quando OUTRA pessoa marcava interesse → interests_count nunca subia.
--
-- Solução: recriar a função como SECURITY DEFINER (roda como dono, ignora RLS
-- só para manter o contador). Também faz backfill dos contadores defasados.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sync_event_interests_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE events SET interests_count = interests_count + 1
        WHERE id = NEW.event_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE events SET interests_count = GREATEST(interests_count - 1, 0)
        WHERE id = OLD.event_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- Backfill: recalcula os contadores que ficaram defasados.
UPDATE events e SET interests_count = (
    SELECT COUNT(*) FROM event_interests i WHERE i.event_id = e.id
);

-- ═════════════════════════════════════════════════════════════════════════════
-- 026_club_role_owner_only.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────────────────────
-- Restringe a mudança de papel (promover/rebaixar gerente) ao DONO do clube.
--
-- Antes, a policy de UPDATE em club_members permitia qualquer admin (gerente)
-- alterar papéis. Agora só o dono pode. Gerentes continuam podendo EXPULSAR
-- (policy de DELETE, inalterada) e o próprio usuário continua podendo aceitar
-- convite (atualizar a própria linha).
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "club_members_update" ON club_members;
CREATE POLICY "club_members_update" ON club_members FOR UPDATE
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM clubs c
            WHERE c.id = club_id AND c.owner_id = auth.uid()
        )
    );

-- ═════════════════════════════════════════════════════════════════════════════
-- 028_club_event_visibility.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────────────────────
-- Privacidade dos eventos de motoclube (público/privado).
--
-- Cada clube tem `events_public` (setado nas Configurações do Motoclube). Cada
-- evento tem `is_public` (denormalizado, mantido em sincronia por triggers):
--   - evento que NÃO é de clube  → sempre público
--   - evento de clube            → herda o events_public do clube
--
-- O feed por região mostra só eventos públicos; os privados de clube ficam
-- restritos aos membros (via RLS + mural do clube). Viagens de clube seguem a
-- mesma lógica de visibilidade.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Colunas ──────────────────────────────────────────────
ALTER TABLE clubs  ADD COLUMN IF NOT EXISTS events_public BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE events ADD COLUMN IF NOT EXISTS is_public     BOOLEAN NOT NULL DEFAULT true;
CREATE INDEX IF NOT EXISTS idx_events_public ON events(is_public);

-- ── 2. Evento novo herda a visibilidade do clube ────────────
CREATE OR REPLACE FUNCTION public.set_event_visibility()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.club_id IS NOT NULL THEN
    NEW.is_public := COALESCE(
      (SELECT events_public FROM clubs WHERE id = NEW.club_id), false);
  ELSE
    NEW.is_public := true;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_event_visibility ON events;
CREATE TRIGGER trg_event_visibility BEFORE INSERT ON events
  FOR EACH ROW EXECUTE FUNCTION public.set_event_visibility();

-- ── 3. Ao trocar a visibilidade do clube, sincroniza os eventos
CREATE OR REPLACE FUNCTION public.sync_club_events_visibility()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.events_public IS DISTINCT FROM OLD.events_public THEN
    UPDATE events SET is_public = NEW.events_public WHERE club_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_sync_club_events_vis ON clubs;
CREATE TRIGGER trg_sync_club_events_vis AFTER UPDATE ON clubs
  FOR EACH ROW EXECUTE FUNCTION public.sync_club_events_visibility();

-- ── 4. RLS: privados de clube só para membros ───────────────
DROP POLICY IF EXISTS "events_select" ON events;
CREATE POLICY "events_select" ON events FOR SELECT
  USING (is_public OR (club_id IS NOT NULL AND public.is_club_member(club_id, auth.uid())));

DROP POLICY IF EXISTS "trips_select" ON trips;
CREATE POLICY "trips_select" ON trips FOR SELECT
  USING (
    club_id IS NULL
    OR public.is_club_member(club_id, auth.uid())
    OR EXISTS (SELECT 1 FROM clubs c WHERE c.id = trips.club_id AND c.events_public)
  );

-- ── 5. Backfill: eventos de clube herdam a visibilidade atual ─
UPDATE events e SET is_public = COALESCE(
  (SELECT c.events_public FROM clubs c WHERE c.id = e.club_id), true)
WHERE e.club_id IS NOT NULL;

-- ═════════════════════════════════════════════════════════════════════════════
-- 029_nearby_riders_privacy.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- ─────────────────────────────────────────────────────────────────────────────
-- Descoberta de riders próximos + privacidade.
--
-- profiles.discoverable → aparece na descoberta de riders próximos.
-- profiles.is_private   → perfil privado (não-amigo vê só o básico).
-- rider_locations       → última localização do usuário, em tabela separada
--                         para que a COORDENADA nunca seja legível por outros
--                         (só o dono lê/escreve). A descoberta usa a RPC abaixo,
--                         que roda como SECURITY DEFINER e devolve só a DISTÂNCIA.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Flags de privacidade no perfil ──────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS discoverable BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_private   BOOLEAN NOT NULL DEFAULT false;

-- ── 2. Localização do rider (privada por RLS) ──────────────
CREATE TABLE IF NOT EXISTS rider_locations (
  user_id    UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  lat        DOUBLE PRECISION NOT NULL,
  lng        DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE rider_locations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "rider_loc_self" ON rider_locations;
CREATE POLICY "rider_loc_self" ON rider_locations FOR ALL
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── 3. RPC: riders próximos (só distância, nunca coordenadas) ─
CREATE OR REPLACE FUNCTION public.nearby_riders(
  p_lat double precision, p_lng double precision, p_limit int DEFAULT 60)
RETURNS TABLE (
  id uuid,
  name text,
  username text,
  avatar_url text,
  moto_model text,
  trip_style text,
  distance_km double precision)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.id, p.name, p.username, p.avatar_url, p.moto_model, p.trip_style,
    6371 * acos(greatest(-1, least(1,
      cos(radians(p_lat)) * cos(radians(rl.lat)) *
      cos(radians(rl.lng) - radians(p_lng)) +
      sin(radians(p_lat)) * sin(radians(rl.lat))
    ))) AS distance_km
  FROM rider_locations rl
  JOIN profiles p ON p.id = rl.user_id
  WHERE p.discoverable = true
    AND p.id <> auth.uid()
  ORDER BY distance_km ASC
  LIMIT p_limit;
$$;

-- ═════════════════════════════════════════════════════════════════════════════
-- 030_multi_device_chat_keys.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- E2EE multi-dispositivo (app + web). Antes user_keys tinha UMA chave por
-- usuário: logar em outro dispositivo sobrescrevia a pública e o aparelho
-- anterior parava de decifrar. Agora cada aparelho publica a própria chave,
-- identificada por device_id, e a mensagem vira um envelope com uma cópia
-- cifrada por dispositivo.

ALTER TABLE user_keys ADD COLUMN IF NOT EXISTS device_id TEXT;
UPDATE user_keys SET device_id = 'legacy' WHERE device_id IS NULL;
ALTER TABLE user_keys ALTER COLUMN device_id SET NOT NULL;

ALTER TABLE user_keys DROP CONSTRAINT IF EXISTS user_keys_pkey;
ALTER TABLE user_keys ADD CONSTRAINT user_keys_pkey PRIMARY KEY (user_id, device_id);

CREATE INDEX IF NOT EXISTS idx_user_keys_user ON user_keys(user_id);

DROP POLICY IF EXISTS "user_keys_delete" ON user_keys;
CREATE POLICY "user_keys_delete" ON user_keys FOR DELETE USING (auth.uid() = user_id);

-- Mensagens antigas ficariam ilegíveis no novo formato — começar limpo.
TRUNCATE TABLE messages;

-- ═════════════════════════════════════════════════════════════════════════════
-- 031_messages_rls.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Privacidade das mensagens (antes QUALQUER autenticado lia TODAS) e permissão
-- de marcar como lida (não existia UPDATE, então o contador não zerava).
-- chat_id é canônico: os dois UUIDs ordenados unidos por "_".

DROP POLICY IF EXISTS "messages_select" ON messages;
CREATE POLICY "messages_select" ON messages FOR SELECT USING (
  auth.uid()::text = split_part(chat_id, '_', 1)
  OR auth.uid()::text = split_part(chat_id, '_', 2)
);

DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (
    auth.uid()::text = split_part(chat_id, '_', 1)
    OR auth.uid()::text = split_part(chat_id, '_', 2)
  )
);

DROP POLICY IF EXISTS "messages_update_read" ON messages;
CREATE POLICY "messages_update_read" ON messages FOR UPDATE
  USING (
    auth.uid() <> sender_id AND (
      auth.uid()::text = split_part(chat_id, '_', 1)
      OR auth.uid()::text = split_part(chat_id, '_', 2)
    )
  )
  WITH CHECK (
    auth.uid() <> sender_id AND (
      auth.uid()::text = split_part(chat_id, '_', 1)
      OR auth.uid()::text = split_part(chat_id, '_', 2)
    )
  );

CREATE INDEX IF NOT EXISTS idx_messages_unread
  ON messages(chat_id, sender_id) WHERE is_read = false;

-- ═════════════════════════════════════════════════════════════════════════════
-- 032_trip_stops.sql
-- ═════════════════════════════════════════════════════════════════════════════
-- Paradas da viagem. O TripModel já tinha `stops` e o buildGoogleMapsUrl() já
-- as incluía como waypoints, mas não havia onde guardá-las.
-- Policies espelham trip_schedule_items (filha de trips).

CREATE TABLE IF NOT EXISTS trip_stops (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id     UUID REFERENCES trips(id) ON DELETE CASCADE NOT NULL,
  position    INT NOT NULL DEFAULT 0,
  name        TEXT NOT NULL,
  category    TEXT NOT NULL DEFAULT 'other',
  description TEXT,
  image_url   TEXT,
  lat         DOUBLE PRECISION NOT NULL,
  lng         DOUBLE PRECISION NOT NULL,
  address     TEXT
);

CREATE INDEX IF NOT EXISTS idx_trip_stops_trip ON trip_stops(trip_id, position);

ALTER TABLE trip_stops ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trip_stops_select" ON trip_stops;
CREATE POLICY "trip_stops_select" ON trip_stops FOR SELECT USING (true);

DROP POLICY IF EXISTS "trip_stops_write" ON trip_stops;
CREATE POLICY "trip_stops_write" ON trip_stops FOR ALL
  USING (EXISTS (SELECT 1 FROM trips t WHERE t.id = trip_id AND (
    t.creator_id = auth.uid() OR (t.club_id IS NOT NULL AND public.is_club_admin(t.club_id, auth.uid())))))
  WITH CHECK (EXISTS (SELECT 1 FROM trips t WHERE t.id = trip_id AND (
    t.creator_id = auth.uid() OR (t.club_id IS NOT NULL AND public.is_club_admin(t.club_id, auth.uid())))));


-- 033: aponta as URLs salvas para o domínio novo da API.
--
-- Contexto: a API saiu de srv1689008.hstgr.cloud (hostname da Hostinger, que
-- publica o IP da VPS e não passa pela Cloudflare) para api.ride.dev.br, atrás
-- da Cloudflare. O passo seguinte é aceitar conexões na 443 só vindas da
-- Cloudflare — e aí o host antigo deixa de responder.
--
-- Estas colunas guardam URL ABSOLUTA. O app monta URLs novas a partir de
-- SupabaseConfig.url, então só os registros antigos ficam presos ao host velho;
-- sem esta migration, banners de evento, capas de viagem, fotos e avatares
-- parariam de carregar.
--
-- replace() troca só o host e preserva caminho e query — a URL de foto do proxy
-- gmaps leva parâmetros que não podem ser perdidos.
--
-- Reversível: basta rodar o mesmo com os domínios invertidos.

UPDATE events      SET banner_url  = replace(banner_url,  'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE banner_url  LIKE '%srv1689008.hstgr.cloud%';

UPDATE trips       SET cover_image = replace(cover_image, 'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE cover_image LIKE '%srv1689008.hstgr.cloud%';

UPDATE profiles    SET avatar_url  = replace(avatar_url,  'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE avatar_url  LIKE '%srv1689008.hstgr.cloud%';

UPDATE trip_photos SET photo_url   = replace(photo_url,   'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE photo_url   LIKE '%srv1689008.hstgr.cloud%';

UPDATE trip_stops  SET image_url   = replace(image_url,   'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE image_url   LIKE '%srv1689008.hstgr.cloud%';


-- ─────────────────────────────────────────────────────────────────────────────
-- 034: desativação de conta (LGPD) + visibilidade por evento/viagem
--
-- PARTE 1 — Desativação
-- A lei brasileira exige guardar os dados por pelo menos 6 meses, então
-- "excluir perfil" não apaga: desliga. Os dados pessoais saem de `profiles` e
-- vão para `profiles_archive`, que NINGUÉM lê — nem anônimo, nem logado (RLS
-- ligada e nenhuma policy; só o service_role ignora RLS). É essa tabela que
-- cumpre a retenção. Em `profiles` fica "Usuário inativo" e o resto em branco.
--
-- Anonimizar só no app Flutter não serviria: qualquer um com a chave anônima
-- continuaria lendo nome, bio e fotos pela API REST.
--
-- PARTE 2 — Visibilidade
-- Sai o interruptor único do motoclube (`clubs.events_public`); cada evento e
-- cada viagem passa a ter o seu. O trigger que herdava a visibilidade do clube
-- SOBRESCREVIA o valor enviado, então a escolha da tela seria descartada.
-- ─────────────────────────────────────────────────────────────────────────────

-- ══ PARTE 1: DESATIVAÇÃO ════════════════════════════════════════════════════

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_profiles_deactivated
  ON profiles(deactivated_at) WHERE deactivated_at IS NOT NULL;

-- Retenção legal. Sem nenhuma policy de propósito: RLS ligada + zero policies
-- = ninguém lê pela API. Só o service_role (worker/psql) enxerga.
CREATE TABLE IF NOT EXISTS profiles_archive (
  id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  data           JSONB NOT NULL,
  deactivated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE profiles_archive ENABLE ROW LEVEL SECURITY;

-- ── Desativar a própria conta ───────────────────────────────
CREATE OR REPLACE FUNCTION public.deactivate_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'É preciso estar logado para desativar a conta';
  END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE id = uid AND deactivated_at IS NOT NULL) THEN
    RETURN; -- já está desativada
  END IF;

  INSERT INTO profiles_archive (id, data, deactivated_at)
  SELECT p.id, to_jsonb(p), NOW() FROM profiles p WHERE p.id = uid
  ON CONFLICT (id) DO UPDATE
    SET data = EXCLUDED.data, deactivated_at = EXCLUDED.deactivated_at;

  UPDATE profiles SET
    name        = 'Usuário inativo',
    -- username é UNIQUE NOT NULL: não pode ficar nulo nem repetir.
    username    = 'inativo_' || left(replace(uid::text, '-', ''), 12),
    avatar_url  = NULL,
    bio         = NULL,
    city        = NULL,
    moto_model  = NULL,
    moto_year   = NULL,
    trip_style  = NULL,
    photos      = '{}',
    business_name               = NULL,
    business_description        = NULL,
    business_banner_url         = NULL,
    business_address_street     = NULL,
    business_address_number     = NULL,
    business_address_neighborhood = NULL,
    business_address_city       = NULL,
    business_address_state      = NULL,
    business_categories         = '{}',
    discoverable = FALSE,   -- some da busca por proximidade
    is_private   = TRUE,
    is_online    = FALSE,
    deactivated_at = NOW()
  WHERE id = uid;

  -- Localização e push: desligamento total.
  DELETE FROM rider_locations WHERE user_id = uid;
  DELETE FROM device_tokens   WHERE user_id = uid;
END; $$;

REVOKE ALL ON FUNCTION public.deactivate_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.deactivate_my_account() TO authenticated;

-- ── Reativar ao voltar a logar ──────────────────────────────
CREATE OR REPLACE FUNCTION public.reactivate_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); d JSONB;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'É preciso estar logado para reativar a conta';
  END IF;
  SELECT data INTO d FROM profiles_archive WHERE id = uid;
  IF d IS NULL THEN RETURN; END IF;

  UPDATE profiles SET
    name        = COALESCE(d->>'name', name),
    username    = COALESCE(d->>'username', username),
    avatar_url  = d->>'avatar_url',
    bio         = d->>'bio',
    city        = d->>'city',
    moto_model  = d->>'moto_model',
    moto_year   = d->>'moto_year',
    trip_style  = d->>'trip_style',
    photos      = COALESCE(
                    ARRAY(SELECT jsonb_array_elements_text(d->'photos')),
                    '{}'),
    business_name               = d->>'business_name',
    business_description        = d->>'business_description',
    business_banner_url         = d->>'business_banner_url',
    business_address_street     = d->>'business_address_street',
    business_address_number     = d->>'business_address_number',
    business_address_neighborhood = d->>'business_address_neighborhood',
    business_address_city       = d->>'business_address_city',
    business_address_state      = d->>'business_address_state',
    business_categories         = COALESCE(
                    ARRAY(SELECT jsonb_array_elements_text(d->'business_categories')),
                    '{}'),
    discoverable = COALESCE((d->>'discoverable')::boolean, TRUE),
    is_private   = COALESCE((d->>'is_private')::boolean, FALSE),
    deactivated_at = NULL
  WHERE id = uid;

  DELETE FROM profiles_archive WHERE id = uid;
END; $$;

REVOKE ALL ON FUNCTION public.reactivate_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reactivate_my_account() TO authenticated;

-- ── Apagar de vez depois da retenção ────────────────────────
-- Chamada por tarefa agendada na VPS (o pg_cron não está instalado e exigiria
-- reiniciar o Postgres). Apagar de auth.users cascateia para profiles e
-- profiles_archive.
CREATE OR REPLACE FUNCTION public.purge_deactivated_accounts(
  older_than INTERVAL DEFAULT '6 months'
) RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n INT;
BEGIN
  WITH alvos AS (
    SELECT id FROM profiles
    WHERE deactivated_at IS NOT NULL AND deactivated_at < NOW() - older_than
  ), apagados AS (
    DELETE FROM auth.users WHERE id IN (SELECT id FROM alvos) RETURNING 1
  )
  SELECT count(*) INTO n FROM apagados;
  RETURN n;
END; $$;

-- ATENCAO: revogar de PUBLIC NAO basta. O Supabase concede EXECUTE direto aos
-- papeis `anon` e `authenticated` em toda funcao nova do schema `public`, e
-- REVOKE ... FROM PUBLIC nao mexe em concessao direta a um papel. Sem as linhas
-- abaixo, qualquer pessoa com a chave anonima chamaria estas funcoes.
REVOKE ALL ON FUNCTION public.purge_deactivated_accounts(INTERVAL)
  FROM PUBLIC, anon, authenticated;

-- ══ PARTE 2: VISIBILIDADE POR EVENTO E POR VIAGEM ═══════════════════════════

-- O trigger herdava do clube e sobrescrevia o que a tela mandasse.
DROP TRIGGER IF EXISTS trg_event_visibility     ON events;
DROP TRIGGER IF EXISTS trg_sync_club_events_vis ON clubs;
DROP FUNCTION IF EXISTS public.set_event_visibility();
DROP FUNCTION IF EXISTS public.sync_club_events_visibility();

-- Viagem ganha o mesmo interruptor do evento.
ALTER TABLE trips ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true;
CREATE INDEX IF NOT EXISTS idx_trips_public ON trips(is_public);

-- Backfill: viagem de clube herda a visibilidade que o clube tinha até agora;
-- viagem pessoal continua pública.
UPDATE trips t SET is_public = COALESCE(
  (SELECT c.events_public FROM clubs c WHERE c.id = t.club_id), TRUE)
WHERE t.club_id IS NOT NULL;

-- ── Policies ────────────────────────────────────────────────
-- Inclui o CRIADOR: sem isso, um evento pessoal marcado como privado ficaria
-- invisível até para quem o criou.
DROP POLICY IF EXISTS "events_select" ON events;
CREATE POLICY "events_select" ON events FOR SELECT
  USING (
    is_public
    OR creator_id = auth.uid()
    OR (club_id IS NOT NULL AND public.is_club_member(club_id, auth.uid()))
  );

DROP POLICY IF EXISTS "trips_select" ON trips;
CREATE POLICY "trips_select" ON trips FOR SELECT
  USING (
    is_public
    OR creator_id = auth.uid()
    OR EXISTS (SELECT 1 FROM trip_participants tp
               WHERE tp.trip_id = trips.id AND tp.user_id = auth.uid())
    OR (club_id IS NOT NULL AND public.is_club_member(club_id, auth.uid()))
  );

-- `clubs.events_public` fica no banco por ora, sem uso: some da interface
-- nesta entrega e a coluna é removida numa migration seguinte, depois de
-- confirmado que nada mais a lê. Derrubar coluna é irreversível.


-- ─────────────────────────────────────────────────────────────────────────────
-- 035: fecha RPCs que exigem sessão para o papel `anon`
--
-- Descoberto ao auditar a 034: o Supabase concede EXECUTE **direto** aos papéis
-- `anon` e `authenticated` em toda função nova do schema `public`, e
-- `REVOKE ... FROM PUBLIC` não mexe em concessão direta a um papel. Ou seja,
-- toda função nasce chamável por qualquer um com a chave anônima — que é
-- pública, vai dentro do app.
--
-- `nearby_riders` devolve nome, username, avatar e distância de quem está por
-- perto. Ela só não vazava para anônimo por ACIDENTE: o filtro
-- `p.id <> auth.uid()` vira NULL quando não há sessão, e NULL descarta todas as
-- linhas. Bastaria alguém trocar isso por um COALESCE para expor a localização
-- de todo mundo. Aqui a proteção passa a ser explícita.
--
-- Conferido que estas NÃO precisam de ajuste:
--   - funções de trigger (handle_new_user, update_*_count, etc.): só rodam como
--     trigger; chamá-las direto dá erro do próprio Postgres;
--   - invite_ride_participants: já valida `creator_id = auth.uid()` e estoura
--     sem sessão.
-- ─────────────────────────────────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.nearby_riders(double precision, double precision, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nearby_riders(double precision, double precision, integer)
  TO authenticated;


-- ─────────────────────────────────────────────────────────────────────────────
-- 036: chave de chat por CONTA, no lugar de chave por aparelho
--
-- Por quê: com a chave só no aparelho, limpar os dados do navegador ou trocar
-- de celular tornava todo o histórico ilegível ("🔒 Mensagem cifrada"), sem
-- nada que o usuário pudesse fazer. No teste real um aparelho gerou TRÊS
-- identidades em quatro minutos, e havia 23 chaves para 13 pessoas.
--
-- TROCA DE GARANTIA, EXPLÍCITA: a chave privada passa a ficar no servidor, o
-- que significa que quem tiver acesso ao banco consegue decifrar as mensagens.
-- Deixa de ser criptografia ponta a ponta e passa a ser "cifrado no banco":
-- um vazamento apenas da tabela `messages` continua inútil sem `user_chat_keys`,
-- mas o servidor não é mais cego. NÃO divulgar como "ponta a ponta".
--
-- As duas metades ficam em TABELAS SEPARADAS de propósito: a pública precisa
-- ser lida por quem vai enviar mensagem para a pessoa, a privada só pelo dono.
-- Juntas na mesma tabela, uma policy de leitura ou um `select('*')` distraído
-- vazaria a privada.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Pública: uma por usuário, legível por quem vai cifrar para ela ───────
-- A tabela já existia com (user_id, device_id). Volta a ser uma linha por
-- usuário. As chaves antigas não servem para nada: as privadas correspondentes
-- se perderam com os aparelhos.
DELETE FROM user_keys;
ALTER TABLE user_keys DROP CONSTRAINT IF EXISTS user_keys_pkey;
ALTER TABLE user_keys DROP COLUMN IF EXISTS device_id;
ALTER TABLE user_keys ADD PRIMARY KEY (user_id);

-- ── 2. Privada: só o dono ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_chat_keys (
  user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  private_key TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE user_chat_keys ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_chat_keys_select" ON user_chat_keys;
CREATE POLICY "user_chat_keys_select" ON user_chat_keys FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "user_chat_keys_insert" ON user_chat_keys;
CREATE POLICY "user_chat_keys_insert" ON user_chat_keys FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Sem policy de UPDATE nem DELETE: trocar a chave privada tornaria o histórico
-- ilegível, que é exatamente o problema que esta migration resolve.

-- ── 3. Mensagens antigas ───────────────────────────────────────────────────
-- Cifradas para aparelhos cujas chaves privadas não existem mais: são
-- irrecuperáveis por qualquer caminho e ficariam como 🔒 para sempre.
-- São 46 mensagens de teste, em 3 conversas. A migration 030 fez o mesmo pelo
-- mesmo motivo.
TRUNCATE TABLE messages;


-- ─────────────────────────────────────────────────────────────────────────────
-- 037: chave do chat cifrada no banco + índices em chaves estrangeiras
--
-- PARTE 1 — Chave privada cifrada em repouso
-- Depois da 036 a chave privada do chat passou a ficar no servidor (para o
-- histórico sobreviver a trocar de aparelho). Ela estava em texto puro, então
-- um BACKUP VAZADO ou uma consulta indevida à tabela entregava tudo.
--
-- Agora a coluna guarda `pgp_sym_encrypt(chave, embrulho)`. O "embrulho" é um
-- segredo guardado no Vault, que por sua vez é cifrado com a chave-mestra em
-- /etc/postgresql-custom/pgsodium_root.key — um arquivo de 64 bytes, modo 600,
-- que NÃO sai no pg_dump. Logo: um dump do banco, sozinho, é inútil.
--
-- O que isto NÃO resolve, para não haver ilusão: quem tem root na VPS lê o
-- arquivo e o banco; e quem tem a service_role continua passando por cima da
-- RLS. O ganho é contra compromisso PARCIAL (backup extraviado, SQL injection,
-- leitura acidental) — que é o incidente mais comum numa operação pequena.
--
-- ⚠️ NOVO PONTO ÚNICO DE FALHA: perder o pgsodium_root.key torna TODAS as
-- mensagens ilegíveis para sempre. Ele precisa entrar no backup com o mesmo
-- cuidado da keystore do Android.
--
-- A tabela deixa de ser lida direto: o app passa por duas funções, que é
-- também onde dá para auditar ou limitar no futuro.
--
-- PARTE 2 — Índices
-- Cinco chaves estrangeiras sem índice. Hoje não custa nada (tabelas pequenas),
-- mas APAGAR UM USUÁRIO obriga o Postgres a varrer cada uma delas para conferir
-- as referências — e a exclusão automática de contas aos 6 meses (034) fez
-- disso rotina.
-- ─────────────────────────────────────────────────────────────────────────────

-- Nota: as chamadas do pgcrypto vao qualificadas com `extensions.` porque as
-- funcoes fixam `search_path = public` (protecao contra sequestro de schema).
-- Alargar o search_path resolveria, mas abriria justamente a brecha que a
-- fixacao evita.

-- ══ PARTE 1: CHAVE CIFRADA EM REPOUSO ══════════════════════════════════════

-- Segredo que embrulha as chaves. Criado uma única vez; se já existir, mantém
-- (recriar tornaria ilegível tudo que foi cifrado com o anterior).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'chat_key_wrap') THEN
    PERFORM vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'chat_key_wrap',
      'Embrulha as chaves privadas do chat (tabela user_chat_keys)');
  END IF;
END $$;

-- Grava a chave privada CIFRADA e publica a pública. Uma função só para as
-- duas metades: separadas, um erro no meio deixaria a pessoa com chave pública
-- publicada e privada ausente — todos cifrariam para algo que ela não abre.
CREATE OR REPLACE FUNCTION public.chat_key_set(p_private TEXT, p_public TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); wrap TEXT;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'É preciso estar logado';
  END IF;
  -- Não deixa sobrescrever: trocar a chave tornaria o histórico ilegível.
  IF EXISTS (SELECT 1 FROM user_chat_keys WHERE user_id = uid) THEN
    RETURN;
  END IF;

  SELECT decrypted_secret INTO wrap
  FROM vault.decrypted_secrets WHERE name = 'chat_key_wrap';
  IF wrap IS NULL THEN
    RAISE EXCEPTION 'Segredo de embrulho ausente';
  END IF;

  INSERT INTO user_chat_keys (user_id, private_key)
  VALUES (uid, encode(extensions.pgp_sym_encrypt(p_private, wrap), 'base64'));

  INSERT INTO user_keys (user_id, public_key, updated_at)
  VALUES (uid, p_public, NOW())
  ON CONFLICT (user_id) DO UPDATE SET public_key = EXCLUDED.public_key,
                                      updated_at = NOW();
END; $$;

-- Devolve a chave privada decifrada, e SÓ a de quem chama.
CREATE OR REPLACE FUNCTION public.chat_key_get()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); wrap TEXT; guardada TEXT;
BEGIN
  IF uid IS NULL THEN RETURN NULL; END IF;

  SELECT private_key INTO guardada FROM user_chat_keys WHERE user_id = uid;
  IF guardada IS NULL THEN RETURN NULL; END IF;

  SELECT decrypted_secret INTO wrap
  FROM vault.decrypted_secrets WHERE name = 'chat_key_wrap';
  IF wrap IS NULL THEN RETURN NULL; END IF;

  RETURN extensions.pgp_sym_decrypt(decode(guardada, 'base64'), wrap);
END; $$;

-- Lembrete da 035: revogar de PUBLIC não basta — o Supabase concede EXECUTE
-- direto a anon e authenticated em toda função nova do schema public.
REVOKE ALL ON FUNCTION public.chat_key_set(TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.chat_key_get()           FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chat_key_set(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.chat_key_get()           TO authenticated;

-- A tabela sai do alcance da API: só as funções acima tocam nela. Sem isto,
-- um `select('*')` distraído no app devolveria a coluna cifrada e, pior, a
-- superfície continuaria existindo.
REVOKE ALL ON TABLE user_chat_keys FROM anon, authenticated;

-- As policies deixam de ser o que protege (não há mais acesso direto), mas
-- ficam como segunda barreira caso alguém conceda acesso de novo por engano.

-- ══ PARTE 2: ÍNDICES EM CHAVES ESTRANGEIRAS ════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_trips_creator          ON trips(creator_id);
CREATE INDEX IF NOT EXISTS idx_rides_creator          ON rides(creator_id);
CREATE INDEX IF NOT EXISTS idx_ride_locations_user    ON ride_locations(user_id);
CREATE INDEX IF NOT EXISTS idx_event_participants_user ON event_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_club_members_invited_by ON club_members(invited_by);


-- ─────────────────────────────────────────────────────────────────────────────
-- 038: convites de motoclube por link
--
-- Hoje só existe convite direto (club_members com status 'invited'), que exige
-- achar a pessoa no app. O dono/gerente precisa de um LINK para mandar no
-- WhatsApp, em três formatos:
--   permanent — vale para sempre, para colocar na bio do clube
--   single    — uma pessoa só; queima no primeiro uso
--   temporary — expira em 1 hora, para um encontro pontual
--
-- ── SEGURANÇA ───────────────────────────────────────────────────────────────
-- O token é a credencial: quem o tem, entra. Por isso:
--  - token com 16 bytes aleatórios (32 hex). Não é sequencial nem adivinhável;
--  - a tabela NÃO é acessível pela API (`REVOKE`): sem isso, qualquer pessoa
--    logada listaria os tokens de todos os clubes e entraria em qualquer um.
--    Tudo passa pelas funções abaixo;
--  - validade e uso são conferidos NO SERVIDOR. Checar no app seria teatro:
--    bastaria chamar o endpoint direto;
--  - o convite de uso único é queimado com UPDATE condicional
--    (`WHERE used_by IS NULL`), que é atômico. Duas pessoas tocando no mesmo
--    link ao mesmo tempo: uma entra, a outra recebe "já utilizado".
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS club_invites (
  token      TEXT PRIMARY KEY,
  club_id    UUID REFERENCES clubs(id)    ON DELETE CASCADE NOT NULL,
  created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  kind       TEXT NOT NULL CHECK (kind IN ('permanent','single','temporary')),
  expires_at TIMESTAMPTZ,                  -- só para 'temporary'
  used_by    UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- só para 'single'
  used_at    TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_club_invites_club ON club_invites(club_id);

ALTER TABLE club_invites ENABLE ROW LEVEL SECURITY;
-- Sem policy de propósito: o acesso é só pelas funções SECURITY DEFINER.
REVOKE ALL ON TABLE club_invites FROM anon, authenticated;

-- ── Criar ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.club_invite_create(
  p_club_id UUID, p_kind TEXT
) RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); t TEXT; exp TIMESTAMPTZ;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'É preciso estar logado'; END IF;
  IF NOT public.is_club_admin(p_club_id, uid) THEN
    RAISE EXCEPTION 'Só quem administra o motoclube pode criar convites';
  END IF;
  IF p_kind NOT IN ('permanent','single','temporary') THEN
    RAISE EXCEPTION 'Tipo de convite inválido';
  END IF;

  IF p_kind = 'temporary' THEN exp := NOW() + INTERVAL '1 hour'; END IF;
  t := encode(extensions.gen_random_bytes(16), 'hex');

  INSERT INTO club_invites (token, club_id, created_by, kind, expires_at)
  VALUES (t, p_club_id, uid, p_kind, exp);
  RETURN t;
END; $$;

-- ── Prévia (tela de quem recebeu o link) ────────────────────
-- Aberta a quem não está logado de propósito: a pessoa precisa ver de qual
-- clube é o convite ANTES de criar conta. Devolve só o que já é público no
-- perfil do clube — nunca a lista de membros nem quem criou o convite.
CREATE OR REPLACE FUNCTION public.club_invite_preview(p_token TEXT)
RETURNS TABLE (club_id UUID, name TEXT, avatar_url TEXT, city TEXT,
               state_uf TEXT, members INT, status TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv club_invites%ROWTYPE; st TEXT;
BEGIN
  SELECT * INTO inv FROM club_invites WHERE token = p_token;
  IF inv.token IS NULL THEN
    RETURN QUERY SELECT NULL::UUID, NULL::TEXT, NULL::TEXT, NULL::TEXT,
                        NULL::TEXT, 0, 'invalido';
    RETURN;
  END IF;

  st := CASE
    WHEN inv.revoked_at IS NOT NULL                       THEN 'revogado'
    WHEN inv.expires_at IS NOT NULL
         AND inv.expires_at < NOW()                       THEN 'expirado'
    WHEN inv.kind = 'single' AND inv.used_by IS NOT NULL  THEN 'usado'
    ELSE 'valido'
  END;

  RETURN QUERY
  SELECT c.id, c.name, c.avatar_url, c.city, c.state_uf,
         (SELECT count(*)::INT FROM club_members m
           WHERE m.club_id = c.id AND m.status = 'active'),
         st
  FROM clubs c WHERE c.id = inv.club_id;
END; $$;

-- ── Aceitar ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.club_invite_accept(p_token TEXT)
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE uid UUID := auth.uid(); inv club_invites%ROWTYPE; queimado INT;
BEGIN
  IF uid IS NULL THEN RETURN 'sem_sessao'; END IF;

  SELECT * INTO inv FROM club_invites WHERE token = p_token;
  IF inv.token IS NULL     THEN RETURN 'invalido'; END IF;
  IF inv.revoked_at IS NOT NULL THEN RETURN 'revogado'; END IF;
  IF inv.expires_at IS NOT NULL AND inv.expires_at < NOW() THEN
    RETURN 'expirado';
  END IF;

  -- Já é membro: não consome o convite de uso único.
  IF EXISTS (SELECT 1 FROM club_members
              WHERE club_id = inv.club_id AND user_id = uid
                AND status = 'active') THEN
    RETURN 'ja_membro';
  END IF;

  IF inv.kind = 'single' THEN
    -- Atômico: quem ganhar a corrida leva. O WHERE garante que só uma
    -- transação consegue marcar como usado.
    UPDATE club_invites SET used_by = uid, used_at = NOW()
     WHERE token = p_token AND used_by IS NULL;
    GET DIAGNOSTICS queimado = ROW_COUNT;
    IF queimado = 0 THEN RETURN 'usado'; END IF;
  END IF;

  INSERT INTO club_members (club_id, user_id, role, status, invited_by)
  VALUES (inv.club_id, uid, 'member', 'active', inv.created_by)
  ON CONFLICT (club_id, user_id)
    DO UPDATE SET status = 'active';

  RETURN 'entrou';
END; $$;

-- ── Listar e revogar (painel do admin) ──────────────────────
CREATE OR REPLACE FUNCTION public.club_invites_list(p_club_id UUID)
RETURNS TABLE (token TEXT, kind TEXT, expires_at TIMESTAMPTZ,
               used_at TIMESTAMPTZ, created_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_club_admin(p_club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Só quem administra o motoclube pode ver os convites';
  END IF;
  RETURN QUERY
  SELECT i.token, i.kind, i.expires_at, i.used_at, i.created_at
  FROM club_invites i
  WHERE i.club_id = p_club_id AND i.revoked_at IS NULL
  ORDER BY i.created_at DESC;
END; $$;

CREATE OR REPLACE FUNCTION public.club_invite_revoke(p_token TEXT)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE inv club_invites%ROWTYPE;
BEGIN
  SELECT * INTO inv FROM club_invites WHERE token = p_token;
  IF inv.token IS NULL THEN RETURN; END IF;
  IF NOT public.is_club_admin(inv.club_id, auth.uid()) THEN
    RAISE EXCEPTION 'Só quem administra o motoclube pode revogar convites';
  END IF;
  UPDATE club_invites SET revoked_at = NOW() WHERE token = p_token;
END; $$;

-- ── Permissões ──────────────────────────────────────────────
-- Lembrete das migrations 035 e 037: REVOKE de PUBLIC não basta, porque o
-- Supabase concede EXECUTE direto a anon e authenticated em toda função nova.
REVOKE ALL ON FUNCTION public.club_invite_create(UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_invite_accept(TEXT)       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_invites_list(UUID)        FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.club_invite_revoke(TEXT)       FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.club_invite_create(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_invite_accept(TEXT)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_invites_list(UUID)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.club_invite_revoke(TEXT)       TO authenticated;

-- A prévia continua aberta ao anônimo: é o que permite a tela "o Motoclube X
-- te convidou" aparecer antes de a pessoa criar conta.
GRANT EXECUTE ON FUNCTION public.club_invite_preview(TEXT) TO anon, authenticated;
