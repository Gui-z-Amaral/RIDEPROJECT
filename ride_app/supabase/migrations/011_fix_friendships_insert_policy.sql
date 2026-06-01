-- ─────────────────────────────────────────────────────────────────────────────
-- Corrige a política de INSERT de friendships
--
-- Ao aceitar um convite, acceptFriendRequest insere as DUAS linhas da amizade
-- bidirecional num único upsert:
--   { user_id: fromUserId, friend_id: euMesmo }   ← LINHA A
--   { user_id: euMesmo,    friend_id: fromUserId } ← LINHA B
--
-- A política antiga (WITH CHECK auth.uid() = user_id) só aprova a LINHA B.
-- Como é um INSERT em batch, a LINHA A reprovada derruba o statement inteiro
-- (erro 42501) e NENHUMA das duas entra → a lista de amigos nunca atualiza.
--
-- Solução: permitir inserir uma linha de amizade onde o usuário autenticado é
-- qualquer um dos dois lados. Não abre superfície de ataque relevante — quem
-- aceita já podia inserir { eu, X } pela política antiga; isto só libera o
-- espelho { X, eu }, que representa a mesma amizade.
--
-- Aplique no SQL Editor do Supabase self-hosted.
-- ─────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "friendships_insert" ON friendships;
CREATE POLICY "friendships_insert" ON friendships FOR INSERT
    WITH CHECK (auth.uid() = user_id OR auth.uid() = friend_id);
