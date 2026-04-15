import 'package:flutter/material.dart';
import '../../core/models/trip_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';
import '../../core/utils/extensions.dart';
import 'app_avatar.dart';

class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback? onTap;

  const TripCard({super.key, required this.trip, this.onTap});

  Color get _statusColor {
    switch (trip.status) {
      case TripStatus.active: return AppColors.teal;
      case TripStatus.completed: return AppColors.success;
      case TripStatus.cancelled: return AppColors.error;
      default: return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSpacing.radiusLg)),
                gradient: const LinearGradient(
                  colors: [AppColors.mediumBlue, AppColors.darkNavy],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.3,
                      child: Icon(Icons.map, size: 80, color: AppColors.teal),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(trip.title,
                                  style: AppTextStyles.headlineSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull),
                                border: Border.all(
                                    color: _statusColor, width: 1),
                              ),
                              child: Text(trip.statusLabel,
                                  style: AppTextStyles.labelSmall
                                      .copyWith(color: _statusColor)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Route
                  Row(
                    children: [
                      const Icon(Icons.radio_button_on,
                          size: 14, color: AppColors.teal),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trip.origin.address ?? trip.origin.label ?? 'Origem',
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trip.destination.address ??
                              trip.destination.label ??
                              'Destino',
                          style: AppTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (trip.scheduledAt != null) ...[
                        const Icon(Icons.calendar_today,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(trip.scheduledAt!.relativeLabel,
                            style: AppTextStyles.labelSmall),
                        const SizedBox(width: 4),
                        Text(trip.scheduledAt!.formattedTime,
                            style: AppTextStyles.labelSmall),
                        const SizedBox(width: AppSpacing.lg),
                      ],
                      if (trip.estimatedDistance != null) ...[
                        const Icon(Icons.straighten,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(trip.estimatedDistance!.formattedKm,
                            style: AppTextStyles.labelSmall),
                      ],
                    ],
                  ),
                  if (trip.participants.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        AvatarGroup(
                          names: trip.participants
                              .map((u) => u.name)
                              .toList(),
                          imageUrls: trip.participants
                              .map((u) => u.avatarUrl)
                              .toList(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${trip.participants.length} participante${trip.participants.length != 1 ? 's' : ''}',
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
