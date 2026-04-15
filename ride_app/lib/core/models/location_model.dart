class LocationModel {
  final double lat;
  final double lng;
  final String? address;
  final String? label;

  const LocationModel({
    required this.lat,
    required this.lng,
    this.address,
    this.label,
  });

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'address': address,
        'label': label,
      };

  factory LocationModel.fromMap(Map<String, dynamic> map) => LocationModel(
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        address: map['address'],
        label: map['label'],
      );
}
