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
