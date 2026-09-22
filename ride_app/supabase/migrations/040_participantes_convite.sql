-- 040 — Convite de viagem/rolê: o criador nunca teve permissão de convidar
--
-- A policy anterior era `WITH CHECK (auth.uid() = user_id)`, então o INSERT em
-- lote que o app fazia ao criar a viagem (criador + convidados) era rejeitado
-- inteiro pela RLS. O app engolia o erro num `catch` e inseria só o criador —
-- o convidado recebia a notificação, tocava em aceitar, e o UPDATE seguinte
-- não encontrava linha nenhuma. O PostgREST responde 204 sem erro nesse caso,
-- então a tela dizia "Você aceitou o convite!" e nada acontecia. Nenhum
-- convite de viagem ou de rolê jamais funcionou.
--
-- De quebra, a policy antiga abria uma falha: como `trips_select` (034) dá
-- leitura a quem é participante, qualquer usuário logado podia se inserir numa
-- viagem PRIVADA de terceiro e passar a ler rota, endereços e participantes.
-- Bastava conhecer o id. Por isso o auto-cadastro agora exige que a viagem
-- seja pública ou do motoclube da pessoa.

-- ── Viagens ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "trip_part_insert" ON trip_participants;
CREATE POLICY "trip_part_insert" ON trip_participants FOR INSERT
  WITH CHECK (
    -- 1. O criador convida. O convite nasce pendente de propósito: quem
    --    confirma é a própria pessoa, pela trip_part_update.
    (status = 'waiting'
     AND EXISTS (SELECT 1 FROM trips t
                 WHERE t.id = trip_id AND t.creator_id = auth.uid()))

    -- 2. Eu me inscrevo sozinho — só onde já posso entrar por conta própria.
    OR (auth.uid() = user_id
        AND EXISTS (SELECT 1 FROM trips t
                    WHERE t.id = trip_id
                      AND (t.is_public
                           OR t.creator_id = auth.uid()
                           OR (t.club_id IS NOT NULL
                               AND public.is_club_member(t.club_id, auth.uid())))))
  );

-- ── Rolês ───────────────────────────────────────────────────────────────────
-- `rides_select` é USING (true) — todo rolê já é legível por qualquer um, então
-- aqui não há o que fechar: o auto-cadastro continua livre. O que faltava era
-- só o criador poder convidar.
DROP POLICY IF EXISTS "ride_part_insert" ON ride_participants;
CREATE POLICY "ride_part_insert" ON ride_participants FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    OR (status = 'waiting'
        AND EXISTS (SELECT 1 FROM rides r
                    WHERE r.id = ride_id AND r.creator_id = auth.uid()))
  );

-- ── Conserto dos convites que se perderam ───────────────────────────────────
-- Todo convite de viagem feito até aqui nunca virou linha em trip_participants.
-- A informação não se perdeu: a notificação `trip_invite` guarda o destinatário
-- (user_id) e a viagem (data->>'tripId'). Reconstruímos a partir dela, como
-- PENDENTE — aceitar continua sendo decisão de quem foi convidado, não nossa.
INSERT INTO trip_participants (trip_id, user_id, status)
SELECT DISTINCT (n.data->>'tripId')::uuid, n.user_id, 'waiting'
  FROM notifications n
  JOIN trips t ON t.id = (n.data->>'tripId')::uuid
 WHERE n.type = 'trip_invite'
   AND n.data->>'tripId' IS NOT NULL
   AND n.user_id <> t.creator_id
ON CONFLICT (trip_id, user_id) DO NOTHING;
