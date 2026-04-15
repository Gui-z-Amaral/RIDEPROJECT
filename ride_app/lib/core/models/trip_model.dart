import 'user_model.dart';
import 'location_model.dart';
import 'stop_model.dart';

enum TripStatus { planned, active, completed, cancelled }
enum RouteType { scenic, gastronomic, shortest, safest, none }

class TripModel {
  final String id;
  final String title;
  final String? description;
  final LocationModel origin;
  final LocationModel destination;
  final List<LocationModel> waypoints;
  final List<StopModel> stops;
  final List<UserModel> participants;
  final UserModel creator;
  final TripStatus status;
  final RouteType routeType;
  final DateTime? scheduledAt;
  final double? estimatedDistance;
  final String? estimatedDuration;
  final String? coverImage;
  final DateTime createdAt;

  const TripModel({
    required this.id,
    required this.title,
    this.description,
    required this.origin,
    required this.destination,
    this.waypoints = const [],
    this.stops = const [],
    this.participants = const [],
    required this.creator,
    this.status = TripStatus.planned,
    this.routeType = RouteType.none,
    this.scheduledAt,
    this.estimatedDistance,
    this.estimatedDuration,
    this.coverImage,
    required this.createdAt,
  });

  String get routeTypeLabel {
    switch (routeType) {
      case RouteType.scenic:
        return 'Panorâmica';
      case RouteType.gastronomic:
        return 'Gastronômica';
      case RouteType.shortest:
        return 'Mais Curta';
      case RouteType.safest:
        return 'Mais Segura';
      case RouteType.none:
        return 'Nenhuma';
    }
  }

  String get statusLabel {
    switch (status) {
      case TripStatus.planned:
        return 'Planejada';
      case TripStatus.active:
        return 'Em andamento';
      case TripStatus.completed:
        return 'Concluída';
      case TripStatus.cancelled:
        return 'Cancelada';
    }
  }

  String buildGoogleMapsUrl() {
    final points = [origin, ...waypoints, destination];
    final waypts = points.skip(1).take(points.length - 2).toList();
    final dest = points.last;
    final orig = points.first;

    String url =
        'https://www.google.com/maps/dir/?api=1&origin=${orig.lat},${orig.lng}&destination=${dest.lat},${dest.lng}';
    if (waypts.isNotEmpty) {
      final wStr = waypts.map((w) => '${w.lat},${w.lng}').join('%7C');
      url += '&waypoints=$wStr';
    }
    url += '&travelmode=driving';
    return url;
  }

  TripModel copyWith({
    String? title,
    String? description,
    LocationModel? origin,
    LocationModel? destination,
    List<LocationModel>? waypoints,
    List<StopModel>? stops,
    List<UserModel>? participants,
    TripStatus? status,
    RouteType? routeType,
    DateTime? scheduledAt,
    double? estimatedDistance,
    String? estimatedDuration,
    String? coverImage,
  }) {
    return TripModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      waypoints: waypoints ?? this.waypoints,
      stops: stops ?? this.stops,
      participants: participants ?? this.participants,
      creator: creator,
      status: status ?? this.status,
      routeType: routeType ?? this.routeType,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      coverImage: coverImage ?? this.coverImage,
      createdAt: createdAt,
    );
  }
}
