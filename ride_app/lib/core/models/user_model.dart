class UserModel {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? motoModel;
  final String? motoYear;
  final String? tripStyle;
  final List<String> photos;
  final int friendsCount;
  final int tripsCount;
  final bool isOnline;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.city,
    this.motoModel,
    this.motoYear,
    this.tripStyle,
    this.photos = const [],
    this.friendsCount = 0,
    this.tripsCount = 0,
    this.isOnline = false,
    this.createdAt,
  });

  UserModel copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    String? bio,
    String? city,
    String? motoModel,
    String? motoYear,
    String? tripStyle,
    List<String>? photos,
    int? friendsCount,
    int? tripsCount,
    bool? isOnline,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      city: city ?? this.city,
      motoModel: motoModel ?? this.motoModel,
      motoYear: motoYear ?? this.motoYear,
      tripStyle: tripStyle ?? this.tripStyle,
      photos: photos ?? this.photos,
      friendsCount: friendsCount ?? this.friendsCount,
      tripsCount: tripsCount ?? this.tripsCount,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'avatar_url': avatarUrl,
        'bio': bio,
        'city': city,
        'moto_model': motoModel,
        'moto_year': motoYear,
        'trip_style': tripStyle,
        'photos': photos,
        'friends_count': friendsCount,
        'trips_count': tripsCount,
        'is_online': isOnline,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['created_at'];
    return UserModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      city: map['city'] as String?,
      motoModel: map['moto_model'] as String?,
      motoYear: map['moto_year'] as String?,
      tripStyle: map['trip_style'] as String?,
      photos: List<String>.from(map['photos'] as List? ?? []),
      friendsCount: (map['friends_count'] as num?)?.toInt() ?? 0,
      tripsCount: (map['trips_count'] as num?)?.toInt() ?? 0,
      isOnline: map['is_online'] as bool? ?? false,
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt)
          : rawCreatedAt as DateTime?,
    );
  }
}
