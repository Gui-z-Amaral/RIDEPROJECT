import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../rides/viewmodels/ride_viewmodel.dart';
import '../../trips/viewmodels/trip_viewmodel.dart';

/// Histórico completo de rolês e viagens do usuário, com a opção de remover
/// cada item do perfil. Acessível pelas Configurações.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAll);
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    await Future.wait([
      context.read<RideViewModel>().loadHistory(),
      context.read<TripViewModel>().loadTrips(),
    ]);
  }

  String get _myId => Supabase.instance.client.auth.currentUser?.id ?? '';

  // ── Remoções ─────────────────────────────────────────────────
  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remover',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _removeRide(RideHistoryEntry e) async {
    final isOwner = e.creatorId != null && e.creatorId == _myId;
    final ok = await _confirm(
      isOwner ? 'Excluir rolê' : 'Remover do perfil',
      isOwner
          ? 'Excluir "${e.title}" para todos os participantes?'
          : 'Remover "${e.title}" do seu histórico?',
    );
    if (!ok || !mounted) return;
    await context.read<RideViewModel>().removeFromHistory(e.rideId,
        isOwner: isOwner);
  }

  Future<void> _removeTrip(TripModel t) async {
    final isOwner = t.creator.id == _myId;
    final ok = await _confirm(
      isOwner ? 'Excluir viagem' : 'Remover do perfil',
      isOwner
          ? 'Excluir "${t.title}" para todos os participantes?'
          : 'Remover "${t.title}" do seu histórico?',
    );
    if (!ok || !mounted) return;
    final vm = context.read<TripViewModel>();
    if (isOwner) {
      await vm.deleteTrip(t.id);
    } else {
      await vm.leaveTrip(t.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rideVm = context.watch<RideViewModel>();
    final tripVm = context.watch<TripViewModel>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Rolês: ativos + histórico (todos os que o usuário participou).
    final rides = <RideHistoryEntry>[
      ...rideVm.activeUserRides,
      ...rideVm.history,
    ];

    // Viagens onde sou criador ou participante.
    final trips = tripVm.trips.where((t) {
      return t.creator.id == _myId ||
          t.participants.any((p) => p.id == _myId);
    }).toList();

    final loading = rideVm.isHistoryLoading || tripVm.isLoading;
    final isEmpty = !loading && rides.isEmpty && trips.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text('Histórico',
            style: AppTextStyles.headlineSmall
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: AppColors.navy,
        onRefresh: _loadAll,
        child: loading && rides.isEmpty && trips.isEmpty
            ? Center(
                child: CircularProgressIndicator(color: AppColors.navy))
            : isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      _EmptyState(),
                    ],
                  )
                : ListView(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 24),
                    children: [
                      if (rides.isNotEmpty) ...[
                        const _SectionLabel('ROLÊS'),
                        const SizedBox(height: 8),
                        ...rides.map((e) => _RideHistoryTile(
                              entry: e,
                              onOpen: () => context.push('/rides/${e.rideId}'),
                              onRemove: () => _removeRide(e),
                            )),
                        const SizedBox(height: 24),
                      ],
                      if (trips.isNotEmpty) ...[
                        const _SectionLabel('VIAGENS'),
                        const SizedBox(height: 8),
                        ...trips.map((t) => _TripHistoryTile(
                              trip: t,
                              onOpen: () => context.push('/trips/${t.id}'),
                              onRemove: () => _removeTrip(t),
                            )),
                      ],
                    ],
                  ),
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Ride tile ───────────────────────────────────────────────────────────────

class _RideHistoryTile extends StatelessWidget {
  final RideHistoryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  const _RideHistoryTile({
    required this.entry,
    required this.onOpen,
    required this.onRemove,
  });

  String _statusLabel(RideStatus s) {
    switch (s) {
      case RideStatus.active:
        return 'Em andamento';
      case RideStatus.waiting:
        return 'Aguardando';
      case RideStatus.completed:
        return 'Concluído';
      case RideStatus.cancelled:
        return 'Cancelado';
      case RideStatus.scheduled:
        return 'Agendado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HistoryCard(
      icon: Icons.groups,
      iconColor: const Color(0xFF9C6FE4),
      title: entry.title,
      subtitle: entry.meetingName,
      statusLabel: _statusLabel(entry.status),
      date: entry.startedAt ?? entry.createdAt,
      onOpen: onOpen,
      onRemove: onRemove,
    );
  }
}

// ─── Trip tile ───────────────────────────────────────────────────────────────

class _TripHistoryTile extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  const _TripHistoryTile({
    required this.trip,
    required this.onOpen,
    required this.onRemove,
  });

  String _statusLabel(TripStatus s) {
    switch (s) {
      case TripStatus.active:
        return 'Em andamento';
      case TripStatus.completed:
        return 'Concluída';
      case TripStatus.cancelled:
        return 'Cancelada';
      case TripStatus.planned:
        return 'Planejada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = trip.destination.address?.split(',') ?? [];
    final city = parts.isNotEmpty
        ? parts.first.trim()
        : (trip.destination.label ?? trip.title);
    return _HistoryCard(
      icon: Icons.map_outlined,
      iconColor: AppColors.teal,
      title: trip.title,
      subtitle: city,
      statusLabel: _statusLabel(trip.status),
      date: trip.scheduledAt,
      onOpen: onOpen,
      onRemove: onRemove,
    );
  }
}

// ─── Shared history card ─────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String statusLabel;
  final DateTime? date;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _HistoryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.date,
    required this.onOpen,
    required this.onRemove,
  });

  String? _fmtDate(DateTime? d) {
    if (d == null) return null;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _fmtDate(date);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.titleSmall
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(statusLabel,
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10)),
                        ),
                        if (dateLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(dateLabel,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: AppColors.textMuted, size: 20),
                tooltip: 'Remover do perfil',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.history,
              size: 56, color: AppColors.navy.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('Nenhum rolê ou viagem ainda',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Seu histórico aparecerá aqui',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
