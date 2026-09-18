-- ─────────────────────────────────────────────────────────────────────────────
-- 039: completa a troca de domínio que a 033 deixou pela metade
--
-- A 033 migrou events.banner_url, trips.cover_image, profiles.avatar_url,
-- trip_photos.photo_url e trip_stops.image_url — uma lista escrita À MÃO, e por
-- isso incompleta. Estas cinco colunas continuaram apontando para
-- srv1689008.hstgr.cloud, que foi fechado quando a porta 443 passou a aceitar
-- só a Cloudflare. Resultado: foto e banner de motoclube pararam de carregar.
--
-- A lista abaixo saiu de uma VARREDURA do information_schema, não de memória.
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE clubs SET avatar_url = replace(avatar_url, 'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE avatar_url LIKE '%srv1689008.hstgr.cloud%';

UPDATE clubs SET banner_url = replace(banner_url, 'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE banner_url LIKE '%srv1689008.hstgr.cloud%';

UPDATE profiles SET business_banner_url = replace(business_banner_url, 'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE business_banner_url LIKE '%srv1689008.hstgr.cloud%';

UPDATE featured_photos SET photo_url = replace(photo_url, 'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE photo_url LIKE '%srv1689008.hstgr.cloud%';

UPDATE profile_customizations SET banner_url = replace(banner_url, 'https://srv1689008.hstgr.cloud', 'https://api.ride.dev.br')
  WHERE banner_url LIKE '%srv1689008.hstgr.cloud%';
