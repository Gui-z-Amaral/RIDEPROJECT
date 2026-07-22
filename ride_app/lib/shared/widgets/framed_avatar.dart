import 'package:flutter/material.dart';
import '../../core/constants/profile_appearance.dart';
import 'app_avatar.dart';

/// [AppAvatar] com a moldura de personalização de perfil desenhada ao redor
/// (anel sólido ou gradiente, conforme [AvatarFrameStyle]). Sem moldura
/// ('none'), renderiza o avatar normalmente — mesmo tamanho, sem borda extra.
class FramedAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final String frameId;
  final bool showOnline;
  final bool isOnline;
  final VoidCallback? onTap;

  const FramedAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    required this.frameId,
    this.size = 52,
    this.showOnline = false,
    this.isOnline = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final frame = avatarFrameById(frameId);
    final avatar = AppAvatar(
      imageUrl: imageUrl,
      name: name,
      size: size,
      showOnline: showOnline,
      isOnline: isOnline,
    );

    if (frame.colors.isEmpty) {
      return onTap != null
          ? GestureDetector(onTap: onTap, child: avatar)
          : avatar;
    }

    const ringWidth = 4.0;
    final ring = Container(
      width: size + ringWidth * 2,
      height: size + ringWidth * 2,
      padding: const EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: frame.colors.length > 1
            ? SweepGradient(colors: [...frame.colors, frame.colors.first])
            : null,
        color: frame.colors.length == 1 ? frame.colors.first : null,
        boxShadow: [
          BoxShadow(
            color: frame.colors.first.withOpacity(0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: avatar,
    );

    return onTap != null ? GestureDetector(onTap: onTap, child: ring) : ring;
  }
}
