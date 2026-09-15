import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/features/active_session/screens/active_map_screen.dart';

/// O avatar do rider no mapa precisa encolher quando o mapa afasta — senão o
/// marcador tapa o próprio mapa — e crescer quando aproxima.
void main() {
  group('iconSizeForZoom', () {
    test('mapa bem afastado usa o menor tamanho', () {
      expect(markerSizeForZoom(3), 40);
      expect(markerSizeForZoom(10), 40);
    });

    test('mapa bem aproximado usa o maior tamanho', () {
      expect(markerSizeForZoom(17), 110);
      expect(markerSizeForZoom(21), 110);
    });

    test('cresce de forma monotônica com o zoom', () {
      var anterior = 0;
      for (var z = 0.0; z <= 21; z += 0.5) {
        final atual = markerSizeForZoom(z);
        expect(atual, greaterThanOrEqualTo(anterior));
        anterior = atual;
      }
    });

    test('fica sempre dentro dos limites', () {
      for (var z = -5.0; z <= 30; z += 0.5) {
        final s = markerSizeForZoom(z);
        expect(s, inInclusiveRange(40, 110));
      }
    });

    test('é quantizado em degraus de 10px (evita regerar a cada frame)', () {
      for (var z = 0.0; z <= 21; z += 0.25) {
        expect(markerSizeForZoom(z) % 10, 0);
      }
    });

    test('zoom intermediário fica entre os extremos', () {
      final meio = markerSizeForZoom(13.5);
      expect(meio, greaterThan(40));
      expect(meio, lessThan(110));
    });
  });
}
