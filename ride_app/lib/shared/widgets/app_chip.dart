import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onDelete;

  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.color,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.teal;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.2) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: selected ? c : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? c : AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(label, style: AppTextStyles.labelMedium.copyWith(color: selected ? c : AppColors.textSecondary)),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close, size: 14, color: selected ? c : AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
