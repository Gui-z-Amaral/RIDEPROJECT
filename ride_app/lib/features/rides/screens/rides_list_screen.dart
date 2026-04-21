import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/services/supabase_ride_service.dart';
import '../viewmodels/ride_viewmodel.dart';
import '../../notifications/viewmodels/notifications_viewmodel.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

const _rideAccent = Color(0xFF9C6FE4);

class RidesListScreen extends StatefulWidget {
  const RidesListScreen({super.key});

  @override
  State<RidesListScreen> createState() => _RidesListScreenState();
}

class _RidesListScreenState extends State<RidesListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final rideVm = context.read<RideViewModel>();
      rideVm.loadRides();
      rideVm.loadHistory();
      context.read<NotificationsViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RideViewModel>();
    final notifVm = context.watch<NotificationsViewModel>();
    final user = context.watch<AuthViewModel>().user;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final upcoming = vm.rides
        .where((r) =>
            r.status == RideStatus.scheduled ||
            r.status == RideStatus.waiting)
        .toList();
    final active = vm.activeUserRides;
    final history = vm.history;
    final invites = notifVm.notifications
        .where((n) => n.type == 'ride_invite' && !n.isRead)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: _rideAccent,
        onRefresh: () async {
          await Future.wait([
            vm.loadRides(),
            vm.loadHistory(),
            notifVm.load(),
          ]);
        },
        child: CustomScrollView(
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
                  Text('HOME',
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

            if (vm.isLoading && vm.rides.isEmpty)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: _rideAccent)),
              )
            else ...[
              // ── PRÓXIMO ROLÊ ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                  child: Text(
                    'PROXIMO ROLÊ',
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
                      message: 'Nenhum rolê agendado',
                      onNew: () => context.push('/rides/create'),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: _NextRideCard(ride: upcoming.first),
                  ),
                ),

              // ── ROLÊS ATIVOS ──────────────────────────────────
              if (active.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                    child: Row(
                      children: [
                        Text(
                          'ROLÊS ATIVOS',
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${active.length} AO VIVO',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                          AppSpacing.lg, AppSpacing.md),
                      child: _ActiveRideCard(
                        entry: active[i],
                        onRejoin: () => context.push(
                          '/session/active/${active[i].rideId}',
                          extra: {'isRide': true},
                        ),
                      ),
                    ),
                    childCount: active.length,
                  ),
                ),
              ],

              // ── CONVITES ──────────────────────────────────────
              if (invites.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                    child: Row(
                      children: [
                        Text(
                          'CONVITES',
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _rideAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${invites.length}',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _rideAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                          AppSpacing.lg, AppSpacing.md),
                      child: _InviteCard(
                        notif: invites[i],
                        onTap: () =>
                            _showRideInviteSheet(context, invites[i]),
                      ),
                    ),
                    childCount: invites.length,
                  ),
                ),
              ],

              // ── ROLÊS ANTERIORES ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.sm),
                  child: Row(
                    children: [
                      Text(
                        'ROLÊS ANTERIORES',
                        style: AppTextStyles.headlineLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      _OutlineBtn(
                        label: 'NOVO ROLÊ',
                        onTap: () => context.push('/rides/create'),
                      ),
                    ],
                  ),
                ),
              ),

              if (history.isEmpty)
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
                      child: Text('Nenhum rolê anterior',
                          style: AppTextStyles.bodyMedium),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                          AppSpacing.lg, AppSpacing.md),
                      child: _HistoryCard(entry: history[i]),
                    ),
                    childCount: history.length,
                  ),
                ),

              SliverToBoxAdapter(
                  child: SizedBox(height: bottomPad + 100)),
            ],
          ],
        ),
      ),
    );
  }

  void _showRideInviteSheet(BuildContext context, NotificationModel notif) {
    final rideId = notif.data['rideId'] as String?;
    final place = notif.data['place'] as String? ?? notif.title;
    final address = notif.data['address'] as String? ?? '';

    context.read<NotificationsViewModel>().markAsRead(notif.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (sheetCtx) => _RideInviteSheet(
        place: place,
        address: address,
        body: notif.body,
        onAccept: rideId == null
            ? null
            : () async {
                Navigator.pop(sheetCtx);
                try {
                  await SupabaseRideService.confirmParticipation(rideId);
                  if (context.mounted) {
                    await context.read<RideViewModel>().loadRides();
                    await context.read<RideViewModel>().loadHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Você aceitou o convite!'),
                        backgroundColor: _rideAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (_) {}
              },
        onDecline: rideId == null
            ? null
            : () async {
                Navigator.pop(sheetCtx);
                try {
                  await SupabaseRideService.declineParticipation(rideId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Convite recusado.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (_) {}
              },
      ),
    );
  }
}

// ─── Próximo rolê (card grande) ───────────────────────────────────────────────

class _NextRideCard extends StatelessWidget {
  final RideModel ride;
  const _NextRideCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.navy,
                    _rideAccent.withOpacity(0.6),
                    AppColors.teal.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(Icons.groups,
                        color: Colors.white.withOpacity(0.18), size: 80),
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
                        ride.statusLabel.toUpperCase(),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ride.meetingPoint.address != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ride.meetingPoint.address!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.people_outline,
                        label:
                            '${ride.participants.length} participante(s)'),
                    const SizedBox(width: 10),
                    if (ride.scheduledAt != null)
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: _formatDate(ride.scheduledAt!),
                      )
                    else if (ride.isImmediate)
                      const _InfoChip(
                          icon: Icons.flash_on, label: 'Agora'),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push('/rides/${ride.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'VER ROLÊ',
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

// ─── Rolê ativo (card menor) ──────────────────────────────────────────────────

class _ActiveRideCard extends StatelessWidget {
  final RideHistoryEntry entry;
  final VoidCallback onRejoin;
  const _ActiveRideCard({required this.entry, required this.onRejoin});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRejoin,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _rideAccent.withOpacity(0.2),
              AppColors.navy,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _rideAccent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 80, height: 90,
              decoration: BoxDecoration(
                color: _rideAccent.withOpacity(0.25),
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14)),
              ),
              child: const Icon(Icons.groups,
                  color: Colors.white, size: 36),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'EM ANDAMENTO',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.meetingName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.meetingName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'VOLTAR',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Convite (card menor) ─────────────────────────────────────────────────────

class _InviteCard extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  const _InviteCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final place = notif.data['place'] as String? ?? notif.title;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _rideAccent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _rideAccent.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _rideAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_outlined,
                  color: _rideAccent, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(notif.body,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _rideAccent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                'RESPONDER',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rolê anterior (histórico) ────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final RideHistoryEntry entry;
  const _HistoryCard({required this.entry});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd/MM/yy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/rides/${entry.rideId}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              child: Container(
                width: 110,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.mediumBlue,
                      _rideAccent.withOpacity(0.5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(Icons.groups_outlined,
                    color: Colors.white.withOpacity(0.3), size: 40),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (entry.meetingName.isNotEmpty)
                      Text(
                        entry.meetingName,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 11,
                            color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(
                              entry.startedAt ?? entry.createdAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                        if (entry.durationLabel.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.timer_outlined,
                              size: 11,
                              color: Colors.white.withOpacity(0.6)),
                          const SizedBox(width: 4),
                          Text(
                            entry.durationLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
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

// ─── Sheet de convite de rolê ─────────────────────────────────────────────────

class _RideInviteSheet extends StatelessWidget {
  final String place;
  final String address;
  final String body;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _RideInviteSheet({
    required this.place,
    required this.address,
    required this.body,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _rideAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups, color: _rideAccent, size: 32),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Convite para rolê', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(body,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.location_on,
                      size: 14, color: _rideAccent),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(place,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
                ]),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const SizedBox(width: 22),
                    Expanded(
                        child: Text(address,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull)),
                  ),
                  child: Text('Recusar',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.error)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rideAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull)),
                    elevation: 0,
                  ),
                  child: Text('Aceitar',
                      style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
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
          border: Border.all(color: _rideAccent, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: _rideAccent,
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
            Icon(Icons.groups_outlined,
                color: _rideAccent.withOpacity(0.5), size: 40),
            const SizedBox(height: 10),
            Text(message, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 6),
            Text('Toque para criar',
                style: AppTextStyles.bodySmall
                    .copyWith(color: _rideAccent)),
          ],
        ),
      ),
    );
  }
}
