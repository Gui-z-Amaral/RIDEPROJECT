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
    case 'friend_request':
      return '/friends/invites';
    case 'ride_invite':
      final id = str('rideId');
      return id != null ? '/rides/$id' : '/rides';
    case 'trip_invite':
      final id = str('tripId');
      return id != null ? '/trips/$id' : '/trips';
    case 'event_update':
      final id = str('eventId');
      return id != null ? '/events/$id' : '/notifications';
    default:
      return '/notifications';
  }
}
