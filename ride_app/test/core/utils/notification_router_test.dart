import 'dart:convert';
// Testes do mapeamento notificação → rota usado ao tocar num push.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/utils/notification_router.dart';

void main() {
  _testesDaRotaDePush();
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

/// Formato da URL que o service worker monta ao tocar na notificação
/// (`/n?t=<type>&p=<payload>`), e que a rota /n desmonta para chamar
/// [routeForNotification].
///
/// O mapeamento vive só no Dart de propósito: tê-lo também em JavaScript
/// garantiria que um dia os dois discordassem, e o sintoma seria o push abrir
/// a tela errada — exatamente o que acontecia quando o worker abria sempre '/'.
void _testesDaRotaDePush() {
  group('ida e volta do payload do push', () {
    /// Reproduz o que o service worker faz ao montar a URL.
    String montarUrl(String type, String payloadJson) =>
        '/n?t=${Uri.encodeQueryComponent(type)}'
        '&p=${Uri.encodeQueryComponent(payloadJson)}';

    /// Reproduz o que a rota /n faz ao receber.
    String resolver(String url) {
      final q = Uri.parse(url).queryParameters;
      final raw = q['p'] ?? '{}';
      Map<String, dynamic> payload = const {};
      try {
        final d = jsonDecode(raw);
        if (d is Map) payload = Map<String, dynamic>.from(d);
      } catch (_) {}
      return routeForNotification(q['t'] ?? '', payload);
    }

    test('mensagem chega na conversa certa', () {
      final url = montarUrl('message', '{"fromUserId":"u-123"}');
      expect(resolver(url), '/friends/chat/u-123');
    });

    test('evento chega no evento certo', () {
      final url = montarUrl('event_update', '{"eventId":"e-9"}');
      expect(resolver(url), '/events/e-9');
    });

    test('convite chega na aba de convites', () {
      expect(resolver(montarUrl('friend_request', '{}')), '/friends/invites');
      expect(resolver(montarUrl('trip_invite', '{}')), '/friends/invites');
    });

    test('payload corrompido cai na lista, sem estourar', () {
      // O que não pode acontecer é a tela ficar branca porque o JSON veio
      // truncado na URL.
      expect(resolver('/n?t=message&p=%7Bquebrado'), '/notifications');
    });

    test('sem type nenhum cai na lista', () {
      expect(resolver('/n?t=&p=%7B%7D'), '/notifications');
    });

    test('caracteres especiais sobrevivem à ida e volta', () {
      final url = montarUrl('event_update', '{"eventId":"a b&c=d"}');
      expect(resolver(url), '/events/a b&c=d');
    });
  });
}
