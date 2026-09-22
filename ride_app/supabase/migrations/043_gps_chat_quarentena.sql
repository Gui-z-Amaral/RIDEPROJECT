-- 043 — GPS só para quem está no rolê, imagem do chat privada, e quarentena
--       das fotos de conta desativada (auditoria LGPD: L-01, L-04, L-05)
--
-- Também fecha uma falha achada no caminho: `avatars_storage_update` era
-- `auth.uid() IS NOT NULL`, ou seja, qualquer conta sobrescrevia a foto de
-- perfil de qualquer outra com um upload em modo upsert.
--
-- Os caminhos que o app grava, e em que as policies abaixo confiam:
--   avatars      <uid>/<prefixo>_<ts>.jpg          (StorageUtils)
--   trip-photos  trip/<trip_id>/<uid>_<ts>.jpg     (uploadTripPhoto)
--   chat-images  chat/<uidA>_<uidB>/<ts>.jpg       (uploadChatImage)
-- UUID não tem "_", então separar por "_" é seguro.

-- ══ L-01 · GPS ═══════════════════════════════════════════════════════════════
-- `ride_locations` guarda a ÚLTIMA posição de cada pessoa em cada rolê (chave
-- ride_id + user_id, gravada por upsert). Era legível por qualquer conta logada.

DROP POLICY IF EXISTS "ride_loc_select" ON ride_locations;
CREATE POLICY "ride_loc_select" ON ride_locations FOR SELECT USING (
  EXISTS (SELECT 1 FROM ride_participants rp
           WHERE rp.ride_id = ride_locations.ride_id AND rp.user_id = auth.uid())
  OR EXISTS (SELECT 1 FROM rides r
              WHERE r.id = ride_locations.ride_id AND r.creator_id = auth.uid())
);

-- Publicar posição também exige estar no rolê: antes bastava ser o dono da
-- linha, então dava para "aparecer" no mapa de um rolê alheio.
DROP POLICY IF EXISTS "ride_loc_insert" ON ride_locations;
CREATE POLICY "ride_loc_insert" ON ride_locations FOR INSERT WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (SELECT 1 FROM ride_participants rp
               WHERE rp.ride_id = ride_locations.ride_id AND rp.user_id = auth.uid())
);

-- Rolê encerrado não precisa de posição de ninguém. SECURITY DEFINER porque
-- quem encerra é o criador, e a RLS só deixa cada um apagar a própria linha.
CREATE OR REPLACE FUNCTION public.limpa_gps_do_role()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status IN ('completed', 'cancelled')
     AND OLD.status IS DISTINCT FROM NEW.status THEN
    DELETE FROM ride_locations WHERE ride_id = NEW.id;
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_limpa_gps_do_role ON rides;
CREATE TRIGGER trg_limpa_gps_do_role AFTER UPDATE OF status ON rides
  FOR EACH ROW EXECUTE FUNCTION public.limpa_gps_do_role();

-- Rolê que nunca foi encerrado (app fechado, bateria acabou) deixaria posição
-- para sempre. Posição sem atualização há 12 h não serve para nenhum mapa ao
-- vivo. Chamada pelo timer diário da VPS (infra/bin/purge-contas.sh).
CREATE OR REPLACE FUNCTION public.purge_gps_antigo()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n INT;
BEGIN
  DELETE FROM ride_locations WHERE updated_at < NOW() - INTERVAL '12 hours';
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END; $$;
REVOKE ALL ON FUNCTION public.purge_gps_antigo() FROM PUBLIC, anon, authenticated;

-- ══ L-04 · Imagem do chat ════════════════════════════════════════════════════
-- Bucket privado: a URL pública para de funcionar. O app passa a pedir URL
-- assinada, e o Storage só assina se a policy de SELECT deixar.
UPDATE storage.buckets SET public = false WHERE id = 'chat-images';

DROP POLICY IF EXISTS "chat_images_storage_select" ON storage.objects;
CREATE POLICY "chat_images_storage_select" ON storage.objects FOR SELECT USING (
  bucket_id = 'chat-images'
  AND split_part(name, '/', 1) = 'chat'
  AND auth.uid()::text IN (
    split_part(split_part(name, '/', 2), '_', 1),
    split_part(split_part(name, '/', 2), '_', 2))
);

-- Subir só na pasta de uma conversa da qual se participa (antes: qualquer
-- pasta, de qualquer conversa).
DROP POLICY IF EXISTS "chat_images_storage_insert" ON storage.objects;
CREATE POLICY "chat_images_storage_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'chat-images'
  AND split_part(name, '/', 1) = 'chat'
  AND auth.uid()::text IN (
    split_part(split_part(name, '/', 2), '_', 1),
    split_part(split_part(name, '/', 2), '_', 2))
);

-- ══ Correção: foto de perfil alheia podia ser sobrescrita ═══════════════════
DROP POLICY IF EXISTS "avatars_storage_insert" ON storage.objects;
CREATE POLICY "avatars_storage_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'avatars'
  AND split_part(name, '/', 1) = auth.uid()::text
);
DROP POLICY IF EXISTS "avatars_storage_update" ON storage.objects;
CREATE POLICY "avatars_storage_update" ON storage.objects FOR UPDATE USING (
  bucket_id = 'avatars' AND owner = auth.uid()
);
DROP POLICY IF EXISTS "trip_photos_storage_insert" ON storage.objects;
CREATE POLICY "trip_photos_storage_insert" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'trip-photos'
  AND split_part(name, '/', 1) = 'trip'
  AND split_part(split_part(name, '/', 3), '_', 1) = auth.uid()::text
);

