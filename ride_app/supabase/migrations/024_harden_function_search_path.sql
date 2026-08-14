-- ─────────────────────────────────────────────────────────────────────────────
-- Hardening: fixa o search_path das funções SECURITY DEFINER/trigger.
--
-- Resolve o aviso do linter "function_search_path_mutable" (risco de injeção de
-- search_path em funções SECURITY DEFINER). Não altera comportamento: todas as
-- funções referenciam apenas objetos do schema public.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER FUNCTION public.update_trips_count(uuid)        SET search_path = public;
ALTER FUNCTION public.update_friends_count(uuid)      SET search_path = public;
ALTER FUNCTION public.sync_event_interests_count()    SET search_path = public;
ALTER FUNCTION public.update_rides_count(uuid)        SET search_path = public;
ALTER FUNCTION public.is_club_member(uuid, uuid)      SET search_path = public;
ALTER FUNCTION public.is_club_admin(uuid, uuid)       SET search_path = public;
ALTER FUNCTION public.handle_new_club()               SET search_path = public;
