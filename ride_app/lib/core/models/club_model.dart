import 'user_model.dart';

/// Motoclube. Os campos `myRole`/`myStatus` descrevem a relação do usuário
/// logado com o clube (quando conhecida): role = owner|admin|member,
/// status = active|invited|null (null = não tem relação).
class ClubModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? city;
  final String? stateUf;
  final bool eventsPublic; // true = eventos do clube visíveis a todos
  final DateTime? createdAt;
  final int membersCount;
  final String? myRole;
  final String? myStatus;

  const ClubModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.avatarUrl,
    this.bannerUrl,
    this.city,
    this.stateUf,
    this.eventsPublic = false,
    this.createdAt,
    this.membersCount = 0,
    this.myRole,
    this.myStatus,
  });

  bool get isActiveMember => myStatus == 'active';
  bool get isAdmin => isActiveMember && (myRole == 'owner' || myRole == 'admin');
  bool get isOwner => isActiveMember && myRole == 'owner';
  bool get isPendingInvite => myStatus == 'invited';

  String get location {
    if ((city ?? '').isNotEmpty && (stateUf ?? '').isNotEmpty) {
      return '$city, $stateUf';
    }
    return city ?? stateUf ?? '';
  }

  ClubModel copyWith({int? membersCount, String? myRole, String? myStatus}) =>
      ClubModel(
        id: id,
        ownerId: ownerId,
        name: name,
        description: description,
        avatarUrl: avatarUrl,
        bannerUrl: bannerUrl,
        city: city,
        stateUf: stateUf,
        eventsPublic: eventsPublic,
        createdAt: createdAt,
        membersCount: membersCount ?? this.membersCount,
        myRole: myRole ?? this.myRole,
        myStatus: myStatus ?? this.myStatus,
      );

  factory ClubModel.fromMap(
    Map<String, dynamic> map, {
    int? membersCount,
    String? myRole,
    String? myStatus,
  }) {
    return ClubModel(
      id: map['id'] as String? ?? '',
      ownerId: map['owner_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      bannerUrl: map['banner_url'] as String?,
      city: map['city'] as String?,
      stateUf: map['state_uf'] as String?,
      eventsPublic: map['events_public'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      membersCount: membersCount ?? (map['members_count'] as num?)?.toInt() ?? 0,
      myRole: myRole,
      myStatus: myStatus,
    );
  }
}

/// Uma entrada da lista de presença (evento ou viagem do clube).
class AttendanceEntry {
  final UserModel? user;
  final String userId;
  final String rsvp; // going|maybe|declined
  final bool checkedIn;

  const AttendanceEntry({
    required this.userId,
    required this.rsvp,
    required this.checkedIn,
    this.user,
  });

  factory AttendanceEntry.fromMap(Map<String, dynamic> map) {
    final userMap = map['user'] as Map<String, dynamic>?;
    return AttendanceEntry(
      userId: map['user_id'] as String? ?? '',
      rsvp: map['rsvp'] as String? ?? 'going',
      checkedIn: map['checked_in'] as bool? ?? false,
      user: userMap != null ? UserModel.fromMap(userMap) : null,
    );
  }
}

/// Membro de um motoclube (com o perfil aninhado quando carregado).
class ClubMemberModel {
  final String clubId;
  final String userId;
  final String role; // owner|admin|member
  final String status; // active|invited
  final DateTime? joinedAt;
  final UserModel? user;

  const ClubMemberModel({
    required this.clubId,
    required this.userId,
    required this.role,
    required this.status,
    this.joinedAt,
    this.user,
  });

  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get isOwner => role == 'owner';

  factory ClubMemberModel.fromMap(Map<String, dynamic> map) {
    final userMap = map['user'] as Map<String, dynamic>?;
    return ClubMemberModel(
      clubId: map['club_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      role: map['role'] as String? ?? 'member',
      status: map['status'] as String? ?? 'active',
      joinedAt: map['joined_at'] != null
          ? DateTime.tryParse(map['joined_at'] as String)
          : null,
      user: userMap != null ? UserModel.fromMap(userMap) : null,
    );
  }
}
