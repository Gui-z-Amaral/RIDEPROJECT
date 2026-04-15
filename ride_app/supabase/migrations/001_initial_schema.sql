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
