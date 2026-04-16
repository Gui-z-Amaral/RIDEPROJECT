import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';

class PlaceInfo {
  final String name;
  final String address;
  final String? category;
  final String? placeId;
  final bool? openNow;
  final List<String>? weekdayText; // índice 0=segunda, 6=domingo

  // Campos de endereço estruturado (para preencher formulário)
  final String? streetName;   // nome da rua
  final String? streetNumber; // número
  final String? neighborhood; // bairro
  final String? postalCode;   // CEP (só dígitos)

  // Foto do estabelecimento (Places API photo_reference)
  final String? photoRef;

  const PlaceInfo({
    required this.name,
    required this.address,
    this.category,
    this.placeId,
    this.openNow,
    this.weekdayText,
    this.streetName,
    this.streetNumber,
    this.neighborhood,
    this.postalCode,
    this.photoRef,
  });

  /// Horário de hoje ex.: "09:00 – 22:00" (ou null se indisponível).
  String? get todayHours {
    if (weekdayText == null || weekdayText!.isEmpty) return null;
    final idx = DateTime.now().weekday - 1; // 1=seg→0, 7=dom→6
    if (idx < 0 || idx >= weekdayText!.length) return null;
    final raw = weekdayText![idx];
    // Remove o prefixo do dia (ex. "Segunda-feira: ") e retorna só o horário
    final colon = raw.indexOf(': ');
    return colon >= 0 ? raw.substring(colon + 2) : raw;
  }

  /// URL para exibir a foto via Places Photo API.
  String? get photoUrl {
    if (photoRef == null || photoRef!.isEmpty) return null;
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=600&photo_reference=$photoRef'
        '&key=${AppConfig.googleMapsApiKey}';
  }
}

class GeocodingService {
  /// Reverse-geocodes [lat]/[lng].
  /// Prefers establishment/POI results over plain street addresses.
  /// For establishments, extracts the business name from formattedAddress
  /// (the part before the first comma) when address components don't carry it.
  static Future<PlaceInfo?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&language=pt-BR'
        '&key=${AppConfig.googleMapsApiKey}',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final results = data['results'] as List<dynamic>;
      if (results.isEmpty) return null;

      // Prefer establishment / POI over plain routes
      Map<String, dynamic> first = results[0] as Map<String, dynamic>;
      for (final r in results.cast<Map<String, dynamic>>()) {
        final rTypes = (r['types'] as List<dynamic>? ?? []).cast<String>();
        if (rTypes.any((t) =>
            t == 'establishment' ||
            t == 'point_of_interest' ||
            t == 'premise')) {
          first = r;
          break;
        }
      }

      final components =
          (first['address_components'] as List<dynamic>).cast<Map<String, dynamic>>();
      final types = (first['types'] as List<dynamic>).cast<String>();
      final formattedAddress = first['formatted_address'] as String? ?? '';
      final placeId = first['place_id'] as String?;

      // Tenta extrair nome do estabelecimento (primeiro componente do endereço)
      String name = formattedAddress;

      // Se for estabelecimento ou ponto de interesse, o nome está no primeiro componente
      final isEstablishment = types.any((t) =>
          t == 'establishment' ||
          t == 'point_of_interest' ||
          t == 'premise' ||
          t == 'natural_feature');

      if (isEstablishment) {
        // Try address components first
        final namePart = components
            .where((c) => (c['types'] as List).contains('establishment') ||
                (c['types'] as List).contains('point_of_interest') ||
                (c['types'] as List).contains('premise'))
            .map((c) => c['long_name'] as String)
            .firstOrNull;
        if (namePart != null) {
          name = namePart;
        } else {
          // formattedAddress for POIs usually starts with the business name
          // before the first comma, e.g. "Posto Shell, Av. ..."
          final firstComma = formattedAddress.indexOf(',');
          if (firstComma > 0) {
            name = formattedAddress.substring(0, firstComma).trim();
          }
        }
      } else {
        // Para ruas, usa número + nome da rua
        final streetNumber = components
            .where((c) => (c['types'] as List).contains('street_number'))
            .map((c) => c['long_name'] as String)
            .firstOrNull;
        final route = components
            .where((c) => (c['types'] as List).contains('route'))
            .map((c) => c['long_name'] as String)
            .firstOrNull;
        if (route != null) {
          name = streetNumber != null ? '$route, $streetNumber' : route;
        }
      }

