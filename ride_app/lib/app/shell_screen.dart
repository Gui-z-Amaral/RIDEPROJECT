import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../features/active_session/viewmodels/active_session_viewmodel.dart';
import '../shared/widgets/active_session_banner.dart';

class ShellScreen extends StatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const _doubleBackWindow = Duration(seconds: 2);
  DateTime? _lastBackAt;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/profile')) return 0;
    if (location.startsWith('/home'))    return 1;
    if (location.startsWith('/trips'))  return 2;
    if (location.startsWith('/rides'))  return 3;
    return 1;
  }

  /// Intercepta o botão de voltar em rotas-raiz (shell):
  /// 1º toque em < 2s → mostra snackbar "pressione novamente para sair"
  /// 2º toque em < 2s → minimiza o app
  /// Rotas empurradas (push) em cima do shell usam o pop padrão do GoRouter.
  void _handleBackPress() {
    // Defesa: se algum Navigator aninhado ainda pode popar (modal bottom sheet,
    // diálogo, etc.), deixa o pop padrão acontecer em vez de mostrar o prompt.
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }

    final now = DateTime.now();
    if (_lastBackAt != null &&
        now.difference(_lastBackAt!) <= _doubleBackWindow) {
      SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Pressione novamente para sair'),
          duration: _doubleBackWindow,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    final sessionVM = context.watch<ActiveSessionViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
      extendBody: true,
      body: Column(
        children: [
          if (sessionVM.hasActiveSession)
            ActiveSessionBanner(
              title: sessionVM.sessionTitle,
              isRide: sessionVM.isRide,
              // Push em vez de go para que o back volte para a tab atual
              // em vez de minimizar o app.
              onTap: () => context.push(
                '/session/active/${sessionVM.sessionId}',
                extra: {'isRide': sessionVM.isRide},
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/home'),
        backgroundColor: AppColors.navy,
        elevation: 4,
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.background,
        elevation: 8,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Perfil',
                  active: idx == 0,
                  onTap: () => context.go('/profile'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.add_circle_outline,
                  activeIcon: Icons.add_circle,
                  label: 'Criar',
                  active: false,
                  onTap: () => _showCreateMenu(context),
                ),
              ),
              const Expanded(child: SizedBox()),
              Expanded(
                child: _NavItem(
                  icon: Icons.flight_takeoff_outlined,
                  activeIcon: Icons.flight_takeoff,
                  label: 'Viagens',
                  active: idx == 2,
                  onTap: () => context.go('/trips'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups,
                  label: 'Rolês',
                  active: idx == 3,
                  onTap: () => context.go('/rides'),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _showCreateMenu(BuildContext context) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('O que você quer criar?',
                style: AppTextStyles.headlineMedium),
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
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? activeIcon : icon,
            color: active ? AppColors.navy : AppColors.textMuted,
            size: 24,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: active ? AppColors.navy : AppColors.textMuted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
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
              width: 48, height: 48,
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
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
