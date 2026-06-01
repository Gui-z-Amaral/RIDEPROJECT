-- ─────────────────────────────────────────────────────────────────────────────
-- Realtime publications
--
-- O Supabase usa a publication "supabase_realtime" para entregar mudanças
-- via WebSocket. Em self-hosted essa publication já existe (criada pelo
-- entrypoint do container realtime), mas as tabelas precisam ser
-- explicitamente adicionadas.
--
-- O app inscreve nas seguintes tabelas:
--   - messages           (chat)
--   - notifications      (sininho)
--   - ride_participants  (status na waiting screen)
--   - ride_locations     (mapa em sessão ativa)
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

-- Cria a publication se ainda não existir (failsafe; normalmente já existe).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END
$$;

-- Adiciona cada tabela à publication (idempotente).
-- ALTER PUBLICATION ... ADD TABLE não tem IF NOT EXISTS, então tratamos
-- a exceção "relation already member" individualmente.
DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY[
        'messages',
        'notifications',
        'ride_participants',
        'trip_participants',
        'ride_locations'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables
    LOOP
        BEGIN
            EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', tbl);
        EXCEPTION
            WHEN duplicate_object THEN
                -- tabela já está na publication, segue
                NULL;
            WHEN undefined_table THEN
                -- tabela não existe ainda (aplique a migração que cria antes)
                RAISE NOTICE 'Tabela % não encontrada — pulei', tbl;
        END;
    END LOOP;
END
$$;
