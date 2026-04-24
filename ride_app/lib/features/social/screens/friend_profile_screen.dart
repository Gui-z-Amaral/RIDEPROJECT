import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_social_service.dart';
import '../../../shared/widgets/app_avatar.dart';

class FriendProfileScreen extends StatefulWidget {
  final UserModel user;
  const FriendProfileScreen({super.key, required this.user});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  List<UserModel> _mutualFriends = [];
  bool _loadingMutual = true;

  @override
  void initState() {
    super.initState();
    _loadMutual();
  }

  Future<void> _loadMutual() async {
    try {
      final list = await SupabaseSocialService.getMutualFriends(widget.user.id);
      if (!mounted) return;
      setState(() {
        _mutualFriends = list;
        _loadingMutual = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMutual = false);
    }
  }

  IconData _iconForStyle(String style) {
    switch (style) {
      case 'Curtas':
        return Icons.route_outlined;
      case 'Longas':
        return Icons.map_outlined;
      case 'Rolês':
        return Icons.groups_outlined;
      default:
        return Icons.two_wheeler;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
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

                // ── Estilo de viagem preferido ───────────────────────
                if (user.tripStyle != null && user.tripStyle!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estilo de viagem preferido',
                              style: AppTextStyles.headlineMedium
                                  .copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.inputFill,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_iconForStyle(user.tripStyle!),
                                    size: 16, color: AppColors.navy),
                                const SizedBox(width: 8),
                                Text(
                                  user.tripStyle!,
                                  style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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

                // ── Amigos em comum ──────────────────────────────────
                _MutualFriendsSection(
                  loading: _loadingMutual,
                  friends: _mutualFriends,
                ),

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

class _MutualFriendsSection extends StatefulWidget {
  final bool loading;
  final List<UserModel> friends;
  const _MutualFriendsSection({
    required this.loading,
    required this.friends,
  });

  @override
  State<_MutualFriendsSection> createState() => _MutualFriendsSectionState();
}

class _MutualFriendsSectionState extends State<_MutualFriendsSection> {
  static const _previewLimit = 6;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: AppSpacing.md),
        child: Row(
          children: [
            Text(
              'Amigos em comum',
              style: AppTextStyles.headlineMedium
                  .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 12),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.navy),
            ),
          ],
        ),
      );
    }

    if (widget.friends.isEmpty) return const SizedBox(height: AppSpacing.md);

    final total = widget.friends.length;
    final visible = _showAll
        ? widget.friends
        : widget.friends.take(_previewLimit).toList();
    final hasMore = total > _previewLimit && !_showAll;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Amigos em comum',
                style: AppTextStyles.headlineMedium
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: AppColors.teal),
                ),
                child: Text(
                  '$total',
                  style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.teal, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: visible
                .map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () =>
                            context.push('/profile/${f.id}', extra: f),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        child: Row(
                          children: [
                            AppAvatar(
                              name: f.name,
                              imageUrl: f.avatarUrl,
                              size: 40,
                              showOnline: true,
                              isOnline: f.isOnline,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(f.name,
                                      style: AppTextStyles.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  if (f.username.isNotEmpty)
                                    Text('@${f.username}',
                                        style: AppTextStyles.bodySmall
                                            .copyWith(
                                                color: AppColors.textMuted),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: TextButton(
                onPressed: () => setState(() => _showAll = true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  'Ver todos ($total)',
                  style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.navy, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
