import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'maps_proxy.dart';

enum RecommendationReason {
  nearbyRestaurant, // Restaurante próximo (< 2km)
  nearbyFuel, // Posto próximo (< 2km)
  nearestFuel, // Posto mais próximo (fallback)
  nearestLodging, // Hospedagem mais próxima (fallback)
  tripBased, // Baseado na próxima viagem
  trustedBusiness, // Empresa confiável (nota alta no Google)
}

/// Categorias de empresas confiáveis exibidas na seção "Encontre Empresas".
enum BusinessCategory {
  gasStation, // Postos de combustível
  mechanic, // Oficinas mecânicas
  tireShop, // Borracharias
  carWash, // Lava-rápido
}

extension BusinessCategoryX on BusinessCategory {
  String get label {
    switch (this) {
      case BusinessCategory.gasStation:
        return 'Postos';
      case BusinessCategory.mechanic:
        return 'Oficinas';
      case BusinessCategory.tireShop:
        return 'Borracharias';
      case BusinessCategory.carWash:
        return 'Lava-rápido';
    }
  }

  /// Tipo do Google Places (null usa somente keyword)
  String? get googleType {
    switch (this) {
      case BusinessCategory.gasStation:
        return 'gas_station';
      case BusinessCategory.mechanic:
        return 'car_repair';
      case BusinessCategory.tireShop:
        return null; // não existe tipo específico, usa keyword
      case BusinessCategory.carWash:
        return 'car_wash';
    }
  }

  /// Keyword adicional para filtrar resultados (útil para categorias brasileiras)
  String? get keyword {
    switch (this) {
      case BusinessCategory.tireShop:
        return 'borracharia';
      default:
        return null;
    }
  }
}

class PlaceRecommendation {
  final String placeId;
  final String name;
  final String vicinity;
  final double? rating;
  final int? userRatingsTotal;
  final String type;
  final String typeLabel;
  final String? photoRef;
  final double lat;
  final double lng;
  final double distanceKm;
  final bool isOpenNow;
  final RecommendationReason reason;
  final String? tripContext;

  const PlaceRecommendation({
    required this.placeId,
    required this.name,
    required this.vicinity,
    this.rating,
    this.userRatingsTotal,
    required this.type,
    required this.typeLabel,
    this.photoRef,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.isOpenNow,
    required this.reason,
    this.tripContext,
  });

  // Foto passa pelo proxy: o CanvasKit (Flutter web) lê o pixel da imagem e
  // isso exige CORS, que o endpoint do Google não manda. A apikey vai na query.
  String get photoUrl {
    if (photoRef == null || photoRef!.isEmpty) return '';
    return MapsProxy.photoUrl({
      'maxwidth': '400',
      'photo_reference': photoRef!,
    });
  }

  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1'
      '&query=${Uri.encodeQueryComponent(name)}'
      '&query_place_id=$placeId';

  String get distanceLabel {
    if (distanceKm < 1) return '${(distanceKm * 1000).round()}m';
    return '${distanceKm.toStringAsFixed(1)}km';
  }
}

class PlacesService {
  // Cliente HTTP injetável — em produção é o default do package:http;
  // em testes pode ser substituído por um MockClient via [debugSetClient].
  static http.Client _client = http.Client();

  /// Permite substituir o cliente HTTP em testes.
  /// Use [debugResetClient] no tearDown para restaurar o default.
  @visibleForTesting
  static void debugSetClient(http.Client client) => _client = client;

  @visibleForTesting
  static void debugResetClient() => _client = http.Client();

