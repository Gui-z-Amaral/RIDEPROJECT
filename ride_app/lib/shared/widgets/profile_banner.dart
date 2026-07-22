import 'package:flutter/material.dart';
import '../../core/constants/profile_banners.dart';

/// Renderiza o banner do perfil a partir do valor salvo em
/// `profile_customizations.banner_url`: se for uma URL (conta empresa,
/// upload livre) mostra a imagem de rede; se for um id de preset (conta
/// pessoal) mostra o asset correspondente. `null`/desconhecido não desenha
/// nada (o chamador decide se mostra um placeholder).
class ProfileBannerView extends StatelessWidget {
  final String? value;
  final double height;
  final BorderRadius? borderRadius;

  const ProfileBannerView({
    super.key,
    required this.value,
    this.height = 130,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (isBannerUrl(value)) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Image.network(
          value!,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    final preset = profileBannerPresetById(value);
    if (preset == null) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.asset(
        preset.assetPath,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}
