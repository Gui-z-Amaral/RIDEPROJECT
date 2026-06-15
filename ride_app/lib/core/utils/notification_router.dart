/// Decide se uma notificação push recebida com o app em PRIMEIRO PLANO deve
/// ser exibida. Suprime mensagens de chat quando o usuário já está na conversa
/// com aquela mesma pessoa ([activeChatUserId]); qualquer outro caso (outra
/// pessoa, outra tela, outros tipos) é exibido normalmente.
bool shouldShowForegroundNotification({
  required String? type,
  required Map<String, dynamic> payload,
  required String? activeChatUserId,
}) {
  if (type == 'message') {
    final from = payload['fromUserId'];
    if (from is String && from.isNotEmpty && from == activeChatUserId) {
      return false;
    }
  }
  return true;
}

/// Mapeia uma notificação (type + payload) para a rota que deve abrir quando
/// o usuário toca no push. Função pura — sem dependência de Firebase/UI — para
/// poder ser testada isoladamente.
///
/// [type] é o `notifications.type` (ex: 'message', 'event_update').
/// [payload] é o `notifications.data` já desserializado.
String routeForNotification(String? type, Map<String, dynamic> payload) {
  String? str(String key) {
    final v = payload[key];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  switch (type) {
    case 'message':
      final id = str('fromUserId');
      return id != null ? '/friends/chat/$id' : '/notifications';
    // Convites (amizade, rolê, viagem) abrem a aba de Convites, onde o
    // usuário aceita/recusa — nunca a tela de início.
    case 'friend_request':
    case 'ride_invite':
    case 'trip_invite':
      return '/friends/invites';
    case 'event_update':
      final id = str('eventId');
      return id != null ? '/events/$id' : '/notifications';
    default:
      return '/notifications';
  }
}
