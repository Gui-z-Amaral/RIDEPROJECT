import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/directions_service.dart';

/// A rota no mapa vem como uma *encoded polyline* do Google. Se a decodificação
/// estiver errada, o traçado simplesmente sai torto — sem erro nenhum. Daí os
/// testes usarem o exemplo oficial da documentação do formato.
void main() {
  group('decodePolyline', () {
    test('decodifica o exemplo oficial do Google', () {
      // `_p~iF~ps|U_ulLnnqC_mqNvxq`@` → (38.5,-120.2) (40.7,-120.95) (43.252,-126.453)
      final pts = DirectionsService.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts.length, 3);
      expect(pts[0].lat, closeTo(38.5, 1e-5));
      expect(pts[0].lng, closeTo(-120.2, 1e-5));
      expect(pts[1].lat, closeTo(40.7, 1e-5));
      expect(pts[1].lng, closeTo(-120.95, 1e-5));
      expect(pts[2].lat, closeTo(43.252, 1e-5));
      expect(pts[2].lng, closeTo(-126.453, 1e-5));
    });

    test('mantém a ordem dos pontos (o traçado depende disso)', () {
      final pts = DirectionsService.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts.first.lat, lessThan(pts.last.lat));
    });

    test('string vazia devolve lista vazia', () {
      expect(DirectionsService.decodePolyline(''), isEmpty);
    });

    test('lixo não lança exceção (o mapa só fica sem traçado)', () {
      expect(() => DirectionsService.decodePolyline('####'), returnsNormally);
      expect(() => DirectionsService.decodePolyline('abc'), returnsNormally);
    });

    test('coordenadas ficam em faixas válidas', () {
      final pts = DirectionsService.decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      for (final p in pts) {
        expect(p.lat, inInclusiveRange(-90, 90));
        expect(p.lng, inInclusiveRange(-180, 180));
      }
    });
  });
}
