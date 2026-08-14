import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Menu "O que você quer criar?" (bottom sheet). Usado no topo da Home.
/// Centraliza as opções de criação num só lugar (Viagem / Rolê / Motoclube).
Future<void> showCreateSheet(BuildContext context) async {
  final route = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text('O que você quer criar?', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 20),
          _MenuOption(
            icon: Icons.route,
            title: 'Nova Viagem',
            subtitle: 'Planeje um roteiro com destino e paradas',
            onTap: () => Navigator.pop(sheetCtx, '/trips/create'),
          ),
          const SizedBox(height: 12),
          _MenuOption(
            icon: Icons.groups,
            title: 'Novo Rolê',
            subtitle: 'Crie um rolê e convide seus amigos',
            onTap: () => Navigator.pop(sheetCtx, '/rides/create'),
          ),
          const SizedBox(height: 12),
          _MenuOption(
            icon: Icons.shield_moon_outlined,
            title: 'Novo Motoclube',
            subtitle: 'Crie seu clube e convide os membros',
            onTap: () => Navigator.pop(sheetCtx, '/clubs/create'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (route == null || !context.mounted) return;
  await Future.delayed(const Duration(milliseconds: 350));
  if (!context.mounted) return;
  context.push(route);
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.navy, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleLarge),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
