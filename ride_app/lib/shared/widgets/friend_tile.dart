import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';
import 'app_avatar.dart';
import 'app_button.dart';

enum FriendTileAction { chat, add, remove, accept, reject }

class FriendTile extends StatelessWidget {
  final UserModel user;
  final List<FriendTileAction> actions;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final VoidCallback? onSecondaryAction;
  final bool showMoto;
  final bool selected;

  const FriendTile({
    super.key,
    required this.user,
    this.actions = const [],
    this.onTap,
    this.onAction,
    this.onSecondaryAction,
    this.showMoto = true,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: selected
            ? BoxDecoration(
                color: AppColors.teal.withOpacity(0.1),
                border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              )
            : null,
        child: Row(
          children: [
            AppAvatar(
              imageUrl: user.avatarUrl,
              name: user.name,
              size: AppSpacing.avatarMd,
              showOnline: true,
              isOnline: user.isOnline,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: AppTextStyles.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(user.username,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (showMoto && user.motoModel != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.motorcycle,
                            size: 12, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Text(
                          '${user.motoModel} ${user.motoYear ?? ''}',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.teal),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actions.contains(FriendTileAction.chat))
                    _ActionBtn(
                      icon: Icons.chat_bubble_outline,
                      onTap: onAction,
                    ),
                  if (actions.contains(FriendTileAction.add))
                    _ActionBtn(
                      icon: Icons.person_add_outlined,
                      onTap: onAction,
                      color: AppColors.teal,
                    ),
                  if (actions.contains(FriendTileAction.remove))
                    _ActionBtn(
                      icon: Icons.person_remove_outlined,
                      onTap: onAction,
                      color: AppColors.error,
                    ),
                  if (actions.contains(FriendTileAction.accept)) ...[
                    _ActionBtn(
                      icon: Icons.check_circle_outline,
                      onTap: onAction,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (actions.contains(FriendTileAction.reject))
                    _ActionBtn(
                      icon: Icons.cancel_outlined,
                      onTap: onSecondaryAction,
                      color: AppColors.error,
                    ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.teal, size: 24),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionBtn({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (color ?? AppColors.textMuted).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color ?? AppColors.textSecondary),
      ),
    );
  }
}
