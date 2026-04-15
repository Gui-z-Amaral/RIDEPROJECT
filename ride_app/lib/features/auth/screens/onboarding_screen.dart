import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';

class _Page {
  final String title;
  final String subtitle;
  final List<Color> waveColors;
  final IconData illustrationIcon;

  const _Page({
    required this.title,
    required this.subtitle,
    required this.waveColors,
    required this.illustrationIcon,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = const [
    _Page(
      title: 'CONVIDE E EXPLORE',
      subtitle:
          'Convide amigos, compartilhe o planejamento e descubra paradas recomendadas para a sua rota',
      waveColors: [Color(0xFF4A8FE4), Color(0xFF1B5FBF)],
      illustrationIcon: Icons.groups,
    ),
    _Page(
      title: 'MONTE UMA ROTA COM A SUA CARA',
      subtitle:
          'Escolha o tipo de rota e adicione paradas para paisagens, gastronomia, descanso ou hospedagem.',
      waveColors: [Color(0xFF5BBDE4), Color(0xFF1B7BBF)],
      illustrationIcon: Icons.map_outlined,
    ),
    _Page(
      title: 'PLANEJE VIAGENS DO SEU JEITO',
      subtitle:
          'Crie roteiros de viagem com partida, destino e paradas',
      waveColors: [Color(0xFF4AC4D8), Color(0xFF0F8FAD)],
      illustrationIcon: Icons.explore_outlined,
    ),
  ];

  int _page = 0;
  final _ctrl = PageController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      context.go('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // PageView
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: _pages.length,
            itemBuilder: (_, i) => _PageContent(page: _pages[i], size: size),
          ),

          // Top bar: RIDE + skip
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RIDE',
                    style: AppTextStyles.displaySmall.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                      letterSpacing: 2,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'Pular',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: dots + button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _page;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                active ? AppColors.navy : AppColors.divider,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _next,
                        child: Text(
                          _page < _pages.length - 1 ? 'PRÓXIMO' : 'COMEÇAR',
                          style: AppTextStyles.labelLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Já tenho conta — Entrar',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _Page page;
  final Size size;

  const _PageContent({required this.page, required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Space below top bar
        const SizedBox(height: 80),

        // Text content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                page.title,
                style: AppTextStyles.headlineLarge.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                page.subtitle,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Wave illustration
        _WaveIllustration(
          waveColors: page.waveColors,
          icon: page.illustrationIcon,
          width: size.width,
        ),

        // Space for bottom buttons
        const SizedBox(height: 140),
      ],
    );
  }
}

class _WaveIllustration extends StatelessWidget {
  final List<Color> waveColors;
  final IconData icon;
  final double width;

  const _WaveIllustration({
    required this.waveColors,
    required this.icon,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      width: width,
      child: Stack(
        children: [
          // Wave background
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: waveColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // Cloud circles
          Positioned(
            top: 30,
            right: 60,
            child: _Cloud(size: 18),
          ),
          Positioned(
            top: 22,
            right: 90,
            child: _Cloud(size: 12),
          ),
          Positioned(
            top: 35,
            right: 40,
            child: _Cloud(size: 10),
          ),
          // Center illustration icon
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, 0.5),
              child: Icon(icon, size: 80, color: Colors.white.withOpacity(0.9)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  final double size;
  const _Cloud({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 2.5,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.35);
    path.cubicTo(
      size.width * 0.25, size.height * 0.15,
      size.width * 0.6, size.height * 0.55,
      size.width, size.height * 0.25,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => false;
}
