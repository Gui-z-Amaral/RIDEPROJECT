import 'package:flutter/material.dart';
import '../../core/models/stop_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class StopCard extends StatelessWidget {
  final StopModel stop;
  final VoidCallback? onTap;
  final bool horizontal;

  const StopCard({super.key, required this.stop, this.onTap, this.horizontal = true});

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'mirante': return Icons.landscape;
      case 'gastronômico': return Icons.restaurant;
      case 'posto': return Icons.local_gas_station;
      case 'natureza': return Icons.park;
      default: return Icons.place;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'mirante': return AppColors.lightCyan;
      case 'gastronômico': return AppColors.warning;
      case 'posto': return AppColors.teal;
      case 'natureza': return AppColors.success;
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _categoryColor(stop.category);
    if (!horizontal) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(_categoryIcon(stop.category), size: 20, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stop.name, style: AppTextStyles.titleMedium),
                    Text(stop.category, style: AppTextStyles.bodySmall.copyWith(color: iconColor)),
                  ],
                ),
              ),
              if (stop.rating != null)
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.warning),
                    const SizedBox(width: 2),
                    Text(stop.rating!.toStringAsFixed(1), style: AppTextStyles.labelSmall),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Center(child: Icon(_categoryIcon(stop.category), size: 36, color: iconColor)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(stop.name, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(stop.category, style: AppTextStyles.bodySmall.copyWith(color: iconColor)),
            if (stop.rating != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, size: 12, color: AppColors.warning),
                  const SizedBox(width: 2),
                  Text(stop.rating!.toStringAsFixed(1), style: AppTextStyles.labelSmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
