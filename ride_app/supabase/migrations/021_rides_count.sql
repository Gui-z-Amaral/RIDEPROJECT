-- ─────────────────────────────────────────────────────────────────────────────
-- Contagem de rolês criados/participados (mesmo padrão de trips_count).
-- ─────────────────────────────────────────────────────────────────────────────

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

-- Backfill: preenche a contagem pra quem já tem rolês
SELECT public.update_rides_count(id) FROM profiles;
