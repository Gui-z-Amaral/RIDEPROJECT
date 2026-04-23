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

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        username: map['username'] ?? '',
        avatarUrl: map['avatar_url'],
        bio: map['bio'],
        city: map['city'],
        motoModel: map['moto_model'],
        motoYear: map['moto_year'],
        tripStyle: map['trip_style'],
        photos: List<String>.from(map['photos'] ?? []),
        friendsCount: map['friends_count'] ?? 0,
        tripsCount: map['trips_count'] ?? 0,
        isOnline: map['is_online'] ?? false,
      );
}
