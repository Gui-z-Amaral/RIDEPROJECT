import '../utils/db_time.dart';

/// Os três formatos de convite de motoclube (migration 038).
enum ClubInviteKind { permanent, single, temporary }

extension ClubInviteKindX on ClubInviteKind {
  /// Valor gravado no banco.
  String get code => switch (this) {
        ClubInviteKind.permanent => 'permanent',
        ClubInviteKind.single => 'single',
        ClubInviteKind.temporary => 'temporary',
      };

  String get label => switch (this) {
        ClubInviteKind.permanent => 'Link permanente',
        ClubInviteKind.single => 'Convite individual',
        ClubInviteKind.temporary => 'Expira em 1 hora',
      };

  String get hint => switch (this) {
        ClubInviteKind.permanent =>
          'Vale para sempre. Bom para a bio do clube — dá para revogar quando quiser.',
        ClubInviteKind.single =>
          'Entra uma pessoa só. O link queima no primeiro uso.',
        ClubInviteKind.temporary =>
          'Para um encontro pontual. Depois de uma hora para de funcionar.',
      };

  static ClubInviteKind? fromCode(String? code) => switch (code) {
        'permanent' => ClubInviteKind.permanent,
        'single' => ClubInviteKind.single,
        'temporary' => ClubInviteKind.temporary,
        _ => null,
      };
}

/// Situação de um convite, decidida **no servidor**. Conferir no app seria
/// teatro: bastaria chamar o endpoint direto.
enum ClubInviteStatus { valido, expirado, usado, revogado, invalido }

ClubInviteStatus clubInviteStatusFrom(String? s) => switch (s) {
      'valido' => ClubInviteStatus.valido,
      'expirado' => ClubInviteStatus.expirado,
      'usado' => ClubInviteStatus.usado,
      'revogado' => ClubInviteStatus.revogado,
      _ => ClubInviteStatus.invalido,
    };

/// O que a tela de "você foi convidado" mostra antes de a pessoa entrar.
///
/// Só traz o que já é público no perfil do clube — nunca a lista de membros
/// nem quem criou o convite.
class ClubInvitePreview {
  final String? clubId;
  final String? name;
  final String? avatarUrl;
  final String? city;
  final String? stateUf;
  final int members;
  final ClubInviteStatus status;

  const ClubInvitePreview({
    this.clubId,
    this.name,
    this.avatarUrl,
    this.city,
    this.stateUf,
    this.members = 0,
    this.status = ClubInviteStatus.invalido,
  });

  bool get isValid => status == ClubInviteStatus.valido && clubId != null;

  /// "Araranguá - SC", ou vazio.
  String get place =>
      [city, stateUf].where((s) => s != null && s.isNotEmpty).join(' - ');

  factory ClubInvitePreview.fromMap(Map<String, dynamic> m) =>
      ClubInvitePreview(
        clubId: m['club_id'] as String?,
        name: m['name'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        city: m['city'] as String?,
        stateUf: m['state_uf'] as String?,
        members: (m['members'] as num?)?.toInt() ?? 0,
        status: clubInviteStatusFrom(m['status'] as String?),
      );
}

/// Um convite na lista do administrador.
class ClubInvite {
  final String token;
  final ClubInviteKind kind;
  final DateTime? expiresAt;
  final DateTime? usedAt;
  final DateTime? createdAt;

  const ClubInvite({
    required this.token,
    required this.kind,
    this.expiresAt,
    this.usedAt,
    this.createdAt,
  });

  /// `true` quando o link já não serve para mais ninguém.
  bool get isSpent =>
      usedAt != null ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  factory ClubInvite.fromMap(Map<String, dynamic> m) => ClubInvite(
        token: m['token'] as String? ?? '',
        kind: ClubInviteKindX.fromCode(m['kind'] as String?) ??
            ClubInviteKind.permanent,
        expiresAt: DbTime.tryParse(m['expires_at']),
        usedAt: DbTime.tryParse(m['used_at']),
        createdAt: DbTime.tryParse(m['created_at']),
      );
}