  // ── Haversine distance (km) ────────────────────────────────────────────────
  static double _dist(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Nearby Search ──────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _search({
    required double lat,
    required double lng,
    String? type,
    String? keyword,
    int? radius,
    bool rankByDistance = false,
  }) async {
    try {
      final params = <String, String>{
        'location': '$lat,$lng',
        'language': 'pt-BR',
      };
      if (type != null) params['type'] = type;
      if (keyword != null) params['keyword'] = keyword;
      if (rankByDistance) {
        params['rankby'] = 'distance';
      } else {
        params['radius'] = (radius ?? 2000).toString();
      }

      final url = MapsProxy.uri('place/nearbysearch/json', params);
      final res = await _client
          .get(url, headers: MapsProxy.headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') return [];

      return List<Map<String, dynamic>>.from(
          (data['results'] as List?) ?? []);
    } catch (_) {
      return [];
    }
  }

  // ── Parse result row ───────────────────────────────────────────────────────
  static PlaceRecommendation _parse(
    Map<String, dynamic> place,
    double originLat,
    double originLng,
    String type,
    String typeLabel,
    RecommendationReason reason, {
    String? tripContext,
  }) {
    final geo =
        (place['geometry'] as Map<String, dynamic>)['location']
            as Map<String, dynamic>;
    final pLat = (geo['lat'] as num).toDouble();
    final pLng = (geo['lng'] as num).toDouble();
    final photos = place['photos'] as List?;
    final hours = place['opening_hours'] as Map?;

    return PlaceRecommendation(
      placeId: place['place_id'] as String? ?? '',
      name: place['name'] as String? ?? '',
      // Nearby Search usa 'vicinity'; Text Search usa 'formatted_address'.
      vicinity: (place['vicinity'] as String?) ??
          (place['formatted_address'] as String?) ??
          '',
      rating: (place['rating'] as num?)?.toDouble(),
      userRatingsTotal: place['user_ratings_total'] as int?,
      type: type,
      typeLabel: typeLabel,
      photoRef: photos != null && photos.isNotEmpty
          ? (photos[0] as Map<String, dynamic>)['photo_reference'] as String?
          : null,
      lat: pLat,
      lng: pLng,
      distanceKm: _dist(originLat, originLng, pLat, pLng),
      isOpenNow: hours?['open_now'] as bool? ?? true,
      reason: reason,
      tripContext: tripContext,
    );
  }

  // ── Sort helper ────────────────────────────────────────────────────────────
  static List<Map<String, dynamic>> _sortByRating(
      List<Map<String, dynamic>> list) {
    return [...list]
      ..sort((a, b) =>
          ((b['rating'] as num?) ?? 0)
              .compareTo((a['rating'] as num?) ?? 0));
  }

  // ── Main recommendation logic ──────────────────────────────────────────────
  /// Retorna sugestões de lugares para o usuário:
  ///
  /// 1. Restaurantes com rating > 4.0 num raio de 2km (até 3)
  /// 2. Posto de combustível num raio de 2km (até 1)
  /// 3. Fallback se < 2 resultados: posto mais próximo + hospedagem mais próxima
  /// 4. Baseado na próxima viagem: restaurantes perto do destino (até 2)
  static Future<List<PlaceRecommendation>> getRecommendations({
    required double lat,
    required double lng,
    double? tripDestLat,
    double? tripDestLng,
    String? tripDestName,
  }) async {
    // Busca paralela: restaurantes e postos dentro de 2km
    final nearbyResults = await Future.wait([
      _search(lat: lat, lng: lng, type: 'restaurant', radius: 2000),
      _search(lat: lat, lng: lng, type: 'gas_station', radius: 2000),
    ]);

    final nearbyRestaurants = nearbyResults[0];
    final nearbyFuel = nearbyResults[1];

    final recommendations = <PlaceRecommendation>[];

    // Top 3 restaurantes por rating
    for (final r in _sortByRating(nearbyRestaurants).take(3)) {
      recommendations.add(_parse(
        r, lat, lng, 'restaurant', 'Restaurante',
        RecommendationReason.nearbyRestaurant,
      ));
    }

    // Top 1 posto por rating
    for (final f in _sortByRating(nearbyFuel).take(1)) {
      recommendations.add(_parse(
        f, lat, lng, 'gas_station', 'Posto de combustível',
        RecommendationReason.nearbyFuel,
      ));
    }

    // ── Fallback: menos de 2 resultados ───────────────────────────────────────
    if (recommendations.length < 2) {
      final fallback = await Future.wait([
        if (!recommendations.any((r) => r.type == 'gas_station'))
          _search(lat: lat, lng: lng, type: 'gas_station', rankByDistance: true),
        _search(lat: lat, lng: lng, type: 'lodging', rankByDistance: true),
      ]);

      int idx = 0;
      if (!recommendations.any((r) => r.type == 'gas_station')) {
        final fuelList = fallback[idx++];
        if (fuelList.isNotEmpty) {
          recommendations.add(_parse(
            fuelList.first, lat, lng, 'gas_station', 'Posto de combustível',
            RecommendationReason.nearestFuel,
          ));
        }
      } else {
        idx++;
      }
      final lodgingList = fallback.length > idx ? fallback[idx] : <Map<String, dynamic>>[];
      if (lodgingList.isNotEmpty) {
        recommendations.add(_parse(
          lodgingList.first, lat, lng, 'lodging', 'Hospedagem',
          RecommendationReason.nearestLodging,
        ));
      }
    }

    // ── Baseado na próxima viagem ──────────────────────────────────────────────
    if (tripDestLat != null && tripDestLng != null) {
      final tripPlaces = await _search(
        lat: tripDestLat,
        lng: tripDestLng,
        type: 'restaurant',
        radius: 3000,
      );
      final context = tripDestName != null
          ? 'Para sua viagem: $tripDestName'
          : 'Para sua próxima viagem';

      for (final r in _sortByRating(tripPlaces).take(2)) {
        recommendations.add(_parse(
          r, tripDestLat, tripDestLng,
          'restaurant', 'Restaurante',
          RecommendationReason.tripBased,
          tripContext: context,
        ));
      }
    }

    return recommendations;
  }

  /// Busca empresas da categoria num raio definido, filtrando por nota mínima
  /// do Google. Resultados ordenados por rating (desc), depois por nº de reviews.
  ///
  /// - [minRating]: nota mínima (padrão 3.5). Use 0 para não filtrar.
  /// - [radiusMeters]: raio de busca em metros (padrão 8000m = 8km).
  static Future<List<PlaceRecommendation>> getTrustedBusinesses({
    required double lat,
    required double lng,
    required BusinessCategory category,
    double minRating = 3.5,
    int radiusMeters = 8000,
  }) async {
    final raw = await _search(
      lat: lat,
      lng: lng,
      type: category.googleType,
      keyword: category.keyword,
      radius: radiusMeters,
    );

    final filtered = raw.where((p) {
      final r = (p['rating'] as num?)?.toDouble() ?? 0;
      return r >= minRating;
    }).toList();

    filtered.sort((a, b) {
      final rA = (a['rating'] as num?)?.toDouble() ?? 0;
      final rB = (b['rating'] as num?)?.toDouble() ?? 0;
      if (rA != rB) return rB.compareTo(rA);
      final cA = (a['user_ratings_total'] as num?)?.toInt() ?? 0;
      final cB = (b['user_ratings_total'] as num?)?.toInt() ?? 0;
      return cB.compareTo(cA);
    });

    return filtered
        .map((p) => _parse(
              p,
              lat,
              lng,
              category.googleType ?? 'business',
              category.label,
              RecommendationReason.trustedBusiness,
            ))
        .toList();
  }

  /// Busca livre de lugares por texto via Google Places Text Search.
  /// Quando [lat]/[lng] são informados, prioriza resultados próximos
  /// (dentro do [radiusMeters]). Sem coordenadas, faz busca global.
  ///
  /// Usado pela tela de busca para o usuário digitar coisas como
  /// "mirante", "cachoeira", "praia" e ver lugares reais para iniciar
  /// rolê / viagem ou abrir no Google Maps.
  static Future<List<PlaceRecommendation>> searchPlaces({
    required String query,
    double? lat,
    double? lng,
    int radiusMeters = 50000,
    int limit = 12,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final params = <String, String>{
        'query': trimmed,
        'language': 'pt-BR',
      };
      if (lat != null && lng != null) {
        params['location'] = '$lat,$lng';
        params['radius'] = radiusMeters.toString();
      }

      final url = MapsProxy.uri('place/textsearch/json', params);
      final res = await _client
          .get(url, headers: MapsProxy.headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') return [];

      final results = List<Map<String, dynamic>>.from(
          (data['results'] as List?) ?? []);

      // Origem usada para calcular distância (lat/lng do dispositivo se houver,
      // senão a coordenada do próprio resultado — distância vira 0 nesse caso).
      final originLat = lat ?? 0;
      final originLng = lng ?? 0;

      final parsed = results.take(limit).map((r) {
        // Quando não temos a localização do usuário, usa a do próprio lugar
        // como origem para evitar números absurdos no label de distância.
        if (lat == null || lng == null) {
          final geo =
              (r['geometry'] as Map<String, dynamic>)['location']
                  as Map<String, dynamic>;
          final pLat = (geo['lat'] as num).toDouble();
          final pLng = (geo['lng'] as num).toDouble();
          return _parse(
            r,
            pLat,
            pLng,
            'place',
            'Lugar',
            RecommendationReason.trustedBusiness,
          );
        }
        return _parse(
          r,
          originLat,
          originLng,
          'place',
          'Lugar',
          RecommendationReason.trustedBusiness,
        );
      }).toList();

      return parsed;
    } catch (_) {
      return [];
    }
  }
}
