import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../core/services/mock_data.dart';

class VoiceCallScreen extends StatefulWidget {
  final String userId;
  const VoiceCallScreen({super.key, required this.userId});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> with SingleTickerProviderStateMixin {
  bool _muted = false;
  bool _speakerOn = false;
  final _callDuration = ValueNotifier<int>(0);
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    // Simulate call duration counter
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      _callDuration.value++;
      return true;
    });
  }

  @override
  void dispose() { _waveCtrl.dispose(); _callDuration.dispose(); super.dispose(); }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = MockData.users.firstWhere((u) => u.id == widget.userId, orElse: () => MockData.users.first);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.deepNavy, AppColors.darkNavy, AppColors.mediumBlue], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Text('Chamada de voz', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xxl),

              // Avatar with wave
              Stack(
                alignment: Alignment.center,
                children: [
                  ...List.generate(3, (i) => AnimatedBuilder(
                    animation: _waveCtrl,
                    builder: (_, __) => Container(
                      width: 100 + (i + 1) * 30.0 + _waveCtrl.value * 10,
                      height: 100 + (i + 1) * 30.0 + _waveCtrl.value * 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.teal.withOpacity(0.3 - i * 0.08), width: 1),
                      ),
                    ),
                  )),
                  AppAvatar(name: user.name, imageUrl: user.avatarUrl, size: 100, borderColor: AppColors.teal),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),
              Text(user.name, style: AppTextStyles.displayMedium),
              const SizedBox(height: AppSpacing.sm),
              if (user.motoModel != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.motorcycle, color: AppColors.teal, size: 16),
                    const SizedBox(width: 4),
                    Text(user.motoModel!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.teal)),
                  ],
                ),
              const SizedBox(height: AppSpacing.lg),
              ValueListenableBuilder<int>(
                valueListenable: _callDuration,
                builder: (_, secs, __) => Text(_formatDuration(secs), style: AppTextStyles.displaySmall.copyWith(color: AppColors.lightCyan)),
              ),

              const Spacer(),

              // Controls
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallBtn(icon: _muted ? Icons.mic_off : Icons.mic, label: _muted ? 'Ativar' : 'Mudo', color: _muted ? AppColors.error : AppColors.textSecondary, onTap: () => setState(() => _muted = !_muted)),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 68, height: 68,
                        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                      ),
                    ),
                    _CallBtn(icon: _speakerOn ? Icons.volume_up : Icons.volume_down, label: 'Alto-fal.', color: _speakerOn ? AppColors.teal : AppColors.textSecondary, onTap: () => setState(() => _speakerOn = !_speakerOn)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.3))),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: color)),
        ],
      ),
    );
  }
}
