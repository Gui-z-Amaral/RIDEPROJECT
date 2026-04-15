import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';
import '../../core/utils/extensions.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnline;
  final bool isOnline;
  final VoidCallback? onTap;
  final Color? borderColor;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = AppSpacing.avatarMd,
    this.showOnline = false,
    this.isOnline = false,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.initials;
    final child = ClipOval(
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _Placeholder(initials: initials, size: size),
              placeholder: (_, __) => _Placeholder(initials: initials, size: size),
            )
          : _Placeholder(initials: initials, size: size),
    );

    final avatar = borderColor != null
        ? Container(
            width: size + 4,
            height: size + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderColor!, width: 2),
            ),
            child: child,
          )
        : SizedBox(width: size, height: size, child: child);

    return Stack(
      children: [
        onTap != null
            ? GestureDetector(onTap: onTap, child: avatar)
            : avatar,
        if (showOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.online : AppColors.offline,
                border: const BorderSide(color: AppColors.background, width: 1.5) as Border?,
              ),
            ),
          ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String initials;
  final double size;

  const _Placeholder({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppColors.mediumBlue,
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: AppColors.lightCyan,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }
}

class AvatarGroup extends StatelessWidget {
  final List<String> names;
  final List<String?> imageUrls;
  final double size;
  final int max;

  const AvatarGroup({
    super.key,
    required this.names,
    required this.imageUrls,
    this.size = AppSpacing.avatarSm,
    this.max = 4,
  });

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    final extra = names.length - max;

    return SizedBox(
      height: size,
      width: size + (shown.length - 1) * (size * 0.6) + (extra > 0 ? size * 0.6 : 0),
      child: Stack(
        children: [
          ...List.generate(shown.length, (i) {
            return Positioned(
              left: i * (size * 0.6),
              child: AppAvatar(
                imageUrl: i < imageUrls.length ? imageUrls[i] : null,
                name: shown[i],
                size: size,
                borderColor: AppColors.card,
              ),
            );
          }),
          if (extra > 0)
            Positioned(
              left: shown.length * (size * 0.6),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant,
                  border: Border.all(color: AppColors.card, width: 1.5),
                ),
                child: Center(
                  child: Text('+$extra',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
