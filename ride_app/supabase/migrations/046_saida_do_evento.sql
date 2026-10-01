-- 046 — Saída do evento: ponto de encontro e horário como campos próprios
--
-- Um usuário organizou o rolê até o MR. FOX e escreveu na DESCRIÇÃO:
--   * Saída: 13:30h
--   * Ponto de encontro: Posto Simon Passo de Torres (BR 101)
-- Não foi preguiça: o app não tinha onde guardar isso. O evento tem um local
-- só (o destino), e o item do cronograma tem horário e título, mas não lugar.
--
-- Texto solto na descrição não aparece no mapa, não permite lembrete de saída
-- e, quando muda, só gera um "evento atualizado" genérico — justamente o
-- "sempre tem alguém que não foi avisado" que o app promete resolver.
--
-- Só colunas novas e opcionais: nenhum evento existente muda. A tela só
-- mostra estes campos em evento de motoclube (empresa não tem "saída").

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS departure_at    TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS meeting_label   TEXT,
  ADD COLUMN IF NOT EXISTS meeting_address TEXT,
  ADD COLUMN IF NOT EXISTS meeting_lat     DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS meeting_lng     DOUBLE PRECISION;

-- O nome do ponto de encontro segue a mesma regra do nome do local (045).
CREATE OR REPLACE FUNCTION public.valida_texto_events()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN RETURN NEW; END IF;
  IF TG_OP = 'INSERT' OR NEW.title IS DISTINCT FROM OLD.title THEN
    NEW.title := btrim(public.limpa_invisiveis(NEW.title));
    PERFORM public.exige_texto('evento', NEW.title);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.description IS DISTINCT FROM OLD.description THEN
    PERFORM public.exige_texto('evento_desc', NEW.description);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.location_label IS DISTINCT FROM OLD.location_label THEN
    PERFORM public.exige_texto('local', NEW.location_label);
  END IF;
  IF TG_OP = 'INSERT' OR NEW.meeting_label IS DISTINCT FROM OLD.meeting_label THEN
    PERFORM public.exige_texto('local', NEW.meeting_label);
  END IF;
  RETURN NEW;
END; $$;

-- ── "A saída mudou" ─────────────────────────────────────────────────────────
-- Aviso específico, para quem marcou interesse ou respondeu Vou/Talvez.
-- Sem o horário no texto de propósito: o banco está em UTC e o push não sabe o
-- fuso de quem recebe (quem está no Acre veria a hora errada). O toque abre o
-- evento, que mostra o horário no fuso do aparelho.
CREATE OR REPLACE FUNCTION public.notifica_saida_alterada()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  titulo TEXT;
  corpo TEXT;
BEGIN
  IF NEW.departure_at IS NOT DISTINCT FROM OLD.departure_at
     AND NEW.meeting_label IS NOT DISTINCT FROM OLD.meeting_label
     AND NEW.meeting_address IS NOT DISTINCT FROM OLD.meeting_address THEN
    RETURN NEW;
  END IF;
  -- Tirar a saída do evento não é notícia que valha um push.
  IF NEW.departure_at IS NULL AND NEW.meeting_label IS NULL
     AND NEW.meeting_address IS NULL THEN
    RETURN NEW;
  END IF;

  titulo := CASE
    WHEN OLD.departure_at IS NULL AND OLD.meeting_label IS NULL
         AND OLD.meeting_address IS NULL
    THEN 'Saída definida' ELSE 'Saída alterada' END;
  corpo := '"' || NEW.title || '": '
    || CASE WHEN COALESCE(NEW.meeting_label, NEW.meeting_address) IS NOT NULL
            THEN 'encontro em ' || COALESCE(NEW.meeting_label, NEW.meeting_address) || '. '
            ELSE '' END
    || 'Toque para ver o horário.';

  INSERT INTO notifications (user_id, type, title, body, data)
  SELECT u.user_id, 'event_update', titulo, corpo, jsonb_build_object('eventId', NEW.id)
    FROM (
      SELECT user_id FROM event_interests WHERE event_id = NEW.id
      UNION
      SELECT user_id FROM event_participants
       WHERE event_id = NEW.id AND rsvp IN ('going', 'maybe')
    ) u
   WHERE u.user_id IS DISTINCT FROM auth.uid();
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS trg_notifica_saida_alterada ON events;
CREATE TRIGGER trg_notifica_saida_alterada
  AFTER UPDATE OF departure_at, meeting_label, meeting_address ON events
  FOR EACH ROW EXECUTE FUNCTION public.notifica_saida_alterada();
