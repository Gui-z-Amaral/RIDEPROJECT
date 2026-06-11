// Testes do mapeamento notificação → rota usado ao tocar num push.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/utils/notification_router.dart';

void main() {
  group('routeForNotification', () {
    test('message com fromUserId abre o chat daquela pessoa', () {
      expect(
        routeForNotification('message', {'fromUserId': 'u-9', 'fromName': 'Ana'}),
        '/friends/chat/u-9',
      );
    });

    test('message sem fromUserId cai para /notifications', () {
      expect(routeForNotification('message', {}), '/notifications');
    });

    test('friend_request vai para a tela de convites', () {
      expect(
        routeForNotification('friend_request', {'requestId': 'r1'}),
        '/friends/invites',
      );
    });

    test('event_update com eventId abre o evento', () {
      expect(
        routeForNotification('event_update', {'eventId': 'e-1'}),
        '/events/e-1',
      );
    });

    test('event_update sem eventId cai para /notifications', () {
      expect(routeForNotification('event_update', {}), '/notifications');
    });

    test('ride_invite usa rideId quando presente, senão lista', () {
      expect(routeForNotification('ride_invite', {'rideId': 'rd'}), '/rides/rd');
      expect(routeForNotification('ride_invite', {}), '/rides');
    });

    test('trip_invite usa tripId quando presente, senão lista', () {
      expect(routeForNotification('trip_invite', {'tripId': 'tp'}), '/trips/tp');
      expect(routeForNotification('trip_invite', {}), '/trips');
    });

    test('tipo desconhecido ou nulo cai para /notifications', () {
      expect(routeForNotification('qualquer_coisa', {}), '/notifications');
      expect(routeForNotification(null, {}), '/notifications');
    });

    test('id vazio é tratado como ausente', () {
      expect(routeForNotification('event_update', {'eventId': ''}),
          '/notifications');
      expect(routeForNotification('message', {'fromUserId': ''}),
          '/notifications');
    });

    test('valor não-string no id não quebra (cai para fallback)', () {
      expect(routeForNotification('event_update', {'eventId': 123}),
          '/notifications');
    });
  });
}
