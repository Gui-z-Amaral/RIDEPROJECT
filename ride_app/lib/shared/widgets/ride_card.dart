import 'package:flutter/material.dart';
import '../../core/models/ride_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';
import '../../core/utils/extensions.dart';
import 'app_avatar.dart';

class RideCard extends StatelessWidget {
  final RideModel ride;
  final VoidCallback? onTap;

  const RideCard({super.key, required this.ride, this.onTap});

  Color get _statusColor {
    switch (ride.status) {
      case RideStatus.active: return AppColors.teal;
      case RideStatus.waiting: return AppColors.warning;
      case RideStatus.completed: return AppColors.success;
      case RideStatus.cancelled: return AppColors.error;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(Icons.groups,
                      color: AppColors.teal, size: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ride.title, style: AppTextStyles.titleLarge,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              ride.meetingPoint.address ?? 'Ponto de encontro',
                              style: AppTextStyles.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(color: _statusColor, width: 1),
                  ),
                  child: Text(ride.statusLabel,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: _statusColor)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (ride.scheduledAt != null) ...[
                  const Icon(Icons.schedule,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${ride.scheduledAt!.relativeLabel} às ${ride.scheduledAt!.formattedTime}',
                    style: AppTextStyles.labelSmall,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                ] else ...[
                  const Icon(Icons.flash_on,
                      size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text('Imediato', style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning)),
                  const SizedBox(width: AppSpacing.lg),
                ],
                if (ride.participants.isNotEmpty)
                  AvatarGroup(
                    names: ride.participants.map((u) => u.name).toList(),
                    imageUrls:
                        ride.participants.map((u) => u.avatarUrl).toList(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
