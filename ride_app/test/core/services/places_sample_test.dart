import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/services/places_service.dart';

/// Amostragem dos pontos usados para procurar paradas "no caminho" entre a
/// origem e o destino da viagem.
void main() {
  group('PlacesService.sampleBetween', () {
    test('devolve um ponto por fração, na ordem', () {
      final pts = PlacesService.sampleBetween(0, 0, 4, 8);
      expect(pts.length, 3); // 25%, 50%, 75% por padrão
      expect(pts[0].lat, closeTo(1, 1e-9));
      expect(pts[0].lng, closeTo(2, 1e-9));
      expect(pts[1].lat, closeTo(2, 1e-9));
      expect(pts[1].lng, closeTo(4, 1e-9));
      expect(pts[2].lat, closeTo(3, 1e-9));
      expect(pts[2].lng, closeTo(6, 1e-9));
    });

    test('os pontos ficam ENTRE origem e destino, nunca fora', () {
      final pts = PlacesService.sampleBetween(-27.6, -48.5, -29.0, -51.2);
      for (final p in pts) {
        expect(p.lat, lessThan(-27.6));
        expect(p.lat, greaterThan(-29.0));
        expect(p.lng, lessThan(-48.5));
        expect(p.lng, greaterThan(-51.2));
      }
    });

    test('respeita frações customizadas', () {
      final pts = PlacesService.sampleBetween(0, 0, 10, 10,
          fractions: const [0.5]);
      expect(pts.length, 1);
      expect(pts.single.lat, closeTo(5, 1e-9));
    });

    test('origem igual ao destino devolve o mesmo ponto (não quebra)', () {
      final pts = PlacesService.sampleBetween(-27.6, -48.5, -27.6, -48.5);
      for (final p in pts) {
        expect(p.lat, closeTo(-27.6, 1e-9));
        expect(p.lng, closeTo(-48.5, 1e-9));
      }
    });

    test('funciona com rota no sentido inverso (destino "antes" da origem)', () {
      final pts = PlacesService.sampleBetween(10, 10, 0, 0);
      expect(pts.first.lat, closeTo(7.5, 1e-9));
      expect(pts.last.lat, closeTo(2.5, 1e-9));
    });
  });
}
