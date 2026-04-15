import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../viewmodels/active_session_viewmodel.dart';

class GuestConfirmScreen extends StatelessWidget {
  final String sessionId;
  const GuestConfirmScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActiveSessionViewModel>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.deepNavy, AppColors.darkNavy], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.teal.withOpacity(0.12),
                    border: Border.all(color: AppColors.teal, width: 2),
                  ),
                  child: const Icon(Icons.notifications_active, color: AppColors.teal, size: 56),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(vm.isRide ? 'Convite para Rolê' : 'Convite para Viagem', style: AppTextStyles.displaySmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '"${vm.sessionTitle}" está prestes a começar!\nVocê confirma participação?',
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                AppButton(
                  label: 'Confirmar participação',
                  icon: Icons.check_circle,
                  onPressed: () {
                    vm.confirmParticipant('u1');
                    context.go('/session/waiting/$sessionId');
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Não posso ir',
                  variant: AppButtonVariant.outline,
                  color: AppColors.error,
                  textColor: AppColors.error,
                  onPressed: () {
                    vm.removeParticipant('u1');
                    context.pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
