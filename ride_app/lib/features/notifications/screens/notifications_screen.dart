import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../viewmodels/notifications_viewmodel.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../social/viewmodels/social_viewmodel.dart';
import '../../trips/viewmodels/trip_viewmodel.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<NotificationsViewModel>().load());
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationsViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (vm.unreadCount > 0)
            TextButton(
              onPressed: vm.markAllAsRead,
              child: Text(
                'Marcar todas lidas',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.teal),
              ),
            ),
        ],
      ),
      body: vm.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : vm.notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none,
                          color: AppColors.textMuted, size: 56),
                      const SizedBox(height: AppSpacing.md),
                      Text('Nenhuma notificação',
                          style: AppTextStyles.titleMedium
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: vm.notifications.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (_, i) {
                    final notif = vm.notifications[i];
                    return _NotifTile(
                      notif: notif,
                      onTap: () => _handleTap(context, vm, notif),
                    );
                  },
                ),
    );
  }

  Future<void> _handleTap(BuildContext context, NotificationsViewModel vm,
      NotificationModel notif) async {
    if (!notif.isRead) await vm.markAsRead(notif.id);

    if (notif.type == 'friend_request') {
      _showFriendRequestSheet(context, vm, notif);
      return;
    }

    if (notif.type == 'trip_invite') {
      _showTripInviteSheet(context, vm, notif);
      return;
    }
  }

  // ── Bottom sheet: pedido de amizade ───────────────────────────────────────

  void _showFriendRequestSheet(BuildContext context, NotificationsViewModel vm,
      NotificationModel notif) {
    final requestId = notif.data['requestId'] as String?;
    final fromName =
        notif.data['fromName'] as String? ?? 'Alguém';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (sheetCtx) => _FriendRequestSheet(
        fromName: fromName,
        onAccept: requestId == null
            ? null
            : () async {
                Navigator.pop(sheetCtx);
                await context
                    .read<SocialViewModel>()
                    .acceptRequest(requestId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Você e $fromName agora são amigos!'),
                      backgroundColor: AppColors.teal,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
        onReject: requestId == null
            ? null
            : () async {
                Navigator.pop(sheetCtx);
                await context
                    .read<SocialViewModel>()
                    .rejectRequest(requestId);
              },
      ),
    );
  }

  // ── Bottom sheet: convite de viagem ──────────────────────────────────────

  void _showTripInviteSheet(BuildContext context, NotificationsViewModel vm,
      NotificationModel notif) {
    final tripId = notif.data['tripId'] as String?;
    final tripTitle = notif.data['tripTitle'] as String? ?? notif.title;
    final origin = notif.data['originAddress'] as String? ?? '';
    final dest = notif.data['destinationAddress'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (sheetCtx) => _TripInviteSheet(
        tripTitle: tripTitle,
        origin: origin,
        destination: dest,
        body: notif.body,
        onAccept: tripId == null
            ? null
            : () async {
                Navigator.pop(sheetCtx);
                try {
                  await SupabaseTripService.confirmParticipation(tripId);
                  if (context.mounted) {
                    await context.read<TripViewModel>().loadTrips();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Você aceitou o convite!'),
                        backgroundColor: AppColors.teal,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (_) {}
              },
        onDecline: tripId == null
            ? null
            : () async {
                Navigator.pop(sheetCtx);
                try {
                  await SupabaseTripService.declineParticipation(tripId);
                  if (context.mounted) {
                    await context.read<TripViewModel>().loadTrips();
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

// ── Sheet de convite de viagem ─────────────────────────────────────────────────

class _TripInviteSheet extends StatelessWidget {
  final String tripTitle;
  final String origin;
  final String destination;
  final String body;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const _TripInviteSheet({
    required this.tripTitle,
    required this.origin,
    required this.destination,
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.map_outlined, color: AppColors.teal, size: 32),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Convite de Viagem', style: AppTextStyles.headlineSmall),
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
              children: [
                Row(children: [
                  const Icon(Icons.radio_button_on, size: 14, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(child: Text(origin.isNotEmpty ? origin : 'Origem',
                      style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(destination.isNotEmpty ? destination : 'Destino',
                      style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
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
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
                  ),
                  child: Text('Recusar',
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.error)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.deepNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
                    elevation: 0,
                  ),
                  child: Text('Aceitar',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: AppColors.deepNavy, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet com Aceitar / Recusar ─────────────────────────────────────────

class _FriendRequestSheet extends StatelessWidget {
  final String fromName;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _FriendRequestSheet({
    required this.fromName,
    this.onAccept,
    this.onReject,
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.navy.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add_outlined,
                color: AppColors.navy, size: 32),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Pedido de amizade', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$fromName quer se conectar com você.\nDeseja aceitar o convite?',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
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
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    elevation: 0,
                  ),
                  child: Text('Aceitar',
                      style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tile de notificação ────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;

  const _NotifTile({required this.notif, required this.onTap});

  IconData get _icon {
    switch (notif.type) {
      case 'friend_request':
        return Icons.person_add_outlined;
      case 'ride_invite':
        return Icons.groups_outlined;
      case 'trip_invite':
        return Icons.map_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _color {
    switch (notif.type) {
      case 'friend_request':
        return AppColors.navy;
      case 'ride_invite':
        return const Color(0xFF9C6FE4);
      case 'trip_invite':
        return AppColors.teal;
      default:
        return AppColors.lightCyan;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
  }

  @override
  Widget build(BuildContext context) {
    final isFriendReq =
        notif.type == 'friend_request' && !notif.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            notif.isRead ? Colors.transparent : _color.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notif.title,
                            style: AppTextStyles.titleMedium.copyWith(
                                color: notif.isRead
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary)),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: _color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(notif.body,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(_timeAgo(notif.createdAt),
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.textMuted)),
                      if (isFriendReq) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull),
                          ),
                          child: Text('Toque para responder',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.navy)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
