import 'location_model.dart';

class StopModel {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String category;
  final LocationModel location;
  final double? rating;

  const StopModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.category,
    required this.location,
    this.rating,
  });
}
