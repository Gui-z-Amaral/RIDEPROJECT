class UserModel {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final String? motoModel;
  final String? motoYear;
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
    this.motoModel,
    this.motoYear,
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
    String? motoModel,
    String? motoYear,
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
      motoModel: motoModel ?? this.motoModel,
      motoYear: motoYear ?? this.motoYear,
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
        'moto_model': motoModel,
        'moto_year': motoYear,
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
        motoModel: map['moto_model'],
        motoYear: map['moto_year'],
        photos: List<String>.from(map['photos'] ?? []),
        friendsCount: map['friends_count'] ?? 0,
        tripsCount: map['trips_count'] ?? 0,
        isOnline: map['is_online'] ?? false,
      );
}
