import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../viewmodels/active_session_viewmodel.dart';

class WaitingScreen extends StatelessWidget {
  final String sessionId;
  const WaitingScreen({super.key, required this.sessionId});

  Future<void> _startNow(BuildContext context) async {
    final vm = context.read<ActiveSessionViewModel>();
    await vm.startNow();
    if (context.mounted) {
      context.go('/session/active/$sessionId',
          extra: {'isRide': vm.isRide});
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActiveSessionViewModel>();

    // Auto-navega quando todos responderam
    if (vm.allConfirmed && vm.confirmedCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/session/active/$sessionId',
              extra: {'isRide': vm.isRide});
        }
      });
    }

    final waiting = vm.participants
        .where((p) => p.status == ParticipantStatus.waiting)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(vm.isRide ? 'Iniciando Rolê' : 'Iniciando Viagem'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              vm.endSession();
              context.pop();
            },
            child: Text(
              'Cancelar',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xxl),

            _PulsingCircle(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.motorcycle, color: AppColors.teal, size: 52),
                  const SizedBox(height: 8),
                  Text(
                    vm.sessionTitle,
                    style: AppTextStyles.titleLarge,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            Text(
              'Aguardando confirmação dos participantes',
              style: AppTextStyles.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: AppTextStyles.displaySmall,
                children: [
                  TextSpan(
                    text: '${vm.confirmedCount}',
                    style: const TextStyle(color: AppColors.teal),
                  ),
                  TextSpan(
                    text: '/${vm.participants.length}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  TextSpan(
                    text: ' confirmados',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (waiting > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$waiting aguardando resposta',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.warning),
                ),
              ),

            const SizedBox(height: AppSpacing.xxl),

            // Lista de participantes
            Expanded(
              child: vm.participants.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum convidado — só você neste rolê.',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: vm.participants.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = vm.participants[i];
                        return ListTile(
                          leading: AppAvatar(
                            name: p.user.name,
                            imageUrl: p.user.avatarUrl,
                            size: 40,
                          ),
                          title: Text(p.user.name,
                              style: AppTextStyles.titleMedium),
                          subtitle: Text(
                            p.user.motoModel ?? '',
                            style: AppTextStyles.bodySmall,
                          ),
                          trailing: _StatusBadge(p.status),
                        );
                      },
                    ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Iniciar agora — sempre disponível para o criador
            AppButton(
              label: 'Iniciar agora',
              icon: Icons.play_arrow,
              onPressed: () => _startNow(context),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Aguardando — desabilitado enquanto há pendentes
            if (waiting > 0)
              OutlinedButton.icon(
                onPressed: null,
                icon: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.teal),
                ),
                label: Text('$waiting aguardando confirmação...'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize:
                      const Size(double.infinity, AppSpacing.buttonHeight),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull)),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ParticipantStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ParticipantStatus.confirmed => ('Confirmado', AppColors.success),
      ParticipantStatus.declined => ('Recusou', AppColors.error),
      _ => ('Aguardando', AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style: AppTextStyles.labelSmall.copyWith(color: color)),
    );
  }
}

class _PulsingCircle extends StatefulWidget {
  final Widget child;
  const _PulsingCircle({required this.child});

  @override
  State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.teal.withOpacity(0.1),
          border: Border.all(color: AppColors.teal, width: 2),
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}