      // Endereço estruturado
      String? getComp(List<String> t) => components
          .where((c) => (c['types'] as List).any(t.contains))
          .map((c) => c['long_name'] as String)
          .firstOrNull;

      final streetNameParsed  = getComp(['route']);
      final streetNumParsed   = getComp(['street_number']);
      final neighborhoodParsed = getComp(['sublocality', 'sublocality_level_1', 'neighborhood']);
      final postalCodeParsed  = getComp(['postal_code'])?.replaceAll(RegExp(r'\D'), '');
      final city = getComp(['administrative_area_level_2', 'locality']);

      final addressParts = [neighborhoodParsed, city].whereType<String>().toList();
      final shortAddress =
          addressParts.isNotEmpty ? addressParts.join(', ') : formattedAddress;

      // Categoria
      final category = _categoryFromTypes(types);

      return PlaceInfo(
        name: name,
        address: shortAddress,
        category: category,
        placeId: placeId,
        streetName: streetNameParsed,
        streetNumber: streetNumParsed,
        neighborhood: neighborhoodParsed,
        postalCode: postalCodeParsed,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tries to find the nearest named place via the Places Nearby Search API.
  /// Used as a fallback when [reverseGeocode] returns null (e.g. no street
  /// coverage) so that POI taps on the map always resolve to a real place name.
  static Future<PlaceInfo?> nearbySearch(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
        '?location=$lat,$lng'
        '&rankby=distance'
        '&language=pt-BR'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK') return null;

      final results = (data['results'] as List<dynamic>? ?? []);
      if (results.isEmpty) return null;

      final place = results[0] as Map<String, dynamic>;
      final name = place['name'] as String? ?? '';
      if (name.isEmpty) return null;

      final vicinity = place['vicinity'] as String? ?? '';
      final types = (place['types'] as List<dynamic>? ?? []).cast<String>();
      final category = _categoryFromTypes(types);
      final placeId = place['place_id'] as String?;

      // Only use if the place is within 100m
      final geo = (place['geometry'] as Map<String, dynamic>)['location']
          as Map<String, dynamic>;
      final pLat = (geo['lat'] as num).toDouble();
      final pLng = (geo['lng'] as num).toDouble();
      final distSq = (pLat - lat) * (pLat - lat) + (pLng - lng) * (pLng - lng);
      // ~100m ≈ 0.001 degree → 0.001² = 0.000001
      if (distSq > 0.000002) return null;

      return PlaceInfo(
        name: name,
        address: vicinity,
        category: category,
        placeId: placeId,
      );
    } catch (_) {
      return null;
    }
  }

  static String? categoryFromTypes(List<String> types) => _categoryFromTypes(types);

  static String? _categoryFromTypes(List<String> types) {
    if (types.contains('restaurant') || types.contains('food')) return 'Restaurante';
    if (types.contains('cafe')) return 'Café';
    if (types.contains('bar')) return 'Bar';
    if (types.contains('gas_station')) return 'Posto de combustível';
    if (types.contains('lodging')) return 'Hospedagem';
    if (types.contains('park')) return 'Parque';
    if (types.contains('tourist_attraction')) return 'Atração turística';
    if (types.contains('shopping_mall') || types.contains('store')) return 'Comércio';
    if (types.contains('hospital') || types.contains('health')) return 'Saúde';
    if (types.contains('school') || types.contains('university')) return 'Educação';
    if (types.contains('church') || types.contains('place_of_worship')) return 'Local de culto';
    if (types.contains('route')) return 'Rua';
    if (types.contains('intersection')) return 'Cruzamento';
    if (types.contains('natural_feature')) return 'Área natural';
    if (types.contains('beach')) return 'Praia';
    return null;
  }
}
