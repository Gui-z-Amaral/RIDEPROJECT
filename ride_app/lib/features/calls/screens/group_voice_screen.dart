import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../active_session/viewmodels/active_session_viewmodel.dart';

class GroupVoiceScreen extends StatefulWidget {
  final String sessionId;
  const GroupVoiceScreen({super.key, required this.sessionId});

  @override
  State<GroupVoiceScreen> createState() => _GroupVoiceScreenState();
}

class _GroupVoiceScreenState extends State<GroupVoiceScreen> {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActiveSessionViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canal de Voz'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.teal.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, color: AppColors.teal),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Canal ativo', style: AppTextStyles.titleLarge.copyWith(color: AppColors.teal)),
                        Text('${vm.participants.length} participantes no canal', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Participantes', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView.separated(
                itemCount: vm.participants.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = vm.participants[i];
                  final speaking = i == 0; // Simulate first person speaking
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: speaking ? AppColors.teal.withOpacity(0.08) : null,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: speaking ? Border.all(color: AppColors.teal.withOpacity(0.3)) : null,
                    ),
                    child: ListTile(
                      leading: AppAvatar(name: p.user.name, imageUrl: p.user.avatarUrl, size: 44, borderColor: speaking ? AppColors.teal : null),
                      title: Text(p.user.name, style: AppTextStyles.titleMedium),
                      subtitle: Text(p.user.motoModel ?? '', style: AppTextStyles.bodySmall),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (speaking) ...[
                            const Icon(Icons.graphic_eq, color: AppColors.teal, size: 18),
                            const SizedBox(width: 4),
                          ],
                          Icon(Icons.mic, size: 18, color: speaking ? AppColors.teal : AppColors.textMuted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: vm.toggleMute,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: vm.myVoiceMuted ? AppColors.error.withOpacity(0.1) : AppColors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(color: vm.myVoiceMuted ? AppColors.error : AppColors.teal),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(vm.myVoiceMuted ? Icons.mic_off : Icons.mic, color: vm.myVoiceMuted ? AppColors.error : AppColors.teal, size: 20),
                          const SizedBox(width: 8),
                          Text(vm.myVoiceMuted ? 'Ativar microfone' : 'Silenciar', style: AppTextStyles.labelLarge.copyWith(color: vm.myVoiceMuted ? AppColors.error : AppColors.teal)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                GestureDetector(
                  onTap: () { vm.toggleVoiceChannel(); context.pop(); },
                  child: Container(
                    width: 52, height: 52,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
