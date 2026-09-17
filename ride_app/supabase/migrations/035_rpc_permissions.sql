-- ─────────────────────────────────────────────────────────────────────────────
-- 035: fecha RPCs que exigem sessão para o papel `anon`
--
-- Descoberto ao auditar a 034: o Supabase concede EXECUTE **direto** aos papéis
-- `anon` e `authenticated` em toda função nova do schema `public`, e
-- `REVOKE ... FROM PUBLIC` não mexe em concessão direta a um papel. Ou seja,
-- toda função nasce chamável por qualquer um com a chave anônima — que é
-- pública, vai dentro do app.
--
-- `nearby_riders` devolve nome, username, avatar e distância de quem está por
-- perto. Ela só não vazava para anônimo por ACIDENTE: o filtro
-- `p.id <> auth.uid()` vira NULL quando não há sessão, e NULL descarta todas as
-- linhas. Bastaria alguém trocar isso por um COALESCE para expor a localização
-- de todo mundo. Aqui a proteção passa a ser explícita.
--
-- Conferido que estas NÃO precisam de ajuste:
--   - funções de trigger (handle_new_user, update_*_count, etc.): só rodam como
--     trigger; chamá-las direto dá erro do próprio Postgres;
--   - invite_ride_participants: já valida `creator_id = auth.uid()` e estoura
--     sem sessão.
-- ─────────────────────────────────────────────────────────────────────────────

REVOKE ALL ON FUNCTION public.nearby_riders(double precision, double precision, integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nearby_riders(double precision, double precision, integer)
  TO authenticated;
