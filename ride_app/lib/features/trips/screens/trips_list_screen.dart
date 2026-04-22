import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../../../core/models/trip_model.dart';
import '../../../features/auth/viewmodels/auth_viewmodel.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key});

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TripViewModel>().loadTrips());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TripViewModel>();
    final user = context.watch<AuthViewModel>().user;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final upcoming = vm.trips
        .where((t) =>
            t.status == TripStatus.planned || t.status == TripStatus.active)
        .toList();
    final previous = vm.trips
        .where((t) =>
            t.status == TripStatus.completed ||
            t.status == TripStatus.cancelled)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ─────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppColors.background,
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
                Text('VIAGENS',
                    style: AppTextStyles.headlineMedium
                        .copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppColors.navy),
                  onPressed: () => context.push('/notifications'),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: GestureDetector(
                onTap: () => context.go('/home'),
                child: const Icon(Icons.arrow_back,
                    color: AppColors.navy, size: 26),
              ),
            ),
          ),

          if (vm.isLoading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.navy)),
            )
          else ...[
            // ── PRÓXIMA VIAGEM ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                child: Text(
                  'PROXIMA VIAGEM',
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ),

            if (upcoming.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: _EmptyCard(
                    message: 'Nenhuma viagem planejada',
                    onNew: () => context.push('/trips/create'),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child:
                      _NextTripCard(trip: upcoming.first),
                ),
              ),

            // ── NOVA VIAGEM button ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    Text(
                      'VIAGENS ANTERIORES',
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    _OutlineBtn(
                      label: 'NOVA VIAGEM',
                      onTap: () => context.push('/trips/create'),
                    ),
                  ],
                ),
              ),
            ),

            // ── VIAGENS ANTERIORES ──────────────────────────────
            if (previous.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Nenhuma viagem anterior',
                        style: AppTextStyles.bodyMedium),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: _TripCard(trip: previous[i]),
                  ),
                  childCount: previous.length,
                ),
              ),

            SliverToBoxAdapter(
                child: SizedBox(height: bottomPad + 100)),
          ],
        ],
      ),
    );
  }
}

// ─── Próxima viagem (card grande) ─────────────────────────────────────────────

class _NextTripCard extends StatelessWidget {
  final TripModel trip;
  const _NextTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dest = trip.destination;
    final parts = dest.address?.split(',') ?? [];
    final city = parts.isNotEmpty ? parts.first.trim().toUpperCase() : trip.title.toUpperCase();
    final state = parts.length > 1 ? parts[1].trim() : '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area (gradient placeholder)
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.navy,
                    AppColors.mediumBlue,
                    AppColors.teal.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.landscape,
                        color: Colors.white.withOpacity(0.15), size: 80),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        trip.statusLabel.toUpperCase(),
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
          // Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city + (state.isNotEmpty ? ', $state' : ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.place_outlined,
                        label:
                            '${trip.stops.length + trip.waypoints.length} paradas'),
                    const SizedBox(width: 10),
                    if (trip.scheduledAt != null)
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: _formatDate(trip.scheduledAt!),
                      ),
                    if (trip.estimatedDistance != null) ...[
                      const SizedBox(width: 10),
                      _InfoChip(
                        icon: Icons.straighten,
                        label:
                            '${trip.estimatedDistance!.toStringAsFixed(0)} km',
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        context.push('/trips/${trip.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navy,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'VER VIAGEM',
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.navy),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Viagem anterior (card menor) ─────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final TripModel trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dest = trip.destination;
    final parts = dest.address?.split(',') ?? [];
    final city =
        parts.isNotEmpty ? parts.first.trim().toUpperCase() : trip.title.toUpperCase();
    final state = parts.length > 1 ? parts[1].trim() : '';

    return GestureDetector(
      onTap: () => context.push('/trips/${trip.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Left image
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(14)),
              child: Container(
                width: 110,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.mediumBlue,
                      AppColors.teal.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.landscape,
                    color: Colors.white.withOpacity(0.2), size: 40),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city + (state.isNotEmpty ? ', $state' : ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trip.stops.length + trip.waypoints.length} paradas  •  ${trip.routeTypeLabel}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                    if (trip.participants.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ...trip.participants.take(3).map((p) => Container(
                                width: 22,
                                height: 22,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                child: Center(
                                  child: Text(
                                    p.name.isNotEmpty
                                        ? p.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )),
                          if (trip.participants.length > 3)
                            Text(
                              '+${trip.participants.length - 3}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 10),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.navy, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final VoidCallback onNew;
  const _EmptyCard({required this.message, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onNew,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(Icons.add_road,
                color: AppColors.navy.withOpacity(0.4), size: 40),
            const SizedBox(height: 10),
            Text(message, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 6),
            Text('Toque para criar',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.navy)),
          ],
        ),
      ),
    );
  }
}