-- ══ L-05 · Quarentena das fotos de conta desativada ═════════════════════════
-- Buckets públicos ignoram RLS na leitura: a única forma de uma foto ficar
-- inacessível sem ser apagada é sair do bucket público. Na desativação, a Edge
-- Function `quarentena` move os arquivos da pessoa para este bucket privado;
-- na reativação, devolve; no fim da retenção, apaga.
--
-- Sem nenhuma policy de propósito: só a service_role (dentro da função) lê ou
-- escreve aqui. Nem o próprio dono acessa enquanto a conta está desativada.
INSERT INTO storage.buckets (id, name, public)
VALUES ('quarentena', 'quarentena', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Arquivos PESSOAIS da pessoa nos buckets públicos.
--
-- `avatars` também guarda banner/logo de motoclube e banner/patrocinador de
-- evento, na pasta de quem subiu. Esses NÃO podem ir para a quarentena: o
-- clube e o evento são de outras pessoas também, e sumiriam para todo mundo
-- quando o gerente desativasse a conta. Por isso `avatars` usa lista de
-- PERMITIDOS por prefixo (avatar, banner do perfil comercial, banner do
-- perfil) — um prefixo novo fica fora até alguém decidir, que é o lado seguro.
--
-- Casa por `owner` e também pelo caminho, porque upload antigo pode ter
-- ficado sem dono gravado.
CREATE OR REPLACE FUNCTION public.arquivos_publicos_de(p_uid UUID)
RETURNS TABLE (bucket_id TEXT, name TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, storage AS $$
  SELECT o.bucket_id, o.name FROM storage.objects o
   WHERE (o.bucket_id = 'avatars'
          AND split_part(o.name, '/', 1) = p_uid::text
          AND split_part(o.name, '/', 2) ~ '^(avatar|banner|profile_banner)_')
      OR (o.bucket_id = 'user-photos'
          AND (o.owner = p_uid OR split_part(o.name, '/', 1) = p_uid::text))
      OR (o.bucket_id = 'trip-photos'
          AND (o.owner = p_uid
               OR split_part(split_part(o.name, '/', 3), '_', 1) = p_uid::text));
$$;

-- Na quarentena, o caminho é <uid>/<bucket de origem>/<caminho original>.
CREATE OR REPLACE FUNCTION public.arquivos_em_quarentena(p_uid UUID)
RETURNS TABLE (name TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, storage AS $$
  SELECT o.name FROM storage.objects o
   WHERE o.bucket_id = 'quarentena'
     AND split_part(o.name, '/', 1) = p_uid::text;
$$;

-- Contas que o purge vai apagar — a função da quarentena usa esta lista para
-- apagar os arquivos ANTES de o registro sumir (apagar só a linha do banco
-- deixaria o arquivo órfão no disco).
CREATE OR REPLACE FUNCTION public.contas_para_apagar(older_than INTERVAL DEFAULT '6 months')
RETURNS TABLE (id UUID)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.id FROM profiles p
   WHERE p.deactivated_at IS NOT NULL AND p.deactivated_at < NOW() - older_than;
$$;

REVOKE ALL ON FUNCTION public.arquivos_publicos_de(UUID)       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.arquivos_em_quarentena(UUID)     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.contas_para_apagar(INTERVAL)     FROM PUBLIC, anon, authenticated;

-- Explícito: a Edge Function chama estas funções como service_role, e revogar
-- de PUBLIC poderia levar junto uma concessão que viesse só por ali.
GRANT EXECUTE ON FUNCTION public.arquivos_publicos_de(UUID)            TO service_role;
GRANT EXECUTE ON FUNCTION public.arquivos_em_quarentena(UUID)          TO service_role;
GRANT EXECUTE ON FUNCTION public.contas_para_apagar(INTERVAL)          TO service_role;
GRANT EXECUTE ON FUNCTION public.purge_deactivated_accounts(INTERVAL)  TO service_role;
GRANT EXECUTE ON FUNCTION public.purge_gps_antigo()                    TO service_role;

-- Fotos de viagem de conta desativada somem da galeria dos outros: o arquivo
-- foi para a quarentena, e a linha apontaria para uma imagem quebrada.
DROP POLICY IF EXISTS "trip_photos_select" ON trip_photos;
CREATE POLICY "trip_photos_select" ON trip_photos FOR SELECT USING (
  NOT EXISTS (SELECT 1 FROM profiles p
               WHERE p.id = trip_photos.uploaded_by AND p.deactivated_at IS NOT NULL)
);
DROP POLICY IF EXISTS "featured_photos_select" ON featured_photos;
CREATE POLICY "featured_photos_select" ON featured_photos FOR SELECT USING (
  NOT EXISTS (SELECT 1 FROM profiles p
               WHERE p.id = featured_photos.user_id AND p.deactivated_at IS NOT NULL)
);

-- ══ Limpeza do que já existe (IRREVERSÍVEL) ══════════════════════════════════
-- Posição de rolê encerrado e posição parada há mais de 12 h.
DELETE FROM ride_locations rl
 USING rides r
 WHERE r.id = rl.ride_id AND r.status IN ('completed', 'cancelled');
DELETE FROM ride_locations WHERE updated_at < NOW() - INTERVAL '12 hours';
