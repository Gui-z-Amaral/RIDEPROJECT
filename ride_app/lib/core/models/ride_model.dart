import 'user_model.dart';
import 'location_model.dart';

enum RideStatus { scheduled, waiting, active, completed, cancelled }

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
