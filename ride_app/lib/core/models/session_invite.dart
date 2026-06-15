/// Convite pendente para um rolê ou viagem (participação com status 'waiting').
/// Usado na aba de Convites para o usuário aceitar/recusar.
class SessionInvite {
  final String sessionId;
  final String title;
  final bool isRide; // true = rolê, false = viagem
  final DateTime? scheduledAt;

  const SessionInvite({
    required this.sessionId,
    required this.title,
    required this.isRide,
    this.scheduledAt,
  });
}
