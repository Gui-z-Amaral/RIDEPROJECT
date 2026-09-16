
/// O que dá para compartilhar por link.
enum ShareKind { event, trip, ride }

extension ShareKindX on ShareKind {
  /// Segmento usado na URL curta (`/e/<id>`, `/v/<id>`, `/r/<id>`).
  String get path => switch (this) {
        ShareKind.event => 'e',
        ShareKind.trip => 'v',
        ShareKind.ride => 'r',
      };

  String get label => switch (this) {
        ShareKind.event => 'Evento',
        ShareKind.trip => 'Viagem',
        ShareKind.ride => 'Rolê',
      };

  static ShareKind? fromPath(String segment) => switch (segment) {
        'e' => ShareKind.event,
        'v' => ShareKind.trip,
        'r' => ShareKind.ride,
        _ => null,
      };
}

/// Versão **pública** de um evento, viagem ou rolê: o que um visitante sem
/// login pode ver ao abrir um link compartilhado.
///
/// Existe separado dos models completos de propósito. Evento é público por
/// natureza — existe para atrair gente — e mostra tudo. Viagem e rolê mostram
/// só o essencial: num app de moto, publicar o ponto de partida e o horário de
/// alguém é risco de segurança, e o link circula em grupo de WhatsApp sem
/// ninguém controlar para onde vai.
class SharePreview {
  final ShareKind kind;
  final String id;
  final String title;

  /// Banner do evento / capa da viagem. Nulo cai na arte padrão do app.
  final String? imageUrl;

  final DateTime? startsAt;

  /// Evento: local completo. Viagem/rolê: **só a cidade** — nunca o endereço,
  /// as coordenadas, as paradas ou a rota.
  final String? placeLabel;

  /// Só evento. Viagem e rolê não expõem descrição.
  final String? description;

  final String? organizerName;
  final String? organizerAvatar;

  const SharePreview({
    required this.kind,
    required this.id,
    required this.title,
    this.imageUrl,
    this.startsAt,
    this.placeLabel,
    this.description,
    this.organizerName,
    this.organizerAvatar,
  });

  /// Cidade de um endereço do Google, sem o resto.
  ///
  /// O formato é "Rua X, 848 - Bairro, Florianópolis - SC, 88000-000, Brasil";
  /// pegamos o trecho "Cidade - UF". Serve para mostrar a região sem entregar o
  /// ponto exato. Devolve `null` quando não dá para identificar — melhor não
  /// mostrar nada do que mostrar a rua por engano.
  static String? cityFromAddress(String? address) {
    if (address == null || address.trim().isEmpty) return null;
    final re = RegExp(r'^(.+?)\s*-\s*([A-Z]{2})$');
    for (final part in address.split(',')) {
      final m = re.firstMatch(part.trim());
      if (m == null) continue;
      final city = m.group(1)!.trim();
      if (city.isNotEmpty) return '$city - ${m.group(2)}';
    }
    return null;
  }
}
