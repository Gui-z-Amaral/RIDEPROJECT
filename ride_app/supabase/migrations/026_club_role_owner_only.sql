-- ─────────────────────────────────────────────────────────────────────────────
-- Restringe a mudança de papel (promover/rebaixar gerente) ao DONO do clube.
--
-- Antes, a policy de UPDATE em club_members permitia qualquer admin (gerente)
-- alterar papéis. Agora só o dono pode. Gerentes continuam podendo EXPULSAR
-- (policy de DELETE, inalterada) e o próprio usuário continua podendo aceitar
-- convite (atualizar a própria linha).
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "club_members_update" ON club_members;
CREATE POLICY "club_members_update" ON club_members FOR UPDATE
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM clubs c
            WHERE c.id = club_id AND c.owner_id = auth.uid()
        )
    );
