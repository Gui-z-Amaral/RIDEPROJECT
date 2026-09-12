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
