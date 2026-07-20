import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Tela de Configurações do perfil. Por enquanto o item principal é o
/// seletor de tipo de conta (pessoal ↔ empresa). Perfis empresa poderão
/// futuramente criar eventos com programação na tela inicial.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _changeAccountType(BuildContext context, String type) async {
    final vm = context.read<ProfileViewModel>();
    if (vm.user?.accountType == type) return;

    // Mudar PARA empresa pede confirmação, já que muda o que o perfil pode fazer.
    if (type == 'business') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Mudar para conta empresa?'),
          content: const Text(
            'Contas empresa poderão criar eventos e divulgar a programação '
            'na tela inicial. Você pode voltar para conta pessoal quando quiser.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Mudar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final ok = await vm.setAccountType(type);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (type == 'business'
                ? 'Conta alterada para empresa.'
                : 'Conta alterada para pessoal.')
            : 'Não foi possível salvar. Tente novamente.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final accountType = vm.user?.accountType ?? 'personal';
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Configurações',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 24),
        children: [
          // ── Conta ──────────────────────────────────────────────
          const _SectionLabel('Conta'),
          const SizedBox(height: 12),
          _AccountTypeCard(
            icon: Icons.person_outline,
            title: 'Pessoal',
            subtitle: 'Participe de rolês e viagens com seus amigos.',
            selected: accountType == 'personal',
            saving: vm.isSaving,
            onTap: () => _changeAccountType(context, 'personal'),
          ),
          const SizedBox(height: 12),
          _AccountTypeCard(
            icon: Icons.storefront_outlined,
            title: 'Empresa',
            subtitle:
                'Crie eventos e divulgue sua programação na tela inicial (em breve).',
            selected: accountType == 'business',
            saving: vm.isSaving,
            onTap: () => _changeAccountType(context, 'business'),
          ),

          const SizedBox(height: 32),

          // ── Segurança ──────────────────────────────────────────
          const _SectionLabel('Segurança'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.lock_reset, color: AppColors.navy),
              title: Text('Trocar senha', style: AppTextStyles.bodyMedium),
              subtitle: Text('Enviaremos um código para o seu email',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textMuted),
              onTap: () {
                final email = Supabase
                    .instance.client.auth.currentUser?.email;
                context.push('/forgot-password', extra: email);
              },
            ),
          ),

          const SizedBox(height: 32),

          // ── Atividade ──────────────────────────────────────────
          const _SectionLabel('Atividade'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.history, color: AppColors.navy),
              title: Text('Histórico de rolês e viagens',
                  style: AppTextStyles.bodyMedium),
              subtitle: Text('Veja tudo e remova do seu perfil',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.textMuted),
              onTap: () => context.push('/profile/history'),
            ),
          ),

          const SizedBox(height: 32),

          // ── Sobre ──────────────────────────────────────────────
          const _SectionLabel('Sobre'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.navy),
              title: Text('Versão', style: AppTextStyles.bodyMedium),
              trailing: Text('1.0.0',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Account type card ─────────────────────────────────────────────────────────

class _AccountTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool saving;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: saving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy.withOpacity(0.06) : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppColors.navy : AppColors.textSecondary,
                size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: selected ? AppColors.navy : null)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textSecondary, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.navy : AppColors.divider,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
