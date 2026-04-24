// Testes de TripModel — statusLabel e buildGoogleMapsUrl.
//
// buildGoogleMapsUrl é o que gera o deep link que o usuário usa pra
// navegar no Google Maps. Se quebra, o botão "Ver rota no Maps"
// abre um link vazio ou inválido.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/location_model.dart';
import 'package:ride_app/core/models/trip_model.dart';
import 'package:ride_app/core/models/user_model.dart';

// Helper pra criar TripModels com defaults razoáveis — mantém os
// testes focados na propriedade sob teste.
TripModel _makeTrip({
  TripStatus status = TripStatus.planned,
  LocationModel? origin,
  LocationModel? destination,
  List<LocationModel> waypoints = const [],
}) {
  return TripModel(
    id: 't-1',
    title: 'Teste',
    origin: origin ??
        const LocationModel(lat: -27.5954, lng: -48.5480, label: 'Floripa'),
    destination: destination ??
        const LocationModel(lat: -25.4284, lng: -49.2733, label: 'Curitiba'),
    waypoints: waypoints,
    creator: const UserModel(id: 'u-1', name: 'x', username: 'x'),
    status: status,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('TripModel.statusLabel', () {
    test('retorna rótulo em português para cada status', () {
      expect(_makeTrip(status: TripStatus.planned).statusLabel, 'Planejada');
      expect(_makeTrip(status: TripStatus.active).statusLabel, 'Em andamento');
      expect(
          _makeTrip(status: TripStatus.completed).statusLabel, 'Concluída');
      expect(
          _makeTrip(status: TripStatus.cancelled).statusLabel, 'Cancelada');
    });

    test('cobre todos os status do enum', () {
      for (final s in TripStatus.values) {
        expect(_makeTrip(status: s).statusLabel, isNotEmpty,
            reason: 'Status $s sem label no switch');
      }
    });
  });

  group('TripModel.buildGoogleMapsUrl', () {
    test('URL básica tem destination e travelmode driving', () {
      final url = _makeTrip().buildGoogleMapsUrl();
      expect(url, startsWith('https://www.google.com/maps/dir/?api=1'));
      expect(url, contains('&destination='));
      expect(url, contains('&travelmode=driving'));
    });

    test('usa o label do destino (quando houver) no parâmetro destination',
        () {
      final url = _makeTrip(
        destination: const LocationModel(
            lat: -25.4, lng: -49.2, label: 'Praça Tiradentes'),
      ).buildGoogleMapsUrl();
      // Uri.encodeQueryComponent codifica espaço como '+' (form-urlencoded)
      // e acentos como %xx — ambos são aceitos pelo Google Maps.
      expect(url, contains('destination=Pra%C3%A7a+Tiradentes'));
    });

    test('cai para lat,lng quando destino não tem label', () {
      final url = _makeTrip(
        destination: const LocationModel(lat: -25.4284, lng: -49.2733),
      ).buildGoogleMapsUrl();
      expect(url, contains('destination=-25.4284,-49.2733'));
    });

    test('trata label com apenas espaços como ausente (cai para lat,lng)',
        () {
      final url = _makeTrip(
        destination: const LocationModel(
            lat: -25.4, lng: -49.2, label: '   '),
      ).buildGoogleMapsUrl();
      expect(url, contains('destination=-25.4,-49.2'));
    });

    test('sem waypoints não adiciona o parâmetro waypoints', () {
      final url = _makeTrip().buildGoogleMapsUrl();
      expect(url, isNot(contains('&waypoints=')));
    });

    test('com waypoints adiciona o parâmetro separado por %7C', () {
      final url = _makeTrip(
        waypoints: const [
          LocationModel(lat: -27.0, lng: -48.5, label: 'Joinville'),
          LocationModel(lat: -26.3, lng: -48.8, label: 'Blumenau'),
        ],
      ).buildGoogleMapsUrl();
      expect(url, contains('&waypoints='));
      expect(url, contains('%7C')); // separador entre waypoints
      expect(url, contains('Joinville'));
      expect(url, contains('Blumenau'));
    });
  });
}
