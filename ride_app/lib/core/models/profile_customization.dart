/// Personalização visual do perfil (banner, moldura do avatar, cores).
/// Uma linha por usuário; visível também para quem visita o perfil.
class ProfileCustomization {
  final String userId;
  final String? bannerUrl;
  final String avatarFrame; // id do catálogo — ver avatar_frames.dart
  final String? backgroundColor; // id da paleta — null = padrão do app
  final String? textColor; // id da paleta — null = padrão do app

  const ProfileCustomization({
    required this.userId,
    this.bannerUrl,
    this.avatarFrame = 'none',
    this.backgroundColor,
    this.textColor,
  });

  /// Personalização vazia (ninguém customizou ainda) — usada como fallback
  /// quando a linha não existe no banco.
  factory ProfileCustomization.empty(String userId) =>
      ProfileCustomization(userId: userId);

  bool get isDefault =>
      bannerUrl == null &&
      avatarFrame == 'none' &&
      backgroundColor == null &&
      textColor == null;

  ProfileCustomization copyWith({
    Object? bannerUrl = _unset,
    String? avatarFrame,
    Object? backgroundColor = _unset,
    Object? textColor = _unset,
  }) {
    return ProfileCustomization(
      userId: userId,
      bannerUrl: bannerUrl == _unset ? this.bannerUrl : bannerUrl as String?,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      backgroundColor: backgroundColor == _unset
          ? this.backgroundColor
          : backgroundColor as String?,
      textColor: textColor == _unset ? this.textColor : textColor as String?,
    );
  }

  static const _unset = Object();

  factory ProfileCustomization.fromMap(Map<String, dynamic> map) {
    return ProfileCustomization(
      userId: map['user_id'] as String? ?? '',
      bannerUrl: map['banner_url'] as String?,
      avatarFrame: map['avatar_frame'] as String? ?? 'none',
      backgroundColor: map['background_color'] as String?,
      textColor: map['text_color'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'banner_url': bannerUrl,
        'avatar_frame': avatarFrame,
        'background_color': backgroundColor,
        'text_color': textColor,
      };
}
