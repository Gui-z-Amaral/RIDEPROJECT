// Testes de RideModel + RideHistoryEntry.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/location_model.dart';
import 'package:ride_app/core/models/ride_model.dart';
import 'package:ride_app/core/models/user_model.dart';

RideModel _makeRide({RideStatus status = RideStatus.scheduled}) {
  return RideModel(
    id: 'r-1',
    title: 'Rolê de domingo',
    meetingPoint: const LocationModel(lat: -27.5, lng: -48.5),
    creator: const UserModel(id: 'u', name: 'x', username: 'x'),
    status: status,
    createdAt: DateTime(2025, 1, 1),
  );
}

void main() {
  group('RideModel.statusLabel', () {
    test('rótulos em português para cada status', () {
      expect(_makeRide(status: RideStatus.scheduled).statusLabel, 'Agendado');
      expect(
          _makeRide(status: RideStatus.waiting).statusLabel, 'Aguardando');
      expect(
          _makeRide(status: RideStatus.active).statusLabel, 'Em andamento');
      expect(
          _makeRide(status: RideStatus.completed).statusLabel, 'Concluído');
      expect(
          _makeRide(status: RideStatus.cancelled).statusLabel, 'Cancelado');
    });

    test('cobre todos os status do enum', () {
      for (final s in RideStatus.values) {
        expect(_makeRide(status: s).statusLabel, isNotEmpty,
            reason: 'Status $s sem label no switch');
      }
    });
  });

  group('RideModel.buildGoogleMapsUrl', () {
    test('monta URL com origin e destination por coordenadas', () {
      final r = _makeRide();
      const origin = LocationModel(lat: -27.0, lng: -48.0);
      final url = r.buildGoogleMapsUrl(origin);

      expect(url, startsWith('https://www.google.com/maps/dir/?api=1'));
      expect(url, contains('origin=-27.0,-48.0'));
      expect(url, contains('destination=-27.5,-48.5'));
      expect(url, contains('travelmode=driving'));
    });
  });

  group('RideHistoryEntry.isActive', () {
    test('considera ativa somente se leftAt é null e status ativo/waiting',
        () {
      final now = DateTime.now();
      final active = RideHistoryEntry(
        rideId: 'r',
        title: 't',
        meetingName: 'mp',
        status: RideStatus.active,
        createdAt: now,
      );
      expect(active.isActive, isTrue);

      final leftAlready = RideHistoryEntry(
        rideId: 'r',
        title: 't',
        meetingName: 'mp',
        status: RideStatus.active,
        createdAt: now,
        leftAt: now,
      );
      expect(leftAlready.isActive, isFalse);

      final completed = RideHistoryEntry(
        rideId: 'r',
        title: 't',
        meetingName: 'mp',
        status: RideStatus.completed,
        createdAt: now,
      );
      expect(completed.isActive, isFalse);
    });
  });

  group('RideHistoryEntry.duration/durationLabel', () {
    test('null quando ainda não saiu', () {
      final r = RideHistoryEntry(
        rideId: 'r',
        title: 't',
        meetingName: 'mp',
        status: RideStatus.active,
        createdAt: DateTime(2025),
      );
      expect(r.duration, isNull);
      expect(r.durationLabel, '');
    });

    test('calcula a partir de startedAt quando disponível', () {
      final start = DateTime(2025, 1, 1, 10, 0);
      final left = DateTime(2025, 1, 1, 12, 30);
      final r = RideHistoryEntry(
        rideId: 'r',
        title: 't',
        meetingName: 'mp',
        status: RideStatus.completed,
        createdAt: start.subtract(const Duration(hours: 1)),
        startedAt: start,
        leftAt: left,
      );
      expect(r.duration, const Duration(hours: 2, minutes: 30));
      expect(r.durationLabel, '2h 30min');
    });

    test('cai para joinedAt quando startedAt é null', () {
      final joined = DateTime(2025, 1, 1, 10, 0);
      final left = DateTime(2025, 1, 1, 10, 45);
      final r = RideHistoryEntry(
        rideId: 'r',
        title: 't',
        meetingName: 'mp',
        status: RideStatus.completed,
        createdAt: joined.subtract(const Duration(hours: 1)),
        joinedAt: joined,
        leftAt: left,
      );
      expect(r.durationLabel, '45min');
    });

    test('formata só minutos quando < 1h', () {
      final joined = DateTime(2025, 1, 1, 10, 0);
      final left = joined.add(const Duration(minutes: 20));
      final r = RideHistoryEntry(
        rideId: 'r',
        title: 't',
        meetingName: 'mp',
        status: RideStatus.completed,
        createdAt: joined,
        joinedAt: joined,
        leftAt: left,
      );
      expect(r.durationLabel, '20min');
    });
  });
}
