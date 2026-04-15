import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/trip_card.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../notifications/viewmodels/notifications_viewmodel.dart';
import '../../../shared/widgets/ride_card.dart';
import '../../../shared/widgets/stop_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<HomeViewModel>().load();
      context.read<NotificationsViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    final user = context.watch<AuthViewModel>().user;
    final unread = context.watch<NotificationsViewModel>().unreadCount;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppColors.background,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.deepNavy, AppColors.darkNavy],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bom dia, rider!', style: AppTextStyles.bodyMedium),
                                  Text(user?.name ?? 'Rider', style: AppTextStyles.displaySmall),
                                ],
                              ),
                            ),
                            Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_outlined),
                                  onPressed: () => context.push('/notifications'),
                                ),
                                if (unread > 0)
                                  Positioned(
                                    right: 8, top: 8,
                                    child: Container(
                                      width: 18, height: 18,
                                      decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle),
                                      child: Center(
                                        child: Text(
                                          unread > 9 ? '9+' : '$unread',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: vm.isLoading
                ? const Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: LoadingWidget())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      // Quick actions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Row(
                          children: [
                            _QuickAction(icon: Icons.add_road, label: 'Nova Viagem', color: AppColors.teal, onTap: () => context.push('/trips/create')),
                            const SizedBox(width: AppSpacing.md),
                            _QuickAction(icon: Icons.groups, label: 'Novo Rolê', color: AppColors.lightCyan, onTap: () => context.push('/rides/create')),
                            const SizedBox(width: AppSpacing.md),
                            _QuickAction(icon: Icons.explore, label: 'Explorar', color: AppColors.mediumBlue, onTap: () {}),
                            const SizedBox(width: AppSpacing.md),
                            _QuickAction(icon: Icons.people, label: 'Amigos', color: AppColors.warning, onTap: () => context.go('/friends')),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      if (vm.upcomingTrips.isNotEmpty) ...[
                        SectionHeader(title: 'Próximas Viagens', actionLabel: 'Ver todas', onAction: () => context.go('/trips')),
                        SizedBox(
                          height: 230,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                            itemCount: vm.upcomingTrips.length,
                            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                            itemBuilder: (_, i) {
                              final trip = vm.upcomingTrips[i];
                              return SizedBox(width: 280, child: TripCard(trip: trip, onTap: () => context.push('/trips/${trip.id}')));
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                      if (vm.upcomingRides.isNotEmpty) ...[
                        SectionHeader(title: 'Rolês', actionLabel: 'Ver todos', onAction: () => context.go('/rides')),
                        ...vm.upcomingRides.take(2).map((r) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: RideCard(ride: r, onTap: () => context.push('/rides/${r.id}')),
                            )),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      SectionHeader(title: 'Paradas Sugeridas', actionLabel: 'Ver mais', onAction: () {}),
                      SizedBox(
                        height: 180,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          itemCount: vm.suggestedStops.length,
                          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                          itemBuilder: (_, i) => StopCard(stop: vm.suggestedStops[i]),
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

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
