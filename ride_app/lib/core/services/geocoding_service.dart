import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_config.dart';

class PlaceInfo {
  final String name;
  final String address;
  final String? category;
  final String? placeId;

  const PlaceInfo({
    required this.name,
    required this.address,
    this.category,
    this.placeId,
  });
}

class GeocodingService {
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

      final first = results[0] as Map<String, dynamic>;
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
        final namePart = components
            .where((c) => (c['types'] as List).contains('establishment') ||
                (c['types'] as List).contains('point_of_interest') ||
                (c['types'] as List).contains('premise'))
            .map((c) => c['long_name'] as String)
            .firstOrNull;
        if (namePart != null) name = namePart;
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

      // Endereço resumido: bairro + cidade
      final neighborhood = components
          .where((c) =>
              (c['types'] as List).contains('sublocality') ||
              (c['types'] as List).contains('neighborhood'))
          .map((c) => c['long_name'] as String)
          .firstOrNull;
      final city = components
          .where((c) =>
              (c['types'] as List).contains('administrative_area_level_2') ||
              (c['types'] as List).contains('locality'))
          .map((c) => c['long_name'] as String)
          .firstOrNull;

      final addressParts = [neighborhood, city].whereType<String>().toList();
      final shortAddress =
          addressParts.isNotEmpty ? addressParts.join(', ') : formattedAddress;

      // Categoria
      final category = _categoryFromTypes(types);

      return PlaceInfo(
        name: name,
        address: shortAddress,
        category: category,
        placeId: placeId,
      );
    } catch (_) {
      return null;
    }
  }

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
