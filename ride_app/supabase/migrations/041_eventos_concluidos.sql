-- 041 — Evento concluído: histórico no mural do motoclube
--
-- Eventos nunca tiveram estado. A única data era `starts_at`, e o mural do
-- clube juntava tudo numa lista ordenada por data — encontro do ano passado
-- no meio dos que ainda vão acontecer.
--
-- `completed_at` em vez de uma coluna `status`: concluir é um fato com data, e
-- NULL já diz "em aberto" sem precisar de default nem de CHECK. Viagens ficam
-- como estão: elas já têm `status = 'completed'` desde a 001.
--
-- Sem policy nova: `events_update` (migration 023) já restringe a alteração ao
-- criador do evento ou ao gerente do motoclube, que é exatamente quem pode
-- concluir. Coluna nullable, sem entrada de usuário — nada a validar.
ALTER TABLE events ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- O mural pede os eventos de um clube separando em aberto de concluído.
CREATE INDEX IF NOT EXISTS idx_events_club_completed
  ON events(club_id, completed_at);
