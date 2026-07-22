/// Um banner predefinido para o perfil PESSOAL (contas empresa usam upload
/// livre — ver EditBusinessProfileScreen). Imagem bundlada como asset do app
/// (assets/images/banners/) — leve e fácil de estender quando novos banners
/// forem adicionados.
///
/// [isPremium] já vem pronto para quando a monetização for ativada: hoje
/// nenhum banner é bloqueado, mas o catálogo já carrega a informação.
class ProfileBannerPreset {
  final String id;
  final String label;
  final String assetPath;
  final bool isPremium;
  const ProfileBannerPreset({
    required this.id,
    required this.label,
    required this.assetPath,
    this.isPremium = false,
  });
}

const List<ProfileBannerPreset> profileBannerPresets = [
  ProfileBannerPreset(
    id: 'cherry_blossom',
    label: 'Cerejeira',
    assetPath: 'assets/images/banners/cherry_blossom.jpg',
  ),
  ProfileBannerPreset(
    id: 'cyber',
    label: 'Cibernético',
    assetPath: 'assets/images/banners/cyber.jpg',
  ),
  ProfileBannerPreset(
    id: 'motorcycles',
    label: 'Motos',
    assetPath: 'assets/images/banners/motorcycles.jpg',
  ),
  ProfileBannerPreset(
    id: 'skulls',
    label: 'Caveiras',
    assetPath: 'assets/images/banners/skulls.jpg',
  ),
];

/// Busca um preset pelo id; `null` se não encontrar (ex: valor salvo é uma
/// URL de upload de empresa, não um preset).
ProfileBannerPreset? profileBannerPresetById(String? id) {
  if (id == null) return null;
  for (final p in profileBannerPresets) {
    if (p.id == id) return p;
  }
  return null;
}

/// `true` se [value] parece ser uma URL de upload (empresa), não um id de
/// preset (pessoal).
bool isBannerUrl(String? value) =>
    value != null &&
    (value.startsWith('http://') || value.startsWith('https://'));
