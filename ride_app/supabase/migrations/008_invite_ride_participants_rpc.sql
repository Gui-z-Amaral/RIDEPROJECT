-- ─────────────────────────────────────────────────────────────────────────────
-- RPC invite_ride_participants
--
-- Permite ao CRIADOR do rolê adicionar amigos em ride_participants. A política
-- RLS dessa tabela só deixa o próprio usuário se inserir (auth.uid() = user_id),
-- então sem essa função o batch insert em createRide falha silenciosamente e
-- os convidados nunca entram no rolê.
--
-- Esta função roda com SECURITY DEFINER (privilégios do dono da função) mas
-- restringe acesso checando que o auth.uid() é o creator_id do rolê.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.invite_ride_participants(
    p_ride_id UUID,
    p_user_ids UUID[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Só o criador do rolê pode convidar
    IF NOT EXISTS (
        SELECT 1 FROM rides
        WHERE id = p_ride_id AND creator_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Only the ride creator can invite participants';
    END IF;

    -- Insere (ou ignora duplicatas) cada user_id como participante com
    -- status 'waiting' — o usuário convidado depois confirma/recusa.
    INSERT INTO ride_participants (ride_id, user_id, status)
    SELECT p_ride_id, unnest(p_user_ids), 'waiting'
    ON CONFLICT (ride_id, user_id) DO NOTHING;
END;
$$;

-- Permite que usuários autenticados chamem a RPC.
GRANT EXECUTE ON FUNCTION public.invite_ride_participants(UUID, UUID[])
    TO authenticated;
