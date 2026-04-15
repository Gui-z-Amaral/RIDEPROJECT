import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class ActiveSessionBanner extends StatelessWidget {
  final String title;
  final bool isRide;
  final VoidCallback? onTap;

  const ActiveSessionBanner({
    super.key,
    required this.title,
    required this.isRide,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.teal, AppColors.mediumBlue]),
        ),
        child: Row(
          children: [
            const _PulsingDot(),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRide ? 'Rolê em andamento' : 'Viagem em andamento',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.deepNavy),
                  ),
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.deepNavy),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.deepNavy, size: 20),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: AppColors.deepNavy, shape: BoxShape.circle),
      ),
    );
  }
}
