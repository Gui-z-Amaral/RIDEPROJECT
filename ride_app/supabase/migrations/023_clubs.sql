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
