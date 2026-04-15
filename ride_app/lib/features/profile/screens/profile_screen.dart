import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/section_header.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ProfileViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    if (vm.isLoading) return const Scaffold(body: LoadingWidget());
    final user = vm.user;
    if (user == null) return const Scaffold(body: LoadingWidget());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.background,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/profile/edit')),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await context.read<AuthViewModel>().logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.mediumBlue, AppColors.deepNavy],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        AppAvatar(imageUrl: user.avatarUrl, name: user.name, size: AppSpacing.avatarXl, borderColor: AppColors.teal),
                        const SizedBox(height: AppSpacing.md),
                        Text(user.name, style: AppTextStyles.headlineLarge),
                        Text(user.username, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.teal)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      _StatTile(value: '${user.tripsCount}', label: 'Viagens'),
                      const _DividerV(),
                      _StatTile(value: '${user.friendsCount}', label: 'Amigos'),
                      const _DividerV(),
                      const _StatTile(value: '4.9', label: 'Avaliação'),
                    ],
                  ),
                ),
                if (user.bio != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(user.bio!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  ),
                ],
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Minha moto', style: AppTextStyles.headlineSmall),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.teal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                              child: const Icon(Icons.motorcycle, color: AppColors.teal, size: 28),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.motoModel ?? 'Não informado', style: AppTextStyles.headlineSmall),
                                Text(user.motoYear ?? '', style: AppTextStyles.bodyMedium),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SectionHeader(title: 'Galeria', actionLabel: 'Ver todas', onAction: () {}),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 6,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4,
                    ),
                    itemBuilder: (_, i) => Container(
                      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                      child: const Icon(Icons.image_outlined, color: AppColors.textMuted, size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.headlineLarge.copyWith(color: AppColors.teal)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _DividerV extends StatelessWidget {
  const _DividerV();
  @override
  Widget build(BuildContext context) => Container(height: 40, width: 1, color: AppColors.divider);
}
