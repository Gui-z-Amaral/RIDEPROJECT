-- 033: aponta as URLs salvas para o domínio novo da API.
--
-- Contexto: a API saiu de srv1689008.hstgr.cloud (hostname da Hostinger, que
-- publica o IP da VPS e não passa pela Cloudflare) para api.ride.dev.br, atrás
-- da Cloudflare. O passo seguinte é aceitar conexões na 443 só vindas da
-- Cloudflare — e aí o host antigo deixa de responder.
--
-- Estas colunas guardam URL ABSOLUTA. O app monta URLs novas a partir de
-- SupabaseConfig.url, então só os registros antigos ficam presos ao host velho;
-- sem esta migration, banners de evento, capas de viagem, fotos e avatares
-- parariam de carregar.
--
-- replace() troca só o host e preserva caminho e query — a URL de foto do proxy
-- gmaps leva parâmetros que não podem ser perdidos.
--
-- Reversível: basta rodar o mesmo com os domínios invertidos.

UPDATE events      SET banner_url  = replace(banner_url,  'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE banner_url  LIKE '%srv1689008.hstgr.cloud%';

UPDATE trips       SET cover_image = replace(cover_image, 'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE cover_image LIKE '%srv1689008.hstgr.cloud%';

UPDATE profiles    SET avatar_url  = replace(avatar_url,  'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE avatar_url  LIKE '%srv1689008.hstgr.cloud%';

UPDATE trip_photos SET photo_url   = replace(photo_url,   'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE photo_url   LIKE '%srv1689008.hstgr.cloud%';

UPDATE trip_stops  SET image_url   = replace(image_url,   'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE image_url   LIKE '%srv1689008.hstgr.cloud%';
