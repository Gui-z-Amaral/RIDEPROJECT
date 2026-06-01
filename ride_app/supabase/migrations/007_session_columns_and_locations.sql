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
