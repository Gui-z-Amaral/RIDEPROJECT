import 'package:flutter/material.dart';
import '../../core/models/trip_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

class RouteTypeSelector extends StatelessWidget {
  final RouteType selected;
  final ValueChanged<RouteType> onChanged;

  const RouteTypeSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: RouteType.values.map((type) {
        final isSelected = selected == type;
        return GestureDetector(
          onTap: () => onChanged(type),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.teal.withOpacity(0.15) : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isSelected ? AppColors.teal : AppColors.divider,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(_icon(type), size: 20, color: isSelected ? AppColors.teal : AppColors.textMuted),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label(type), style: AppTextStyles.titleMedium.copyWith(color: isSelected ? AppColors.teal : AppColors.textPrimary)),
                      Text(_desc(type), style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: AppColors.teal, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _icon(RouteType t) {
    switch (t) {
      case RouteType.scenic: return Icons.landscape;
      case RouteType.gastronomic: return Icons.restaurant;
      case RouteType.shortest: return Icons.speed;
      case RouteType.safest: return Icons.shield;
      case RouteType.none: return Icons.remove;
    }
  }

  String _label(RouteType t) {
    switch (t) {
      case RouteType.scenic: return 'Panorâmica';
      case RouteType.gastronomic: return 'Gastronômica';
      case RouteType.shortest: return 'Mais curta';
      case RouteType.safest: return 'Mais segura';
      case RouteType.none: return 'Nenhuma';
    }
  }

  String _desc(RouteType t) {
    switch (t) {
      case RouteType.scenic: return 'Rotas cênicas com paisagens incríveis';
      case RouteType.gastronomic: return 'Paradas em restaurantes e cafés';
      case RouteType.shortest: return 'O caminho mais direto';
      case RouteType.safest: return 'Menor risco e melhor conservação';
      case RouteType.none: return 'Sem preferência de rota';
    }
  }
}
