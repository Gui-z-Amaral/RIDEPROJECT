-- ─────────────────────────────────────────────────────────────────────────────
-- Corrige o contador de interesse dos eventos.
--
-- O trigger sync_event_interests_count fazia UPDATE em events, mas rodava com
-- os privilégios de quem marcava interesse. Como a policy events_update só
-- permite o criador/admin editar o evento, o UPDATE do contador era bloqueado
-- pelo RLS quando OUTRA pessoa marcava interesse → interests_count nunca subia.
--
-- Solução: recriar a função como SECURITY DEFINER (roda como dono, ignora RLS
-- só para manter o contador). Também faz backfill dos contadores defasados.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.sync_event_interests_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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

-- Backfill: recalcula os contadores que ficaram defasados.
UPDATE events e SET interests_count = (
    SELECT COUNT(*) FROM event_interests i WHERE i.event_id = e.id
);
