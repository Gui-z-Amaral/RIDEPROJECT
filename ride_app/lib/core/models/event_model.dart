import 'user_model.dart';
import '../utils/db_time.dart';

/// Patrocinador/apoiador do evento (texto livre + logo opcional).
class EventSponsor {
  final String? id;
  final int position;
  final String name;
  final String? logoUrl;

  const EventSponsor({
    this.id,
    this.position = 0,
    required this.name,
    this.logoUrl,
  });

  factory EventSponsor.fromMap(Map<String, dynamic> map) => EventSponsor(
        id: map['id'] as String?,
        position: (map['position'] as num?)?.toInt() ?? 0,
        name: map['name'] as String? ?? '',
        logoUrl: map['logo_url'] as String?,
      );

  Map<String, dynamic> toInsertMap(String eventId) => {
        'event_id': eventId,
        'position': position,
        'name': name,
        'logo_url': logoUrl,
      };
}

/// Um item da programação do evento (ex: "14:00 — Abertura dos portões").
class EventScheduleItem {
  final String? id;
  final int position;
  final String? timeLabel; // texto livre, ex: '14:00'
  final String title;
  final String? description;

  const EventScheduleItem({
    this.id,
    this.position = 0,
    this.timeLabel,
    required this.title,
    this.description,
  });

  factory EventScheduleItem.fromMap(Map<String, dynamic> map) =>
      EventScheduleItem(
        id: map['id'] as String?,
        position: (map['position'] as num?)?.toInt() ?? 0,
        timeLabel: map['time_label'] as String?,
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
      );

  /// Payload pra inserir em event_schedule_items (sem id; event_id é setado
  /// pelo serviço). Mantém a ordem via [position].
  Map<String, dynamic> toInsertMap(String eventId) => {
        'event_id': eventId,
        'position': position,
        'time_label': timeLabel,
        'title': title,
        'description': description,
      };
}

class EventModel {
  final String id;
  final String creatorId;
  final UserModel? creator;
  final String title;
  final String? description;
  final String? bannerUrl;
  final double? lat;
  final double? lng;
  final String? address;
  final String? locationLabel;
  final String? stateUf;
  final String? city;
  final String? clubId; // != null = evento de motoclube
  final DateTime startsAt;
  final DateTime? endsAt;
  final int interestsCount;
  final List<EventScheduleItem> schedule;
  final List<EventSponsor> sponsors;
  final List<UserModel> participants;

  /// `true` quando o usuário logado marcou interesse. Preenchido sob demanda
  /// (no detalhe ou quando carregamos o set de interesses do usuário).
  final bool isInterested;

  const EventModel({
    required this.id,
    required this.creatorId,
    this.creator,
    required this.title,
    this.description,
    this.bannerUrl,
    this.lat,
    this.lng,
    this.address,
    this.locationLabel,
    this.stateUf,
    this.city,
    this.clubId,
    required this.startsAt,
    this.endsAt,
    this.interestsCount = 0,
    this.schedule = const [],
    this.sponsors = const [],
    this.participants = const [],
    this.isInterested = false,
  });

  bool get hasLocation => lat != null && lng != null;

  String get googleMapsUrl {
    if (hasLocation) {
      return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }
    final q = Uri.encodeComponent(address ?? locationLabel ?? title);
    return 'https://www.google.com/maps/search/?api=1&query=$q';
  }

  EventModel copyWith({
    int? interestsCount,
    bool? isInterested,
    List<EventScheduleItem>? schedule,
    List<EventSponsor>? sponsors,
    List<UserModel>? participants,
    UserModel? creator,
  }) {
    return EventModel(
      id: id,
      creatorId: creatorId,
      creator: creator ?? this.creator,
      title: title,
      description: description,
      bannerUrl: bannerUrl,
      lat: lat,
      lng: lng,
      address: address,
      locationLabel: locationLabel,
      stateUf: stateUf,
      city: city,
      startsAt: startsAt,
      endsAt: endsAt,
      interestsCount: interestsCount ?? this.interestsCount,
      schedule: schedule ?? this.schedule,
      sponsors: sponsors ?? this.sponsors,
      participants: participants ?? this.participants,
      isInterested: isInterested ?? this.isInterested,
    );
  }

  factory EventModel.fromMap(
    Map<String, dynamic> map, {
    bool isInterested = false,
  }) {
    final creatorRow = map['creator'] as Map<String, dynamic>?;
    final scheduleRows =
        (map['schedule'] as List? ?? []).cast<Map<String, dynamic>>();
    final items = scheduleRows
        .map(EventScheduleItem.fromMap)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final sponsorRows =
        (map['sponsors'] as List? ?? []).cast<Map<String, dynamic>>();
    final sponsorList = sponsorRows
        .map(EventSponsor.fromMap)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    // participants vem como [{user: {...profile}}]
    final participantRows =
        (map['participants'] as List? ?? []).cast<Map<String, dynamic>>();
    final participantList = participantRows
        .map((p) => UserModel.fromMap(
            (p['user'] as Map<String, dynamic>?) ?? const {}))
        .where((u) => u.id.isNotEmpty)
        .toList();

    return EventModel(
      id: map['id'] as String,
      creatorId: map['creator_id'] as String,
      creator: creatorRow != null ? UserModel.fromMap(creatorRow) : null,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      bannerUrl: map['banner_url'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      address: map['address'] as String?,
      locationLabel: map['location_label'] as String?,
      stateUf: map['state_uf'] as String?,
      city: map['city'] as String?,
      clubId: map['club_id'] as String?,
      startsAt: DbTime.parse(map['starts_at']),
      endsAt: map['ends_at'] != null
          ? DbTime.tryParse(map['ends_at'])
          : null,
      interestsCount: (map['interests_count'] as num?)?.toInt() ?? 0,
      schedule: items,
      sponsors: sponsorList,
      participants: participantList,
      isInterested: isInterested,
    );
  }
}
