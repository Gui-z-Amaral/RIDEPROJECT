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
  final String accountType; // 'personal' | 'business'

  // ── Campos do perfil empresa ───────────────────────────────
  // Mantidos separados dos campos pessoais (name, bio) para que alternar
  // account_type não sobrescreva os dois conjuntos.
  final String? businessName;
  final String? businessDescription;
  final String? businessBannerUrl;
  final String? businessAddressStreet;
  final String? businessAddressNumber;
  final String? businessAddressNeighborhood;
  final String? businessAddressCity;
  final String? businessAddressState;
  final List<String> businessCategories;

  final List<String> photos;
  final int friendsCount;
  final int tripsCount;
  final int ridesCount;
  final bool isOnline;
  final bool discoverable; // aparece na descoberta de riders próximos
  final bool isPrivate; // perfil privado (não-amigo vê só o básico)
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
    this.accountType = 'personal',
    this.businessName,
    this.businessDescription,
    this.businessBannerUrl,
    this.businessAddressStreet,
    this.businessAddressNumber,
    this.businessAddressNeighborhood,
    this.businessAddressCity,
    this.businessAddressState,
    this.businessCategories = const [],
    this.photos = const [],
    this.friendsCount = 0,
    this.tripsCount = 0,
    this.ridesCount = 0,
    this.isOnline = false,
    this.discoverable = true,
    this.isPrivate = false,
    this.createdAt,
  });

  /// `true` quando o perfil é do tipo empresa (pode criar eventos).
  bool get isBusiness => accountType == 'business';

  /// Nome de exibição: usa businessName quando o perfil é empresa e o campo
  /// está preenchido; caso contrário cai pro nome pessoal.
  String get displayName {
    if (isBusiness && (businessName?.isNotEmpty ?? false)) return businessName!;
    return name;
  }

  UserModel copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    String? bio,
    String? city,
    String? motoModel,
    String? motoYear,
    String? tripStyle,
    String? accountType,
    String? businessName,
    String? businessDescription,
    String? businessBannerUrl,
    String? businessAddressStreet,
    String? businessAddressNumber,
    String? businessAddressNeighborhood,
    String? businessAddressCity,
    String? businessAddressState,
    List<String>? businessCategories,
    List<String>? photos,
    int? friendsCount,
    int? tripsCount,
    int? ridesCount,
    bool? isOnline,
    bool? discoverable,
    bool? isPrivate,
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
      accountType: accountType ?? this.accountType,
      businessName: businessName ?? this.businessName,
      businessDescription: businessDescription ?? this.businessDescription,
      businessBannerUrl: businessBannerUrl ?? this.businessBannerUrl,
      businessAddressStreet: businessAddressStreet ?? this.businessAddressStreet,
      businessAddressNumber: businessAddressNumber ?? this.businessAddressNumber,
      businessAddressNeighborhood:
          businessAddressNeighborhood ?? this.businessAddressNeighborhood,
      businessAddressCity: businessAddressCity ?? this.businessAddressCity,
      businessAddressState: businessAddressState ?? this.businessAddressState,
      businessCategories: businessCategories ?? this.businessCategories,
      photos: photos ?? this.photos,
      friendsCount: friendsCount ?? this.friendsCount,
      tripsCount: tripsCount ?? this.tripsCount,
      ridesCount: ridesCount ?? this.ridesCount,
      isOnline: isOnline ?? this.isOnline,
      discoverable: discoverable ?? this.discoverable,
      isPrivate: isPrivate ?? this.isPrivate,
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
        'account_type': accountType,
        'business_name': businessName,
        'business_description': businessDescription,
        'business_banner_url': businessBannerUrl,
        'business_address_street': businessAddressStreet,
        'business_address_number': businessAddressNumber,
        'business_address_neighborhood': businessAddressNeighborhood,
        'business_address_city': businessAddressCity,
        'business_address_state': businessAddressState,
        'business_categories': businessCategories,
        'photos': photos,
        'friends_count': friendsCount,
        'trips_count': tripsCount,
        'rides_count': ridesCount,
        'is_online': isOnline,
        'discoverable': discoverable,
        'is_private': isPrivate,
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
      accountType: map['account_type'] as String? ?? 'personal',
      businessName: map['business_name'] as String?,
      businessDescription: map['business_description'] as String?,
      businessBannerUrl: map['business_banner_url'] as String?,
      businessAddressStreet: map['business_address_street'] as String?,
      businessAddressNumber: map['business_address_number'] as String?,
      businessAddressNeighborhood:
          map['business_address_neighborhood'] as String?,
      businessAddressCity: map['business_address_city'] as String?,
      businessAddressState: map['business_address_state'] as String?,
      businessCategories:
          List<String>.from(map['business_categories'] as List? ?? []),
      photos: List<String>.from(map['photos'] as List? ?? []),
      friendsCount: (map['friends_count'] as num?)?.toInt() ?? 0,
      tripsCount: (map['trips_count'] as num?)?.toInt() ?? 0,
      ridesCount: (map['rides_count'] as num?)?.toInt() ?? 0,
      isOnline: map['is_online'] as bool? ?? false,
      discoverable: map['discoverable'] as bool? ?? true,
      isPrivate: map['is_private'] as bool? ?? false,
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt)
          : rawCreatedAt as DateTime?,
    );
  }
}
