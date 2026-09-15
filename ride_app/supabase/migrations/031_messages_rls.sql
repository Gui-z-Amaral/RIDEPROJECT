-- 031 — RLS das mensagens: privacidade e marcar como lida
--
-- Problema 1 (segurança): a policy de SELECT da 001 era
--   USING (auth.uid() IS NOT NULL)
-- ou seja, QUALQUER usuário autenticado lia TODAS as mensagens do banco. O
-- conteúdo é cifrado (E2EE), mas os metadados vazavam: quem conversa com quem,
-- quando e com que frequência.
--
-- Problema 2 (funcional): não havia policy de UPDATE, então marcar uma mensagem
-- como lida sempre era recusado — o contador de não lidas não tinha como zerar.
--
-- O chat_id é canônico: os dois UUIDs ordenados e unidos por "_"
-- (ver SupabaseSocialService.canonicalChatId), então dá para checar
-- participação com split_part.

-- 1) SELECT só para os participantes da conversa.
DROP POLICY IF EXISTS "messages_select" ON messages;
CREATE POLICY "messages_select" ON messages FOR SELECT USING (
  auth.uid()::text = split_part(chat_id, '_', 1)
  OR auth.uid()::text = split_part(chat_id, '_', 2)
);

-- 2) INSERT: só como você mesmo E só em conversa da qual participa.
DROP POLICY IF EXISTS "messages_insert" ON messages;
CREATE POLICY "messages_insert" ON messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id AND (
    auth.uid()::text = split_part(chat_id, '_', 1)
    OR auth.uid()::text = split_part(chat_id, '_', 2)
  )
);

-- 3) UPDATE: o destinatário marca como lida (o remetente não mexe).
DROP POLICY IF EXISTS "messages_update_read" ON messages;
CREATE POLICY "messages_update_read" ON messages FOR UPDATE
  USING (
    auth.uid() <> sender_id AND (
      auth.uid()::text = split_part(chat_id, '_', 1)
      OR auth.uid()::text = split_part(chat_id, '_', 2)
    )
  )
  WITH CHECK (
    auth.uid() <> sender_id AND (
      auth.uid()::text = split_part(chat_id, '_', 1)
      OR auth.uid()::text = split_part(chat_id, '_', 2)
    )
  );

CREATE INDEX IF NOT EXISTS idx_messages_unread
  ON messages(chat_id, sender_id) WHERE is_read = false;
