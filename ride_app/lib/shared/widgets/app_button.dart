import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

enum AppButtonVariant { filled, outline, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool iconTrailing;
  final double? height;
  final Color? color;
  final Color? textColor;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.isLoading = false,
    this.icon,
    this.iconTrailing = false,
    this.height,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final h = height ?? AppSpacing.buttonHeight;
    final bg = color ??
        (variant == AppButtonVariant.filled
            ? AppColors.teal
            : variant == AppButtonVariant.danger
                ? AppColors.error
                : Colors.transparent);
    final fg = textColor ??
        (variant == AppButtonVariant.filled || variant == AppButtonVariant.danger
            ? AppColors.deepNavy
            : AppColors.teal);

    final content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null && !iconTrailing) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(color: fg),
              ),
              if (icon != null && iconTrailing) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: fg),
              ],
            ],
          );

    if (variant == AppButtonVariant.outline) {
      return SizedBox(
        width: double.infinity,
        height: h,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color ?? AppColors.teal, width: 1.5),
            foregroundColor: fg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
          ),
          child: content,
        ),
      );
    }

    if (variant == AppButtonVariant.ghost) {
      return SizedBox(
        width: double.infinity,
        height: h,
        child: TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: fg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
          ),
          child: content,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
          elevation: 0,
        ),
        child: content,
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? background;
  final double size;
  final String? badge;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.background,
    this.size = 40,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: background ?? AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon,
                  size: size * 0.5, color: color ?? AppColors.textPrimary),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  color: AppColors.error, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(badge!,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: Colors.white, fontSize: 9),
                  textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}
