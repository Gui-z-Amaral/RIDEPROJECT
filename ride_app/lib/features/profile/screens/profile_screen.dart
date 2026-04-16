import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../social/viewmodels/social_viewmodel.dart';
import '../../trips/viewmodels/trip_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ProfileViewModel>().load();
      context.read<SocialViewModel>().loadFriends();
      context.read<TripViewModel>().loadTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();
    final socialVm = context.watch<SocialViewModel>();
    final tripVm = context.watch<TripViewModel>();
    final user = vm.user;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
            pinned: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.navy),
                onPressed: () async {
                  await context.read<AuthViewModel>().logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Avatar + nome ───────────────────────────────
                const SizedBox(height: 8),
                CircleAvatar(
                  radius: 52,
                  backgroundColor: AppColors.navy.withOpacity(0.1),
                  backgroundImage: user?.avatarUrl != null
                      ? NetworkImage(user!.avatarUrl!)
                      : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          (user?.name.isNotEmpty == true)
                              ? user!.name[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  (user?.name ?? '').toUpperCase(),
                  style: AppTextStyles.headlineLarge
                      .copyWith(fontWeight: FontWeight.w800, fontSize: 20),
                ),
                if (user?.username.isNotEmpty == true)
                  Text('@${user!.username}',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 20),

                // ── Stats 2x2 ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _StatBox(
                          value: '${user?.tripsCount ?? 0}',
                          label: 'Viagens\ncriadas'),
                      const SizedBox(width: 12),
                      _StatBox(value: '0', label: 'Rolês'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _StatBox(
                          value: '${user?.friendsCount ?? 0}',
                          label: 'Amigos\nadicionados'),
                      const SizedBox(width: 12),
                      _StatBox(value: '0', label: 'Viagens\nconcluídas'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Editar perfil button ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.push('/profile/edit'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.navy, width: 1.5),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('EDITAR PERFIL',
                          style: AppTextStyles.labelMedium
                              .copyWith(color: AppColors.navy,
                                  fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(height: 1),

                // ── Bio ────────────────────────────────────────
                if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio',
                            style: AppTextStyles.headlineMedium
                                .copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(user.bio!,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary,
                                    height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                ],

                // ── Seus contatos ─────────────────────────────
                if (socialVm.friends.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Seus Contatos',
                            style: AppTextStyles.headlineMedium
                                .copyWith(fontWeight: FontWeight.w800)),
                        GestureDetector(
                          onTap: () => context.push('/friends'),
                          child: Text('Ver todos',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.navy)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: socialVm.friends.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                      itemBuilder: (_, i) =>
                          _ContactCard(user: socialVm.friends[i]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                ],

                // ── Suas fotos ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Suas Fotos',
                          style: AppTextStyles.headlineMedium
                              .copyWith(fontWeight: FontWeight.w800)),
                      GestureDetector(
                        onTap: () {},
                        child: Text('Ver Todas',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.navy)),
                      ),
                    ],
                  ),
                ),
                if (user?.photos.isEmpty != false)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('Nenhuma foto adicionada',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted)),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: user!.photos.take(6).length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(user.photos[i],
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Divider(height: 1),

                // ── Viagens ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Viagens',
                          style: AppTextStyles.headlineMedium
                              .copyWith(fontWeight: FontWeight.w800)),
                      GestureDetector(
                        onTap: () => context.go('/trips'),
                        child: Text('Ver todas',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.navy)),
                      ),
                    ],
                  ),
                ),
                if (tripVm.trips.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Nenhuma viagem ainda',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...tripVm.trips.take(2).map((t) {
                    final parts =
                        t.destination.address?.split(',') ?? [];
                    final city = parts.isNotEmpty
                        ? parts.first.trim()
                        : t.title;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: GestureDetector(
                        onTap: () => context.push('/trips/${t.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.landscape,
                                  color: Colors.white54, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(city.toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight:
                                                FontWeight.w700,
                                            fontSize: 13)),
                                    if (t.scheduledAt != null)
                                      Text(
                                        '${t.scheduledAt!.day.toString().padLeft(2, '0')}/${t.scheduledAt!.month.toString().padLeft(2, '0')}/${t.scheduledAt!.year}',
                                        style: TextStyle(
                                            color: Colors.white
                                                .withOpacity(0.6),
                                            fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white54, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                SizedBox(height: bottomPad + 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat box ─────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppColors.navy)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

// ─── Contact card ─────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final dynamic user;
  const _ContactCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.navy.withOpacity(0.1),
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl as String)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    (user.name as String).isNotEmpty
                        ? (user.name as String)[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            (user.name as String).split(' ').first,
            style: AppTextStyles.labelSmall
                .copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      context.push('/friends/chat/${user.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Text('MSG',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
