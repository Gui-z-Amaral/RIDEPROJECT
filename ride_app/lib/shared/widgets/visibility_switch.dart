import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Seletor público/privado usado ao criar evento e viagem.
///
/// Vive aqui porque as duas telas precisam do mesmo controle, com o mesmo
/// texto e o mesmo comportamento. Até a migration 034 a visibilidade vinha de
/// um interruptor único no motoclube; agora cada item tem o seu.
class VisibilitySwitch extends StatelessWidget {
  final bool isPublic;
  final ValueChanged<bool> onChanged;

  /// O que dizer em cada estado. Muda entre evento e viagem porque o que está
  /// em jogo é diferente: evento é divulgação, viagem tem trajeto e horário.
  final String publicHint;
  final String privateHint;

  const VisibilitySwitch({
    super.key,
    required this.isPublic,
    required this.onChanged,
    required this.publicHint,
    required this.privateHint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: isPublic,
        onChanged: onChanged,
        activeColor: AppColors.navy,
        secondary: Icon(isPublic ? Icons.public : Icons.lock_outline,
            color: AppColors.navy),
        title: Text(isPublic ? 'Público' : 'Privado',
            style: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          isPublic ? publicHint : privateHint,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}
