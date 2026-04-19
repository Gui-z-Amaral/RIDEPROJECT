import 'user_model.dart';
import 'location_model.dart';

enum RideStatus { scheduled, waiting, active, completed, cancelled }

class RideHistoryEntry {
  final String rideId;
  final String title;
  final String meetingName;
  final RideStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  const RideHistoryEntry({
    required this.rideId,
    required this.title,
    required this.meetingName,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.joinedAt,
    this.leftAt,
  });

  bool get isActive =>
      leftAt == null &&
      (status == RideStatus.active || status == RideStatus.waiting);

  Duration? get duration {
    if (leftAt == null) return null;
    final start = startedAt ?? joinedAt ?? createdAt;
    return leftAt!.difference(start);
  }

  String get durationLabel {
    final d = duration;
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }
}

class RideModel {
  final String id;
  final String title;
  final LocationModel meetingPoint;
  final List<UserModel> participants;
  final UserModel creator;
  final RideStatus status;
  final DateTime? scheduledAt;
  final bool isImmediate;
  final DateTime createdAt;
  final DateTime? startedAt;

  const RideModel({
    required this.id,
    required this.title,
    required this.meetingPoint,
    this.participants = const [],
    required this.creator,
    this.status = RideStatus.scheduled,
    this.scheduledAt,
    this.isImmediate = false,
    required this.createdAt,
    this.startedAt,
  });

  String buildGoogleMapsUrl(LocationModel origin) {
    return 'https://www.google.com/maps/dir/?api=1&origin=${origin.lat},${origin.lng}&destination=${meetingPoint.lat},${meetingPoint.lng}&travelmode=driving';
  }

  String get statusLabel {
    switch (status) {
      case RideStatus.scheduled:
        return 'Agendado';
      case RideStatus.waiting:
        return 'Aguardando';
      case RideStatus.active:
        return 'Em andamento';
      case RideStatus.completed:
        return 'Concluído';
      case RideStatus.cancelled:
        return 'Cancelado';
    }
  }

  RideModel copyWith({
    String? title,
    LocationModel? meetingPoint,
    List<UserModel>? participants,
    RideStatus? status,
    DateTime? scheduledAt,
  }) {
    return RideModel(
      id: id,
      title: title ?? this.title,
      meetingPoint: meetingPoint ?? this.meetingPoint,
      participants: participants ?? this.participants,
      creator: creator,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isImmediate: isImmediate,
      createdAt: createdAt,
    );
  }
}
