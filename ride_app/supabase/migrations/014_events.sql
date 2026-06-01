-- ─────────────────────────────────────────────────────────────────────────────
-- Eventos (criados por perfis empresa)
--
-- Um perfil empresa cria eventos com local (Google Maps), data e programação.
-- Eventos aparecem na home filtrados pela UF atual do usuário e na busca.
-- Qualquer usuário pode marcar "tenho interesse"; a contagem é mantida em
-- events.interests_count por trigger.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. events ───────────────────────────────────────────────────────────────
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
    state_uf        TEXT,            -- UF (ex: 'SC') usada pra filtrar na home
    city            TEXT,
    starts_at       TIMESTAMPTZ NOT NULL,
    ends_at         TIMESTAMPTZ,
    interests_count INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_state_starts ON events(state_uf, starts_at);
CREATE INDEX IF NOT EXISTS idx_events_creator       ON events(creator_id);

-- ── 2. event_schedule_items (programação) ───────────────────────────────────
CREATE TABLE IF NOT EXISTS event_schedule_items (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id    UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    position    INT NOT NULL DEFAULT 0,   -- ordem de exibição
    time_label  TEXT,                     -- ex: '14:00' (texto livre)
    title       TEXT NOT NULL,
    description TEXT
);

CREATE INDEX IF NOT EXISTS idx_event_schedule_event ON event_schedule_items(event_id);

-- ── 3. event_interests ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS event_interests (
    event_id   UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_interests_user ON event_interests(user_id);

-- ── 4. Trigger: mantém events.interests_count em sincronia ──────────────────
CREATE OR REPLACE FUNCTION public.sync_event_interests_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
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

DROP TRIGGER IF EXISTS trg_event_interests_count ON event_interests;
CREATE TRIGGER trg_event_interests_count
    AFTER INSERT OR DELETE ON event_interests
    FOR EACH ROW EXECUTE FUNCTION public.sync_event_interests_count();

-- ── 5. Row Level Security ───────────────────────────────────────────────────
ALTER TABLE events               ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_schedule_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_interests      ENABLE ROW LEVEL SECURITY;

-- events: todos leem; só conta empresa cria; só o criador edita/apaga.
DROP POLICY IF EXISTS "events_select" ON events;
CREATE POLICY "events_select" ON events FOR SELECT USING (true);

DROP POLICY IF EXISTS "events_insert" ON events;
CREATE POLICY "events_insert" ON events FOR INSERT
    WITH CHECK (
        auth.uid() = creator_id
        AND EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND account_type = 'business'
        )
    );

DROP POLICY IF EXISTS "events_update" ON events;
CREATE POLICY "events_update" ON events FOR UPDATE
    USING (auth.uid() = creator_id);

DROP POLICY IF EXISTS "events_delete" ON events;
CREATE POLICY "events_delete" ON events FOR DELETE
    USING (auth.uid() = creator_id);

-- event_schedule_items: todos leem; só o dono do evento gerencia.
DROP POLICY IF EXISTS "event_schedule_select" ON event_schedule_items;
CREATE POLICY "event_schedule_select" ON event_schedule_items FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "event_schedule_write" ON event_schedule_items;
CREATE POLICY "event_schedule_write" ON event_schedule_items FOR ALL
    USING (
        EXISTS (SELECT 1 FROM events e
                WHERE e.id = event_id AND e.creator_id = auth.uid())
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM events e
                WHERE e.id = event_id AND e.creator_id = auth.uid())
    );

-- event_interests: todos leem (pra contar); cada um gerencia só o próprio.
DROP POLICY IF EXISTS "event_interests_select" ON event_interests;
CREATE POLICY "event_interests_select" ON event_interests FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "event_interests_insert" ON event_interests;
CREATE POLICY "event_interests_insert" ON event_interests FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "event_interests_delete" ON event_interests;
CREATE POLICY "event_interests_delete" ON event_interests FOR DELETE
    USING (auth.uid() = user_id);

-- ── 6. Realtime (contador de interesse / novos eventos) ─────────────────────
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.events;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.event_interests;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END
$$;
