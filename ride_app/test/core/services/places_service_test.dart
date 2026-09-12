// Testes do PlacesService:
//
// 1. BusinessCategoryX: mapeamento enum → (label, googleType, keyword).
//    Protege contra alguém adicionar uma categoria no enum e esquecer
//    de estender os switches.
//
// 2. PlaceRecommendation: getters puros (photoUrl, googleMapsUrl,
//    distanceLabel) — formatos consumidos pela UI direto.
//
// 3. searchPlaces: integração com Google Places Text Search via
//    MockClient. Cobre query vazia, ZERO_RESULTS, OK com resultados,
//    parametrização de location/radius e tratamento de erro de rede.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ride_app/core/services/places_service.dart';

void main() {
  group('BusinessCategoryX.label', () {
    test('retorna o rótulo em português para cada categoria', () {
      expect(BusinessCategory.gasStation.label, 'Postos');
      expect(BusinessCategory.mechanic.label, 'Oficinas');
      expect(BusinessCategory.tireShop.label, 'Borracharias');
      expect(BusinessCategory.carWash.label, 'Lava-rápido');
    });

    test('cobre todas as categorias do enum', () {
      for (final c in BusinessCategory.values) {
        expect(c.label, isNotEmpty,
            reason: 'Categoria $c está sem label — atualize o switch');
      }
    });
  });

  group('BusinessCategoryX.googleType', () {
    test('mapeia para o type oficial do Google Places quando existe', () {
      expect(BusinessCategory.gasStation.googleType, 'gas_station');
      expect(BusinessCategory.mechanic.googleType, 'car_repair');
      expect(BusinessCategory.carWash.googleType, 'car_wash');
    });

    test('tireShop fica sem type (usa keyword porque Google não tem)', () {
      expect(BusinessCategory.tireShop.googleType, isNull);
    });
  });

  group('BusinessCategoryX.keyword', () {
    test('tireShop usa "borracharia" como keyword de busca', () {
      expect(BusinessCategory.tireShop.keyword, 'borracharia');
    });

    test('categorias com googleType próprio não precisam de keyword', () {
      expect(BusinessCategory.gasStation.keyword, isNull);
      expect(BusinessCategory.mechanic.keyword, isNull);
      expect(BusinessCategory.carWash.keyword, isNull);
    });

    test('pelo menos um entre googleType ou keyword sempre está preenchido',
        () {
      // Invariante: uma query precisa de pelo menos um filtro, senão pega
      // qualquer lugar próximo — teste protege contra adicionar categoria
      // sem filtro nenhum.
      for (final c in BusinessCategory.values) {
        final hasFilter = c.googleType != null || c.keyword != null;
        expect(hasFilter, isTrue,
            reason: 'Categoria $c não tem googleType nem keyword');
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // PlaceRecommendation — getters puros consumidos direto pela UI.
  // ───────────────────────────────────────────────────────────────────────

  group('PlaceRecommendation.photoUrl', () {
    test('vazio quando photoRef é null', () {
      const p = PlaceRecommendation(
        placeId: 'p',
        name: 'X',
        vicinity: 'Y',
        type: 'place',
        typeLabel: 'Lugar',
        lat: 0,
        lng: 0,
        distanceKm: 0,
        isOpenNow: true,
        reason: RecommendationReason.trustedBusiness,
      );
      expect(p.photoUrl, '');
    });

    test('vazio quando photoRef é string vazia', () {
      const p = PlaceRecommendation(
        placeId: 'p',
        name: 'X',
        vicinity: 'Y',
        photoRef: '',
        type: 'place',
        typeLabel: 'Lugar',
        lat: 0,
        lng: 0,
        distanceKm: 0,
        isOpenNow: true,
        reason: RecommendationReason.trustedBusiness,
      );
      expect(p.photoUrl, '');
    });

    test('quando photoRef preenchido, monta URL com endpoint, ref e key', () {
      const p = PlaceRecommendation(
        placeId: 'p',
        name: 'X',
        vicinity: 'Y',
        photoRef: 'CmRaAAAA-XYZ',
        type: 'place',
        typeLabel: 'Lugar',
        lat: 0,
        lng: 0,
        distanceKm: 0,
        isOpenNow: true,
        reason: RecommendationReason.trustedBusiness,
      );
      // Foto vai direto ao Google (<img> não sofre CORS).
      expect(p.photoUrl, contains('place/photo'));
      expect(p.photoUrl, contains('photo_reference=CmRaAAAA-XYZ'));
      expect(p.photoUrl, contains('maxwidth=400'));
      expect(p.photoUrl, contains('key='));
    });
  });

  group('PlaceRecommendation.googleMapsUrl', () {
    test('codifica nome com query encode e inclui place_id', () {
      const p = PlaceRecommendation(
        placeId: 'PLACE_123',
        name: 'Mirante do Morro',
        vicinity: 'Floripa',
        type: 'place',
        typeLabel: 'Lugar',
        lat: -27.5,
        lng: -48.5,
        distanceKm: 0,
        isOpenNow: true,
        reason: RecommendationReason.trustedBusiness,
      );
      expect(p.googleMapsUrl, startsWith('https://www.google.com/maps/'));
      // Espaços viram '+' (form-urlencoded), acentos viram %xx.
      expect(p.googleMapsUrl, contains('Mirante+do+Morro'));
      expect(p.googleMapsUrl, contains('query_place_id=PLACE_123'));
    });
  });

  group('PlaceRecommendation.distanceLabel', () {
    test('< 1 km usa metros arredondados', () {
      const p = PlaceRecommendation(
        placeId: 'p',
        name: 'X',
        vicinity: 'Y',
        type: 'place',
        typeLabel: 'Lugar',
        lat: 0,
        lng: 0,
        distanceKm: 0.247,
        isOpenNow: true,
        reason: RecommendationReason.trustedBusiness,
      );
      expect(p.distanceLabel, '247m');
    });

    test('>= 1 km usa quilômetros com 1 casa decimal', () {
      const p = PlaceRecommendation(
        placeId: 'p',
        name: 'X',
        vicinity: 'Y',
        type: 'place',
        typeLabel: 'Lugar',
        lat: 0,
        lng: 0,
        distanceKm: 12.345,
        isOpenNow: true,
        reason: RecommendationReason.trustedBusiness,
      );
      expect(p.distanceLabel, '12.3km');
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // searchPlaces — busca livre via Google Places Text Search.
  // Usa MockClient pra simular respostas do Google sem bater na rede.
  // ───────────────────────────────────────────────────────────────────────

  group('PlacesService.searchPlaces', () {
    tearDown(() {
      // Restaura o cliente HTTP default depois de cada teste.
      PlacesService.debugResetClient();
    });

    test('query vazia (ou só espaços) retorna lista vazia sem chamar HTTP',
        () async {
      var called = false;
      PlacesService.debugSetClient(MockClient((req) async {
        called = true;
        return http.Response('', 200);
      }));

      expect(await PlacesService.searchPlaces(query: ''), isEmpty);
      expect(await PlacesService.searchPlaces(query: '   '), isEmpty);
      expect(called, isFalse,
          reason: 'searchPlaces não deve chamar HTTP com query vazia');
    });

    test('parseia resposta OK do Google Places em PlaceRecommendation', () async {
      PlacesService.debugSetClient(MockClient((req) async {
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'results': [
              {
                'place_id': 'PLACE_1',
                'name': 'Mirante do Morro da Cruz',
                'formatted_address': 'Florianópolis, SC',
                'rating': 4.7,
                'user_ratings_total': 1234,
                'geometry': {
                  'location': {'lat': -27.59, 'lng': -48.55}
                },
                'opening_hours': {'open_now': true},
                'photos': [
                  {'photo_reference': 'PHOTO_REF_X'}
                ],
              },
            ],
          }),
          200,
        );
      }));

      final results = await PlacesService.searchPlaces(
        query: 'mirante',
        lat: -27.5,
        lng: -48.5,
      );

      expect(results, hasLength(1));
      final p = results.first;
      expect(p.placeId, 'PLACE_1');
      expect(p.name, 'Mirante do Morro da Cruz');
      // Text Search devolve formatted_address — _parse usa como fallback de vicinity.
      expect(p.vicinity, 'Florianópolis, SC');
      expect(p.rating, 4.7);
      expect(p.userRatingsTotal, 1234);
      expect(p.lat, -27.59);
      expect(p.lng, -48.55);
      expect(p.isOpenNow, isTrue);
      expect(p.photoRef, 'PHOTO_REF_X');
      expect(p.reason, RecommendationReason.trustedBusiness);
    });

    test('inclui location e radius nos query params quando há coordenadas',
        () async {
      Uri? capturedUrl;
      PlacesService.debugSetClient(MockClient((req) async {
        capturedUrl = req.url;
        return http.Response('{"status":"OK","results":[]}', 200);
      }));

      await PlacesService.searchPlaces(
        query: 'mirante',
        lat: -27.5,
        lng: -48.5,
        radiusMeters: 30000,
      );

      expect(capturedUrl, isNotNull);
      expect(capturedUrl!.queryParameters['query'], 'mirante');
      expect(capturedUrl!.queryParameters['location'], '-27.5,-48.5');
      expect(capturedUrl!.queryParameters['radius'], '30000');
      expect(capturedUrl!.queryParameters['language'], 'pt-BR');
    });

    test('omite location e radius quando coordenadas não são informadas',
        () async {
      Uri? capturedUrl;
      PlacesService.debugSetClient(MockClient((req) async {
        capturedUrl = req.url;
        return http.Response('{"status":"OK","results":[]}', 200);
      }));

      await PlacesService.searchPlaces(query: 'mirante');

      expect(capturedUrl, isNotNull);
      expect(capturedUrl!.queryParameters.containsKey('location'), isFalse);
      expect(capturedUrl!.queryParameters.containsKey('radius'), isFalse);
    });

    test('ZERO_RESULTS retorna lista vazia (sem erro)', () async {
      PlacesService.debugSetClient(MockClient((req) async {
        return http.Response(
          '{"status":"ZERO_RESULTS","results":[]}',
          200,
        );
      }));
      final results = await PlacesService.searchPlaces(query: 'algoraro');
      expect(results, isEmpty);
    });

    test('status diferente de OK/ZERO_RESULTS retorna lista vazia', () async {
      PlacesService.debugSetClient(MockClient((req) async {
        return http.Response(
          '{"status":"REQUEST_DENIED","results":[]}',
          200,
        );
      }));
      final results = await PlacesService.searchPlaces(query: 'x');
      expect(results, isEmpty);
    });

    test('HTTP != 200 retorna lista vazia', () async {
      PlacesService.debugSetClient(MockClient((req) async {
        return http.Response('Server Error', 500);
      }));
      final results = await PlacesService.searchPlaces(query: 'x');
      expect(results, isEmpty);
    });

    test('exceção de rede é tratada e retorna lista vazia', () async {
      PlacesService.debugSetClient(MockClient((req) async {
        throw http.ClientException('connection refused');
      }));
      final results = await PlacesService.searchPlaces(query: 'x');
      expect(results, isEmpty);
    });

    test('respeita o limite de resultados', () async {
      PlacesService.debugSetClient(MockClient((req) async {
        // Simula 20 resultados; limit deve cortar em N.
        final fakeResults = List.generate(
          20,
          (i) => {
            'place_id': 'P_$i',
            'name': 'Lugar $i',
            'formatted_address': 'X',
            'geometry': {
              'location': {'lat': 0.0, 'lng': 0.0}
            },
          },
        );
        return http.Response(
          jsonEncode({'status': 'OK', 'results': fakeResults}),
          200,
        );
      }));

      final all = await PlacesService.searchPlaces(query: 'x', limit: 5);
      expect(all, hasLength(5));
      expect(all.first.placeId, 'P_0');
    });

    test('quando lat/lng são null, distância é calculada como 0 (referência = lugar)',
        () async {
      // Sem localização do dispositivo, _parse usa as coordenadas do próprio
      // lugar como origem — distância vira 0 e a UI esconde o label de km.
      PlacesService.debugSetClient(MockClient((req) async {
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'results': [
              {
                'place_id': 'P',
                'name': 'X',
                'geometry': {
                  'location': {'lat': -27.0, 'lng': -48.0}
                },
              },
            ],
          }),
          200,
        );
      }));
      final results = await PlacesService.searchPlaces(query: 'x');
      expect(results, hasLength(1));
      expect(results.first.distanceKm, 0.0);
    });
  });
}
