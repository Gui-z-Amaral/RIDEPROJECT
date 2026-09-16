import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/location_model.dart';
import 'maps_proxy.dart';

/// Rota **por estrada** entre dois pontos (Google Directions), com paradas
/// intermediárias opcionais.
///
/// Existe porque o mapa desenhava uma **linha reta** entre origem e destino: o
/// widget de mapa só liga os pontos que recebe, então alguém precisa buscar a
/// polyline de verdade.
///
/// Passa pelo [MapsProxy], como toda chamada de Maps do app.
class DirectionsService {
  DirectionsService._();

  // Cliente injetável — em testes pode ser um MockClient.
  static http.Client _client = http.Client();

  @visibleForTesting
  static void debugSetClient(http.Client client) => _client = client;

  @visibleForTesting
  static void debugResetClient() => _client = http.Client();

  /// Pontos da rota por estrada, na ordem.
  ///
  /// Devolve lista **vazia** quando a rota não pode ser traçada (sem internet,
  /// sem rota possível, cota estourada). O chamador decide o fallback — no
  /// detalhe da viagem, ligar os pontos direto.
  static Future<List<LocationModel>> route({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<LocationModel> waypoints = const [],
  }) async {
    try {
      final params = <String, String>{
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'mode': 'driving',
        'language': 'pt-BR',
      };
      if (waypoints.isNotEmpty) {
        // "via:" faz a rota PASSAR pelo ponto sem tratá-lo como parada com
        // manobra — é o que queremos para desenhar o traçado.
        params['waypoints'] =
            waypoints.map((w) => 'via:${w.lat},${w.lng}').join('|');
      }

      final res = await _client
          .get(MapsProxy.uri('directions/json', params),
              headers: MapsProxy.headers)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return [];
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [];

      final overview = (routes.first as Map<String, dynamic>)
          ['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) return [];

      return decodePolyline(encoded);
    } catch (_) {
      return [];
    }
  }

  /// Decodifica a *encoded polyline* do Google (formato público: deltas em
  /// base64 de 5 bits, com sinal em complemento).
  ///
  /// Pura e testável — é a parte que costuma quebrar silenciosamente.
  @visibleForTesting
  static List<LocationModel> decodePolyline(String encoded) {
    final points = <LocationModel>[];
    var index = 0;
    final len = encoded.length;
    var lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        // Polyline truncada ou inválida: devolve o que já deu para decodificar
        // em vez de estourar — o mapa fica sem traçado, não quebra a tela.
        if (index >= len) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        if (index >= len) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LocationModel(lat: lat / 1e5, lng: lng / 1e5));
    }
    return points;
  }
}
