import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Tela de Configurações do perfil. Por enquanto o item principal é o
/// seletor de tipo de conta (pessoal ↔ empresa). Perfis empresa poderão
/// futuramente criar eventos com programação na tela inicial.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Pede a permissão de notificação. Chamado DIRETO do toque, sem await antes:
  /// o Safari do iOS só aceita o pedido durante o gesto do usuário, e era por
  /// isso que o iPhone ficava sem token nenhum (o pedido automático após o
  /// login já vinha depois do await e era recusado em silêncio).
  Future<void> _ativarNotificacoes(BuildContext context) async {
    final r = await PushNotificationService.instance.enableFromUserGesture();
    if (!context.mounted) return;
    switch (r) {
      case PushEnableResult.ativado:
        context.showSnack('Notificações ativadas neste aparelho.');
      case PushEnableResult.recusado:
        context.showSnack(
            'Notificações bloqueadas. Libere nas configurações do navegador '
            'ou do aparelho e tente de novo.',
            isError: true);
      case PushEnableResult.semToken:
        context.showSnack(
            'Não deu para ativar aqui. No iPhone é preciso instalar o app na '
            'tela de início (Compartilhar → Adicionar à Tela de Início) e abrir '
            'por lá.',
            isError: true);
      case PushEnableResult.naoConfigurado:
        context.showSnack('Notificações não estão configuradas nesta versão.',
            isError: true);
    }
  }

  /// Desativa a conta. Não apaga: a lei brasileira exige guardar os dados por
  /// pelo menos 6 meses, então o perfil é desligado e os dados pessoais ficam
  /// guardados fora do alcance de qualquer consulta (migration 034).
  ///
  /// Confirmação em duas etapas de propósito — é a ação mais destrutiva do app,
  /// e o texto diz exatamente o que acontece, incluindo que dá para voltar.
  Future<void> _confirmDeactivate(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir meu perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('O que acontece:'),
            const SizedBox(height: 10),
            const _Bullet('Seu nome vira "Usuário inativo" para todo mundo'),
            const _Bullet('Foto, bio e fotos do perfil saem do ar'),
            const _Bullet('Você some da busca por riders próximos'),
            const _Bullet('Para de receber notificações'),
            const SizedBox(height: 12),
            Text(
              'Suas viagens e mensagens continuam existindo para quem participou '
              'delas, sem o seu nome.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              'Se você entrar de novo, seu perfil volta como estava. Depois de 6 '
              'meses a conta é apagada em definitivo.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir meu perfil',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await SupabaseAuthService.deactivateAccount();
      if (!context.mounted) return;
      await context.read<AuthViewModel>().logout();
      if (context.mounted) context.go('/login');
    } catch (e) {
      if (context.mounted) {
        context.showSnack('Não foi possível excluir agora: $e', isError: true);
      }
    }
  }

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
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
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

          // ── Aparência ────────────────────────────────────────────
          const _SectionLabel('Aparência'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(Icons.palette_outlined, color: AppColors.navy),
              title: Text('Aparência do perfil', style: AppTextStyles.bodyMedium),
              subtitle: Text('Banner do perfil e modo escuro',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              trailing: Icon(Icons.chevron_right,
                  color: AppColors.textMuted),
              onTap: () => context.push('/profile/appearance'),
            ),
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
              leading: Icon(Icons.lock_reset, color: AppColors.navy),
              title: Text('Trocar senha', style: AppTextStyles.bodyMedium),
              subtitle: Text('Enviaremos um código para o seu email',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              trailing: Icon(Icons.chevron_right,
                  color: AppColors.textMuted),
              onTap: () {
                final email = Supabase
                    .instance.client.auth.currentUser?.email;
                context.push('/forgot-password', extra: email);
              },
            ),
          ),

          const SizedBox(height: 32),

          // ── Privacidade ────────────────────────────────────────
          const _SectionLabel('Privacidade'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: vm.user?.isPrivate ?? false,
                  onChanged: (v) =>
                      context.read<ProfileViewModel>().setPrivate(v),
                  activeColor: AppColors.navy,
                  secondary: Icon(Icons.lock_outline, color: AppColors.navy),
                  title:
                      Text('Perfil privado', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                      'Quem não é seu amigo vê só nome, @ e foto',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ),
                Divider(
                    height: 1,
                    color: AppColors.divider,
                    indent: 16,
                    endIndent: 16),
                SwitchListTile(
                  value: vm.user?.discoverable ?? true,
                  onChanged: (v) =>
                      context.read<ProfileViewModel>().setDiscoverable(v),
                  activeColor: AppColors.navy,
                  secondary:
                      Icon(Icons.near_me_outlined, color: AppColors.navy),
                  title: Text('Aparecer na descoberta',
                      style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                      'Aparecer nos riders próximos. Desligado, só te acham pelo @',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ),
              ],
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
              leading: Icon(Icons.history, color: AppColors.navy),
              title: Text('Histórico de rolês e viagens',
                  style: AppTextStyles.bodyMedium),
              subtitle: Text('Veja tudo e remova do seu perfil',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              trailing: Icon(Icons.chevron_right,
                  color: AppColors.textMuted),
              onTap: () => context.push('/profile/history'),
            ),
          ),

          const SizedBox(height: 32),

          // ── Notificações ───────────────────────────────────────
          const _SectionLabel('Notificações'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading:
                  Icon(Icons.notifications_active_outlined, color: AppColors.navy),
              title: Text('Ativar notificações neste aparelho',
                  style: AppTextStyles.bodyMedium),
              subtitle: Text(
                  'Avisos de mensagens, convites e rolês. No iPhone, só funciona '
                  'com o app instalado na tela de início.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => _ativarNotificacoes(context),
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
              leading: Icon(Icons.info_outline, color: AppColors.navy),
              title: Text('Versão', style: AppTextStyles.bodyMedium),
              trailing: Text('1.0.0',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
            ),
          ),

          const SizedBox(height: 32),

          // ── Conta ──────────────────────────────────────────────
          const _SectionLabel('Conta'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.person_off_outlined,
                  color: AppColors.error),
              title: Text('Excluir meu perfil',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.error)),
              subtitle: Text('Seu perfil sai do ar e some das buscas',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
              onTap: () => _confirmDeactivate(context),
            ),
          ),

          const SizedBox(height: 40),
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

/// Item de lista do diálogo de exclusão de perfil.
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
          ],
        ),
      );
}
