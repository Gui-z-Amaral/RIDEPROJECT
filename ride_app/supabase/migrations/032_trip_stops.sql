-- 032 — Paradas da viagem
--
-- O TripModel já tinha `stops` e o buildGoogleMapsUrl() já as incluía como
-- waypoints, mas não havia onde guardá-las: a tela de criação só mantinha uma
-- lista de nomes em memória (sem coordenadas), perdida ao salvar.
--
-- Policies espelham trip_schedule_items (mesma relação filha de trips):
-- leitura livre; escrita do criador da viagem ou admin do clube.

CREATE TABLE IF NOT EXISTS trip_stops (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  trip_id     UUID REFERENCES trips(id) ON DELETE CASCADE NOT NULL,
  position    INT NOT NULL DEFAULT 0,        -- ordem da parada na rota
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
