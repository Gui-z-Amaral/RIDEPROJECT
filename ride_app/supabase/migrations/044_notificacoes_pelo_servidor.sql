-- 044 — Notificação passa a ser criada pelo SERVIDOR
--
-- A policy `notif_insert` era `WITH CHECK (auth.uid() IS NOT NULL)`, e o
-- `rideapp-push-worker` manda para o celular toda linha nova desta tabela. Na
-- prática, qualquer conta enviava push com qualquer texto para qualquer
-- pessoa: golpe ("sua conta será bloqueada, toque aqui"), xingamento, ou um
-- `data` montado para o toque abrir qualquer tela do app.
--
-- Agora quem escreve em `notifications` é só o banco, a partir de um fato que
-- aconteceu de verdade (um convite, uma mensagem, um pedido de amizade), com
-- o texto montado a partir de dado real. O app não grava mais nada aqui.
--
-- Os textos e as chaves de `data` são exatamente os que o app gravava, para o
-- roteador de toque (`notification_router.dart`) continuar igual.
--
-- `auth.uid()` continua valendo dentro de trigger e de SECURITY DEFINER (vem
-- do JWT da requisição), e é o que separa "alguém me convidou" de "eu mesmo
-- me inscrevi": só notifica quando quem fez a ação é OUTRA pessoa.

-- ── Helper: nome de exibição ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.nome_de(p_uid UUID)
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(NULLIF(trim(name), ''), 'Alguém') FROM profiles WHERE id = p_uid;
$$;
REVOKE ALL ON FUNCTION public.nome_de(UUID) FROM PUBLIC, anon, authenticated;

-- ── Convite de viagem ───────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notifica_convite_viagem()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE t RECORD;
BEGIN
  IF NEW.status <> 'waiting' OR auth.uid() IS NULL OR NEW.user_id = auth.uid() THEN
    RETURN NEW;
  END IF;
  SELECT title, creator_id, origin_address, destination_address, destination_label
    INTO t FROM trips WHERE id = NEW.trip_id;
  IF NOT FOUND OR NEW.user_id = t.creator_id THEN RETURN NEW; END IF;

  INSERT INTO notifications (user_id, type, title, body, data) VALUES (
    NEW.user_id,
    'trip_invite',
    public.nome_de(auth.uid()) || ' te convidou para uma viagem',
    t.title || ' · ' || COALESCE(t.destination_address, t.destination_label, 'Destino'),
    jsonb_build_object(
      'tripId', NEW.trip_id,
      'tripTitle', t.title,
      'originAddress', COALESCE(t.origin_address, ''),
      'destinationAddress', COALESCE(t.destination_address, ''))
  );
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_notifica_convite_viagem ON trip_participants;
CREATE TRIGGER trg_notifica_convite_viagem AFTER INSERT ON trip_participants
  FOR EACH ROW EXECUTE FUNCTION public.notifica_convite_viagem();

-- ── Convite de rolê ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notifica_convite_role()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r RECORD;
BEGIN
  IF NEW.status <> 'waiting' OR auth.uid() IS NULL OR NEW.user_id = auth.uid() THEN
    RETURN NEW;
  END IF;
  SELECT title, creator_id, meeting_address, meeting_lat, meeting_lng
    INTO r FROM rides WHERE id = NEW.ride_id;
  IF NOT FOUND OR NEW.user_id = r.creator_id THEN RETURN NEW; END IF;

  INSERT INTO notifications (user_id, type, title, body, data) VALUES (
    NEW.user_id,
    'ride_invite',
    'Convite para rolê',
    public.nome_de(auth.uid()) || ' te convidou para um rolê em "' || r.title || '"',
    jsonb_build_object(
      'rideId', NEW.ride_id,
      'place', r.title,
      'address', r.meeting_address,
      'lat', r.meeting_lat,
      'lng', r.meeting_lng)
  );
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_notifica_convite_role ON ride_participants;
CREATE TRIGGER trg_notifica_convite_role AFTER INSERT ON ride_participants
  FOR EACH ROW EXECUTE FUNCTION public.notifica_convite_role();

-- ── Convite de motoclube ────────────────────────────────────────────────────
-- Entrar por link (migration 038) grava `active` direto: não gera aviso.
CREATE OR REPLACE FUNCTION public.notifica_convite_clube()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE nome TEXT;
BEGIN
  IF NEW.status <> 'invited' OR auth.uid() IS NULL OR NEW.user_id = auth.uid() THEN
    RETURN NEW;
  END IF;
  SELECT name INTO nome FROM clubs WHERE id = NEW.club_id;
  IF NOT FOUND THEN RETURN NEW; END IF;

  INSERT INTO notifications (user_id, type, title, body, data) VALUES (
    NEW.user_id,
    'club_invite',
    'Convite de motoclube',
    'Você foi convidado para o motoclube "' || nome || '".',
    jsonb_build_object('clubId', NEW.club_id)
  );
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_notifica_convite_clube ON club_members;
CREATE TRIGGER trg_notifica_convite_clube AFTER INSERT ON club_members
  FOR EACH ROW EXECUTE FUNCTION public.notifica_convite_clube();

