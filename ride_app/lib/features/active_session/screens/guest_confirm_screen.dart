import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../core/services/supabase_ride_service.dart';
import '../../../core/services/supabase_trip_service.dart';

class GuestConfirmScreen extends StatefulWidget {
  final String sessionId;
  final bool isRide;

  const GuestConfirmScreen({
    super.key,
    required this.sessionId,
    this.isRide = true,
  });

  @override
  State<GuestConfirmScreen> createState() => _GuestConfirmScreenState();
}

class _GuestConfirmScreenState extends State<GuestConfirmScreen> {
  bool _isLoading = false;

  Future<void> _confirm() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isRide) {
        await SupabaseRideService.confirmParticipation(widget.sessionId);
      } else {
        await SupabaseTripService.confirmParticipation(widget.sessionId);
      }
    } catch (_) {}
    // Entra na sessão ativa diretamente — funciona mesmo com rolê já em andamento
    if (mounted) {
      context.go('/session/active/${widget.sessionId}',
          extra: {'isRide': widget.isRide});
    }
  }

  Future<void> _decline() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isRide) {
        await SupabaseRideService.declineParticipation(widget.sessionId);
      } else {
        await SupabaseTripService.declineParticipation(widget.sessionId);
      }
    } catch (_) {}
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.isRide ? 'Rolê' : 'Viagem';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.deepNavy, AppColors.darkNavy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.teal.withOpacity(0.12),
                    border: Border.all(color: AppColors.teal, width: 2),
                  ),
                  child: const Icon(Icons.notifications_active,
                      color: AppColors.teal, size: 56),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Convite para $typeLabel',
                  style: AppTextStyles.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Você foi convidado para participar!\nConfirma presença?',
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                AppButton(
                  label: 'Confirmar participação',
                  icon: Icons.check_circle,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _confirm,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Não posso ir',
                  variant: AppButtonVariant.outline,
                  color: AppColors.error,
                  textColor: AppColors.error,
                  onPressed: _isLoading ? null : _decline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
