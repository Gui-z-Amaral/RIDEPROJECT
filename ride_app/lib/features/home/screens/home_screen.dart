import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../notifications/viewmodels/notifications_viewmodel.dart';
import '../../social/viewmodels/social_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/supabase_social_service.dart';

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
      _fetchLocationAndRecommend();
      if (mounted) context.read<HomeViewModel>().loadFriendsStories();
    });
  }

  Future<void> _fetchLocationAndRecommend() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.reduced, // rápido, suficiente para recomendações
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        context
            .read<HomeViewModel>()
            .loadRecommendations(pos.latitude, pos.longitude);
      }
    } catch (_) {}
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
                      icon: const Icon(Icons.people_outline,
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
                      icon: const Icon(Icons.notifications_outlined,
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
                  const SizedBox(height: AppSpacing.md),

                  // ── Barra de pesquisa ─────────────────────────────
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pesquise lugares, agendamentos ou pessoas!',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                          ),
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

                  // ── PRÓXIMA VIAGEM ────────────────────────────────
                  _SectionLabel(label: 'PRÓXIMA VIAGEM'),
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
                  _SectionLabel(label: 'PRÓXIMO ROLÊ'),
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
                  _BusinessSection(onTap: () {}),
                  const SizedBox(height: AppSpacing.lg),

                  // ── SUGESTÕES PARA VOCÊ ───────────────────────────
                  Row(
                    children: [
                      _SectionLabel(label: 'SUGESTÕES PARA VOCÊ'),
                      const Spacer(),
                      if (vm.isLoadingRecs)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.navy,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),

          // ── Sugestões (scroll horizontal) ─────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: vm.isLoadingRecs && vm.recommendations.isEmpty
                  ? _SuggestionSkeletons()
                  : vm.recommendations.isEmpty
                      ? _NoRecommendations()
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          itemCount: vm.recommendations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: AppSpacing.md),
                          itemBuilder: (_, i) => _SuggestionCard(
                            place: vm.recommendations[i],
                          ),
                        ),
            ),
          ),

          SliverToBoxAdapter(
              child:
                  SizedBox(height: bottomPad + 100)),
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

// ─── Skeleton de sugestões (loading) ─────────────────────────────────────────

class _SuggestionSkeletons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
      itemBuilder: (_, __) => Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ─── Sem recomendações ────────────────────────────────────────────────────────

class _NoRecommendations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.location_off_outlined,
                color: AppColors.textMuted.withOpacity(0.5), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ative a localização para ver sugestões perto de você',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Suggestion card (real data) ─────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final PlaceRecommendation place;
  const _SuggestionCard({required this.place});

  // Gradiente por tipo quando não há foto
  List<Color> get _gradient {
    switch (place.type) {
      case 'restaurant':
      case 'cafe':
        return [const Color(0xFF6B4E35), const Color(0xFF3D2B1F)];
      case 'gas_station':
        return [AppColors.navy, AppColors.mediumBlue];
      case 'lodging':
        return [const Color(0xFF4A1D6B), const Color(0xFF2D0D4E)];
      default:
        return [AppColors.navy, AppColors.mediumBlue];
    }
  }

  // Badge de razão da recomendação
  String get _reasonLabel {
    switch (place.reason) {
      case RecommendationReason.nearbyRestaurant:
      case RecommendationReason.nearbyFuel:
        return '📍 ${place.distanceLabel}';
      case RecommendationReason.nearestFuel:
        return '⛽ Mais próximo';
      case RecommendationReason.nearestLodging:
        return '🏨 Mais próximo';
      case RecommendationReason.tripBased:
        return '🗺️ ${place.tripContext ?? 'Sua viagem'}';
    }
  }

  IconData get _typeIcon {
    switch (place.type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'cafe':
        return Icons.coffee;
      case 'gas_station':
        return Icons.local_gas_station;
      case 'lodging':
        return Icons.hotel;
      default:
        return Icons.place;
    }
  }

  Future<void> _openMaps() async {
    final uri = Uri.parse(place.googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = place.photoUrl.isNotEmpty;

    return GestureDetector(
      onTap: _openMaps,
      child: Container(
        width: 160,
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
              // ── Fundo: foto ou gradiente ──────────────────────────
              if (hasPhoto)
                CachedNetworkImage(
                  imageUrl: place.photoUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(_typeIcon,
                        color: Colors.white.withOpacity(0.12), size: 70),
                  ),
                ),

              // ── Overlay escuro no rodapé ──────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 110,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // ── Badge tipo (topo esquerdo) ────────────────────────
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    place.typeLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              // ── Aberto agora (topo direito) ───────────────────────
              if (place.isOpenNow)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF22C55E), shape: BoxShape.circle),
                  ),
                ),

              // ── Conteúdo (rodapé) ─────────────────────────────────
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rating
                    if (place.rating != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            place.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                          if (place.userRatingsTotal != null) ...[
                            const SizedBox(width: 3),
                            Text(
                              '(${_fmt(place.userRatingsTotal!)})',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 9),
                            ),
                          ],
                        ],
                      ),
                    const SizedBox(height: 3),
                    // Nome
                    Text(
                      place.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Reason badge
                    Text(
                      _reasonLabel,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85), fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Ver no Maps
                    Text(
                      'Ver no Maps →',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
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
                          style: const TextStyle(
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
              gradient: const LinearGradient(
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
            decoration: const BoxDecoration(
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