-- ── Pedido de amizade ───────────────────────────────────────────────────────
-- O app faz upsert. Só avisa quando o pedido PASSA a ficar pendente: repetir o
-- pedido que já está pendente não gera um push novo a cada toque.
CREATE OR REPLACE FUNCTION public.notifica_pedido_amizade()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE remetente TEXT;
BEGIN
  IF NEW.status <> 'pending' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.status = 'pending' THEN RETURN NEW; END IF;
  remetente := public.nome_de(NEW.from_user_id);

  INSERT INTO notifications (user_id, type, title, body, data) VALUES (
    NEW.to_user_id,
    'friend_request',
    'Novo pedido de amizade',
    remetente || ' quer se conectar com você',
    jsonb_build_object(
      'requestId', NEW.id,
      'fromUserId', NEW.from_user_id,
      'fromName', remetente)
  );
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_notifica_pedido_amizade ON friend_requests;
CREATE TRIGGER trg_notifica_pedido_amizade
  AFTER INSERT OR UPDATE OF status ON friend_requests
  FOR EACH ROW EXECUTE FUNCTION public.notifica_pedido_amizade();

-- ── Mensagem ────────────────────────────────────────────────────────────────
-- Sem o texto: a mensagem é cifrada, e o aviso é genérico de propósito.
-- O destinatário é a outra metade do chat_id ("<uidA>_<uidB>").
CREATE OR REPLACE FUNCTION public.notifica_mensagem()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE a TEXT := split_part(NEW.chat_id, '_', 1);
        b TEXT := split_part(NEW.chat_id, '_', 2);
        dest UUID;
        remetente TEXT;
BEGIN
  dest := CASE WHEN a = NEW.sender_id::text THEN b ELSE a END::uuid;
  IF dest IS NULL OR dest = NEW.sender_id THEN RETURN NEW; END IF;
  remetente := public.nome_de(NEW.sender_id);

  INSERT INTO notifications (user_id, type, title, body, data) VALUES (
    dest,
    'message',
    remetente,
    CASE WHEN NEW.image_url IS NOT NULL THEN '📷 Imagem' ELSE '📩 Nova mensagem' END,
    jsonb_build_object('fromUserId', NEW.sender_id, 'fromName', remetente)
  );
  RETURN NEW;
EXCEPTION WHEN invalid_text_representation THEN
  -- chat_id fora do formato: a mensagem entra, só não gera aviso.
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_notifica_mensagem ON messages;
CREATE TRIGGER trg_notifica_mensagem AFTER INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION public.notifica_mensagem();

-- ── Evento atualizado ───────────────────────────────────────────────────────
-- Aqui não dá para ser trigger: a tela de edição tem a escolha "avisar quem
-- tem interesse". Vira uma função que confere se quem chama pode editar o
-- evento (mesma regra da `events_update`) e monta o texto a partir do banco.
CREATE OR REPLACE FUNCTION public.notificar_interessados_evento(p_event UUID)
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE e RECORD; n INT;
BEGIN
  SELECT id, title, creator_id, club_id INTO e FROM events WHERE id = p_event;
  IF NOT FOUND THEN RETURN 0; END IF;
  IF NOT (e.creator_id = auth.uid()
          OR (e.club_id IS NOT NULL AND public.is_club_admin(e.club_id, auth.uid()))) THEN
    RAISE EXCEPTION 'Sem permissão para avisar sobre este evento'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  INSERT INTO notifications (user_id, type, title, body, data)
  SELECT ei.user_id, 'event_update', 'Evento atualizado',
         'O evento "' || e.title || '" que você tem interesse foi atualizado.',
         jsonb_build_object('eventId', e.id)
    FROM event_interests ei
   WHERE ei.event_id = e.id AND ei.user_id <> auth.uid();
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END; $$;
REVOKE ALL ON FUNCTION public.notificar_interessados_evento(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.notificar_interessados_evento(UUID) TO authenticated;

-- ── Fecha a porta ───────────────────────────────────────────────────────────
-- Sem policy de INSERT, o app não grava mais notificação. As funções acima são
-- SECURITY DEFINER e continuam gravando.
DROP POLICY IF EXISTS "notif_insert" ON notifications;
