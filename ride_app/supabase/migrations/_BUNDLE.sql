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
