-- ── NOTIFICATIONS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type       TEXT NOT NULL DEFAULT 'general',
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  data       JSONB DEFAULT '{}',
  is_read    BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user   ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Cada usuário lê apenas as próprias notificações
CREATE POLICY "notif_select" ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Qualquer usuário autenticado pode criar notificação para outro (convite)
CREATE POLICY "notif_insert" ON notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Usuário pode marcar as suas como lidas
CREATE POLICY "notif_update" ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Usuário pode deletar as suas
CREATE POLICY "notif_delete" ON notifications FOR DELETE
  USING (auth.uid() = user_id);
