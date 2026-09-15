import '../constants/supabase_config.dart';

/// Proxy para os *web services* do Google Maps (Places, Geocoding, Directions).
///
/// Por que existe:
///  - Na **web** o navegador bloqueia chamadas diretas ao Google por **CORS**;
///  - Em **todas** as plataformas mantém a chave da API só no servidor
///    (a Edge Function `gmaps` injeta a chave; o cliente nunca a envia).
///
/// A Edge Function fica em `supabase/functions/gmaps/` e é servida em
/// `<SUPABASE_URL>/functions/v1/gmaps`.
///
/// Observação: isto cobre só as chamadas REST. O **mapa** em si (tiles) usa a
/// Maps JavaScript API no navegador (chave no `web/index.html`) e o SDK nativo
/// no celular — nenhum dos dois passa por aqui.
class MapsProxy {
  static final Uri _endpoint =
      Uri.parse('${SupabaseConfig.url}/functions/v1/gmaps');

  /// Monta a URL do proxy para um caminho da API do Google Maps
  /// (ex.: `place/textsearch/json`) com os parâmetros de query.
  /// NÃO inclua `key` em [params] — o servidor injeta.
  static Uri uri(String apiPath, Map<String, String> params) {
    return _endpoint.replace(queryParameters: {
      'path': apiPath,
      ...params,
    });
  }

  /// Cabeçalhos exigidos pelo gateway do Supabase (apikey anônima).
  static Map<String, String> get headers => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      };

  /// `true` para URLs de foto salvas **antes** do proxy existir: apontam direto
  /// para o Google e quebram na web (sem CORS). Quem encontrar uma dessas deve
  /// tratá-la como ausente e re-resolver a foto pelo proxy.
  static bool isLegacyGooglePhotoUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('maps.googleapis.com');
  }

  /// URL de foto pronta pra `Image.network`/`CachedNetworkImage`. Como a
  /// imagem é carregada por `<img>`/CanvasKit (sem cabeçalhos), a `apikey`
  /// vai na query. Passa pelo proxy pra ter CORS (o CanvasKit lê o pixel da
  /// imagem, o que exige CORS — o endpoint do Google não manda).
  static String photoUrl(Map<String, String> params) {
    return _endpoint.replace(queryParameters: {
      'path': 'place/photo',
      ...params,
      'apikey': SupabaseConfig.anonKey,
    }).toString();
  }
}
