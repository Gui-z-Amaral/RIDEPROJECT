import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Os três valores de presença que o banco aceita (`rsvp` em
/// `event_participants` / `trip_participants`).
class Rsvp {
  const Rsvp._();
  static const going = 'going';
  static const maybe = 'maybe';
  static const declined = 'declined';
}

/// Linha "Vou · Talvez · Não vou".
///
/// Nasceu dentro do mural do motoclube e virou widget compartilhado quando a
/// tela do evento também passou a marcar presença — as duas telas mostram o
/// mesmo dado, então têm que mostrar as mesmas opções.
///
/// [myRsvp] é o valor atual (ou null, sem resposta). [onRsvp] recebe uma das
/// constantes de [Rsvp].
class RsvpBar extends StatelessWidget {
  final String? myRsvp;
  final ValueChanged<String> onRsvp;

  /// Rótulo do "não vou". Curto no mural (cabe pouca largura), por extenso na
  /// tela do evento.
  final String declinedLabel;

  const RsvpBar({
    super.key,
    required this.myRsvp,
    required this.onRsvp,
    this.declinedLabel = 'Não',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RsvpChip(
            label: 'Vou',
            selected: myRsvp == Rsvp.going,
            color: AppColors.success,
            onTap: () => onRsvp(Rsvp.going)),
        RsvpChip(
            label: 'Talvez',
            selected: myRsvp == Rsvp.maybe,
            color: AppColors.warning,
            onTap: () => onRsvp(Rsvp.maybe)),
        RsvpChip(
            label: declinedLabel,
            selected: myRsvp == Rsvp.declined,
            color: AppColors.error,
            onTap: () => onRsvp(Rsvp.declined)),
      ],
    );
  }
}

/// Uma opção de presença.
class RsvpChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const RsvpChip({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            border: Border.all(
                color: selected ? color : AppColors.divider,
                width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? color : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              )),
        ),
      ),
    );
  }
}
