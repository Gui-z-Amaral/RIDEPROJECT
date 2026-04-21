import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/models/user_model.dart';

class FriendProfileScreen extends StatelessWidget {
  final UserModel user;
  const FriendProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
              onPressed: () => context.pop(),
            ),
            title: Text(
              user.name.toUpperCase(),
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // ── Avatar com indicador online ──────────────────────
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.navy.withOpacity(0.1),
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy),
                            )
                          : null,
                    ),
                    if (user.isOnline)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppColors.background, width: 2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                Text(
                  user.name.toUpperCase(),
                  style: AppTextStyles.headlineLarge
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                if (user.username.isNotEmpty)
                  Text(
                    '@${user.username}',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                  ),
                if (user.city != null && user.city!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        user.city!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // ── Stats ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _StatBox(
                          value: '${user.tripsCount}', label: 'Viagens\ncriadas'),
                      const SizedBox(width: 12),
                      _StatBox(
                          value: '${user.friendsCount}',
                          label: 'Amigos\nadicionados'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Moto ──────────────────────────────────────────────
                if (user.motoModel != null && user.motoModel!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.motorcycle,
                              color: AppColors.teal, size: 24),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.motoModel!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14),
                              ),
                              if (user.motoYear != null &&
                                  user.motoYear!.isNotEmpty)
                                Text(
                                  user.motoYear!,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Bio ───────────────────────────────────────────────
                if (user.bio != null && user.bio!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio',
                            style: AppTextStyles.headlineMedium
                                .copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          user.bio!,
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const Divider(height: 1),
                const SizedBox(height: AppSpacing.xl),

                // ── Botão Mensagem ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/friends/chat/${user.id}'),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('ENVIAR MENSAGEM'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: bottomPad + 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTextStyles.headlineLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: AppColors.navy),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
