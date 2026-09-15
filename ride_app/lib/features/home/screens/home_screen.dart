import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../notifications/viewmodels/notifications_viewmodel.dart';
import '../../social/viewmodels/social_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/trip_photo_model.dart';
import '../../../core/services/supabase_social_service.dart';
import '../../../shared/widgets/app_avatar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // Carrega viagens/rolês primeiro (para usar destino nas recomendações)
      await context.read<HomeViewModel>().load();
      context.read<NotificationsViewModel>().load();
      context.read<SocialViewModel>().loadRequests();
      if (mounted) {
        context.read<HomeViewModel>().loadFriendsStories();
        context.read<HomeViewModel>().loadFeaturedHighlights();
      }
    });
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'BOM DIA';
    if (h < 18) return 'BOA TARDE';
    return 'BOA NOITE';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final user = context.watch<AuthViewModel>().user;
    final unread = context.watch<NotificationsViewModel>().unreadCount;
    final pendingFriends = context.watch<SocialViewModel>().pendingCount;
    final firstName = (user?.name ?? '').split(' ').first.toUpperCase();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final nextTrip = vm.upcomingTrips.isNotEmpty ? vm.upcomingTrips.first : null;
    final nextRide = vm.upcomingRides.isNotEmpty ? vm.upcomingRides.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.navy.withOpacity(0.1),
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Text(
                            (user?.name.isNotEmpty == true)
                                ? user!.name[0].toUpperCase()
                                : 'U',
                            style: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.navy),
                          )
                        : null,
                  ),
                ),
                const Spacer(),
                Text('HOME',
                    style: AppTextStyles.headlineMedium
                        .copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                // Friends icon with pending-request badge
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.people_outline,
                          color: AppColors.navy),
                      onPressed: () => context.push('/friends/invites'),
                    ),
                    if (pendingFriends > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              pendingFriends > 9 ? '9+' : '$pendingFriends',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Notifications icon
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined,
                          color: AppColors.navy),
                      onPressed: () => context.push('/notifications'),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Saudação ──────────────────────────────────────
                  Text(
                    '${_greeting()} ${firstName.isNotEmpty ? firstName : 'RIDER'} !',
                    style: AppTextStyles.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Veja o que está te esperando na estrada',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── RIDERS PRÓXIMOS ───────────────────────────────
                  GestureDetector(
                    onTap: () => context.push('/riders/nearby'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.near_me,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Riders próximos',
                                    style: AppTextStyles.titleMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                                Text('Encontre motociclistas perto de você',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: Colors.white70)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── NOVIDADES DOS AMIGOS (stories) ────────────────
                  if (vm.isLoadingStories || vm.friendStories.isNotEmpty) ...[
                    _SectionLabel(label: 'NOVIDADES DOS AMIGOS'),
                    const SizedBox(height: AppSpacing.sm),
                    _FriendStoriesStrip(
                      stories: vm.friendStories,
                      isLoading: vm.isLoadingStories,
                      onTapStory: (tripId) =>
                          context.push('/trips/$tripId'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ── DESTAQUES DOS AMIGOS (fotos destacadas) ───────
                  if (vm.featuredHighlights.isNotEmpty) ...[
                    _SectionLabel(label: 'DESTAQUES'),
                    const SizedBox(height: AppSpacing.sm),
                    _HighlightsStrip(
                      highlights: vm.featuredHighlights,
                      onTap: (h) {
                        if (h.tripId != null) {
                          context.push('/trips/${h.tripId}');
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // ── PRÓXIMA VIAGEM ────────────────────────────────
                  _SectionRow(
                    label: 'PRÓXIMA VIAGEM',
                    actionLabel: 'Ver todas',
                    onAction: () => context.go('/trips'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  nextTrip != null
                      ? _NextTripCard(
                          trip: nextTrip,
                          onTap: () => context.push('/trips/${nextTrip.id}'),
                        )
                      : _EmptyCard(
                          icon: Icons.add_road,
                          message: 'Nenhuma viagem planejada',
                          hint: 'Toque para criar uma nova',
                          onTap: () => context.push('/trips/create'),
                        ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── PRÓXIMO ROLÊ ──────────────────────────────────
                  _SectionRow(
                    label: 'PRÓXIMO ROLÊ',
                    actionLabel: 'Ver todos',
                    onAction: () => context.go('/rides'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  nextRide != null
                      ? _NextRideCard(
                          ride: nextRide,
                          onTap: () => context.push('/rides/${nextRide.id}'),
                        )
                      : _EmptyCard(
                          icon: Icons.groups_outlined,
                          message: 'Nenhum rolê agendado',
                          hint: 'Toque para criar um novo',
                          onTap: () => context.push('/rides/create'),
                        ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── CTAs ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _CtaButton(
                          icon: Icons.two_wheeler,
                          label: 'PLANEJAR UMA\nVIAGEM',
                          onTap: () => context.push('/trips/create'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _CtaButton(
                          icon: Icons.groups,
                          label: 'INICIAR UM\nROLÊ',
                          onTap: () => context.push('/rides/create'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── ENCONTRE EMPRESAS ─────────────────────────────
                  _BusinessSection(onTap: () => context.push('/businesses')),
                  SizedBox(height: bottomPad + 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.headlineMedium.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    );
  }
}

/// Cabeçalho de seção com um atalho à direita (ex.: "Ver todas").
class _SectionRow extends StatelessWidget {
  final String label;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionRow({
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SectionLabel(label: label),
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.navy)),
        ),
      ],
    );
  }
}

// ─── Próxima Viagem card ──────────────────────────────────────────────────────

class _NextTripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;
  const _NextTripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dest = trip.destination;
    final parts = dest.address?.split(',') ?? [];
    final city = parts.isNotEmpty
        ? parts.first.trim().toUpperCase()
        : trip.title.toUpperCase();
    final state = parts.length > 1 ? parts[1].trim().toUpperCase() : '';
    final stops = trip.stops.length + trip.waypoints.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.navy,
                      AppColors.mediumBlue,
                      AppColors.teal.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(Icons.landscape,
                          color: Colors.white.withOpacity(0.15), size: 60),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$stops PARADAS',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.isNotEmpty ? '$city, $state' : city,
                          style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                      if (trip.scheduledAt != null)
                        Text(
                          _fmtDate(trip.scheduledAt!),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  if (trip.participants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...trip.participants.take(3).map((p) => Container(
                              width: 24,
                              height: 24,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.navy.withOpacity(0.1),
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  p.name.isNotEmpty
                                      ? p.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: AppColors.navy,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            )),
                        if (trip.participants.length > 3)
                          Text(
                            '+${trip.participants.length - 3}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Clique no card para ver as viagens agendadas com detalhes',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_month(d.month).toUpperCase()}';

  String _month(int m) => const [
        '',
        'JAN',
        'FEV',
        'MAR',
        'ABR',
        'MAI',
        'JUN',
        'JUL',
        'AGO',
        'SET',
        'OUT',
        'NOV',
        'DEZ'
      ][m];
}

// ─── Próximo Rolê card ────────────────────────────────────────────────────────

class _NextRideCard extends StatelessWidget {
  final RideModel ride;
  final VoidCallback onTap;
  const _NextRideCard({required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ride.title.toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (ride.scheduledAt != null) ...[
            Text('HORÁRIO:',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              _fmtDateTime(ride.scheduledAt!),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          Text('AMIGOS CONFIRMADOS:',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ride.participants.isEmpty
              ? Text('Nenhum confirmado ainda',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12))
              : Row(
                  children: [
                    ...ride.participants.take(4).map((p) => Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          child: Center(
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )),
                    if (ride.participants.length > 4)
                      Text('+${ride.participants.length - 4}',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11)),
                  ],
                ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Text('VER DETALHE',
                  style: AppTextStyles.labelMedium
                      .copyWith(color: AppColors.navy, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  $h:$m';
  }
}

// ─── CTA Button ───────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CtaButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Encontre Empresas section ────────────────────────────────────────────────

class _BusinessSection extends StatelessWidget {
  final VoidCallback onTap;
  const _BusinessSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENCONTRE EMPRESAS CONFIÁVEIS',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explore postos de combustível, oficinas mecânica, borracharias e outros comércios confiáveis com base na avaliação deles',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.navy, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COMEÇAR A EXPLORAR',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty card ───────────────────────────────────────────────────────────────

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  final VoidCallback onTap;
  const _EmptyCard(
      {required this.icon,
      required this.message,
      required this.hint,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.navy.withOpacity(0.4), size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: AppTextStyles.bodyMedium),
                Text(hint,
                    style:
                        AppTextStyles.bodySmall.copyWith(color: AppColors.navy)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Friend Stories Strip ─────────────────────────────────────────────────────

class _FriendStoriesStrip extends StatelessWidget {
  final List<FriendTripStory> stories;
  final bool isLoading;
  final void Function(String tripId) onTapStory;

  const _FriendStoriesStrip({
    required this.stories,
    required this.isLoading,
    required this.onTapStory,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && stories.isEmpty) {
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          itemBuilder: (_, __) => const _StoryItemSkeleton(),
        ),
      );
    }

    // Every 5th slot (index % 5 == 4) is an ad; others are stories
    final total = stories.length + stories.length ~/ 4;
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        itemBuilder: (_, i) {
          final isAd = (i + 1) % 5 == 0;
          if (isAd) return const _AdStoryItem();
          final storyIdx = i - i ~/ 5;
          if (storyIdx >= stories.length) return const SizedBox.shrink();
          final story = stories[storyIdx];
          return _StoryItem(
            story: story,
            onTap: () => onTapStory(story.tripId),
          );
        },
      ),
    );
  }
}

class _StoryItem extends StatelessWidget {
  final FriendTripStory story;
  final VoidCallback onTap;
  const _StoryItem({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.teal, width: 2.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.5),
                child: CircleAvatar(
                  backgroundColor: AppColors.navy.withOpacity(0.1),
                  backgroundImage: story.friend.avatarUrl != null
                      ? NetworkImage(story.friend.avatarUrl!)
                      : null,
                  child: story.friend.avatarUrl == null
                      ? Text(
                          story.friend.name.isNotEmpty
                              ? story.friend.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: AppColors.navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              story.friend.name.split(' ').first,
              style: AppTextStyles.labelSmall
                  .copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              story.tripTitle,
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textMuted, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdStoryItem extends StatelessWidget {
  const _AdStoryItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.navy, AppColors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.teal, width: 2),
            ),
            child: const Icon(Icons.two_wheeler,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 5),
          Text(
            'RideApp',
            style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.navy),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
          Text(
            'Publicidade',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.textMuted, fontSize: 9),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Featured Highlights Strip ────────────────────────────────────────────────

class _HighlightsStrip extends StatelessWidget {
  final List<FeaturedPhotoModel> highlights;
  final void Function(FeaturedPhotoModel) onTap;
  const _HighlightsStrip({required this.highlights, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: highlights.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          final h = highlights[i];
          return GestureDetector(
            onTap: () => onTap(h),
            child: Container(
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: h.photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.inputFill,
                        child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.navy),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.inputFill,
                        child: Icon(Icons.broken_image,
                            color: AppColors.textMuted),
                      ),
                    ),
                    // Overlay gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Star badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: AppColors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.star,
                            color: AppColors.deepNavy, size: 14),
                      ),
                    ),
                    // Footer (avatar + name)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        children: [
                          AppAvatar(
                            name: h.user.name,
                            imageUrl: h.user.avatarUrl,
                            size: 28,
                            profileOf: h.user,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              h.user.name.split(' ').first,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


class _StoryItemSkeleton extends StatelessWidget {
  const _StoryItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.shimmerBase,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 44,
            height: 9,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
