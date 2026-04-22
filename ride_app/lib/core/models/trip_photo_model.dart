import 'user_model.dart';

class TripPhotoModel {
  final String id;
  final String tripId;
  final String uploadedBy;
  final String photoUrl;
  final DateTime createdAt;

  const TripPhotoModel({
    required this.id,
    required this.tripId,
    required this.uploadedBy,
    required this.photoUrl,
    required this.createdAt,
  });

  factory TripPhotoModel.fromRow(Map<String, dynamic> r) => TripPhotoModel(
        id: r['id'] as String,
        tripId: r['trip_id'] as String,
        uploadedBy: r['uploaded_by'] as String,
        photoUrl: r['photo_url'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
      );
}

/// Foto destacada de um amigo (válida por 7 dias).
class FeaturedPhotoModel {
  final UserModel user;
  final String photoUrl;
  final String? tripId;
  final DateTime featuredAt;
  final DateTime expiresAt;

  const FeaturedPhotoModel({
    required this.user,
    required this.photoUrl,
    this.tripId,
    required this.featuredAt,
    required this.expiresAt,
  });
}
