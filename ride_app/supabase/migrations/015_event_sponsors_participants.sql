-- ─────────────────────────────────────────────────────────────────────────────
-- Patrocinadores e participantes extras do evento
--
--   event_sponsors      → marcas/apoiadores (texto livre + logo opcional)
--   event_participants  → usuários do app convidados como participantes extras
--
-- Quem gerencia ambos é o criador do evento. Notificações de alteração para
-- quem marcou interesse são inseridas pelo cliente (RLS de notifications já
-- permite authenticated inserir pra outros).
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── event_sponsors ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS event_sponsors (
    id        UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    event_id  UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    position  INT NOT NULL DEFAULT 0,
    name      TEXT NOT NULL,
    logo_url  TEXT
);
CREATE INDEX IF NOT EXISTS idx_event_sponsors_event ON event_sponsors(event_id);

-- ── event_participants ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS event_participants (
    event_id  UUID REFERENCES events(id) ON DELETE CASCADE NOT NULL,
    user_id   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_event_participants_event ON event_participants(event_id);

-- ── RLS ─────────────────────────────────────────────────────────────────────
ALTER TABLE event_sponsors      ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants  ENABLE ROW LEVEL SECURITY;

-- Todos leem; só o dono do evento gerencia.
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
