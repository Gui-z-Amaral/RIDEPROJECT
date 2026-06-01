-- ─────────────────────────────────────────────────────────────────────────────
-- Fotos de sessão (viagem OU rolê)
--
-- trip_photos.trip_id e featured_photos.trip_id tinham FK obrigatória para
-- trips(id). Ao finalizar um ROLÊ, o app grava com trip_id = id do rolê (que
-- não está em `trips`), e o Postgres rejeitava com
--   "Key (trip_id)=(...) is not present in table 'trips'"
-- — o erro "not exist" que aparecia ao tentar salvar a foto.
--
-- Como uma "sessão" pode ser viagem ou rolê, removemos a FK rígida. A coluna
-- continua guardando o id da sessão (trip ou ride). Perde-se o ON DELETE
-- CASCADE automático, mas o app já remove as fotos junto ao deletar.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE trip_photos
    DROP CONSTRAINT IF EXISTS trip_photos_trip_id_fkey;

ALTER TABLE featured_photos
    DROP CONSTRAINT IF EXISTS featured_photos_trip_id_fkey;
