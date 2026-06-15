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

    test('ride_invite e trip_invite abrem a aba de Convites (aceitar/recusar)', () {
      expect(routeForNotification('ride_invite', {'rideId': 'rd'}),
          '/friends/invites');
      expect(routeForNotification('trip_invite', {'tripId': 'tp'}),
          '/friends/invites');
      expect(routeForNotification('ride_invite', {}), '/friends/invites');
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

  group('shouldShowForegroundNotification', () {
    test('suprime mensagem de quem o usuário já está conversando', () {
      expect(
        shouldShowForegroundNotification(
          type: 'message',
          payload: {'fromUserId': 'u-1'},
          activeChatUserId: 'u-1',
        ),
        isFalse,
      );
    });

    test('exibe mensagem de OUTRA pessoa', () {
      expect(
        shouldShowForegroundNotification(
          type: 'message',
          payload: {'fromUserId': 'u-2'},
          activeChatUserId: 'u-1',
        ),
        isTrue,
      );
    });

    test('exibe mensagem quando não está em nenhum chat', () {
      expect(
        shouldShowForegroundNotification(
          type: 'message',
          payload: {'fromUserId': 'u-1'},
          activeChatUserId: null,
        ),
        isTrue,
      );
    });

    test('outros tipos sempre exibem, mesmo com chat aberto', () {
      expect(
        shouldShowForegroundNotification(
          type: 'event_update',
          payload: {'eventId': 'e-1'},
          activeChatUserId: 'u-1',
        ),
        isTrue,
      );
      expect(
        shouldShowForegroundNotification(
          type: 'friend_request',
          payload: {},
          activeChatUserId: 'u-1',
        ),
        isTrue,
      );
    });

    test('fromUserId vazio ou ausente não suprime', () {
      expect(
        shouldShowForegroundNotification(
          type: 'message',
          payload: {'fromUserId': ''},
          activeChatUserId: 'u-1',
        ),
        isTrue,
      );
      expect(
        shouldShowForegroundNotification(
          type: 'message',
          payload: {},
          activeChatUserId: 'u-1',
        ),
        isTrue,
      );
    });
  });
}
