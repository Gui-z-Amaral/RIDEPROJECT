import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/stop_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/utils/extensions.dart';
import '../viewmodels/trip_viewmodel.dart';
import '../../active_session/viewmodels/active_session_viewmodel.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TripViewModel>().clearForLoad();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TripViewModel>().loadTripById(widget.tripId);
    });
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final vm = context.read<TripViewModel>();
    final trip = vm.selectedTrip;
    if (trip == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir viagem'),
        content: Text('Deseja excluir "${trip.title}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await vm.deleteTrip(trip.id);
      if (context.mounted) context.go('/home');
    }
  }

  /// Criador pode editar apenas viagens ainda planejadas (não iniciadas/concluídas).
  bool _canEdit(TripModel trip) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    return trip.creator.id == myId && trip.status == TripStatus.planned;
  }

  Future<void> _openMaps(TripModel trip) async {
    final url = trip.buildGoogleMapsUrl();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TripViewModel>();
    // Só considera a viagem válida se o ID bate com o que foi solicitado
    final trip = vm.selectedTrip?.id == widget.tripId ? vm.selectedTrip : null;

    // Mostra loading enquanto: carregando detalhes, ou viagem ainda não chegou (e sem erro)
    if (vm.isLoadingDetail || (trip == null && !vm.hasError)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: const LoadingWidget(),
      );
    }

    if (trip == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppColors.navy),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Não foi possível carregar a viagem.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.read<TripViewModel>().loadTripById(widget.tripId),
                child: const Text('Tentar novamente', style: TextStyle(color: AppColors.navy)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            }),
            actions: [
              if (_canEdit(trip)) ...[
                IconButton(
                  tooltip: 'Editar viagem',
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  onPressed: () => context.push('/trips/${trip.id}/edit'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => _confirmDelete(context),
                ),
              ] else if (trip.creator.id ==
                  Supabase.instance.client.auth.currentUser?.id)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  onPressed: () => _confirmDelete(context),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(trip.title, style: AppTextStyles.headlineSmall),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.mediumBlue, AppColors.darkNavy], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: const Center(child: Icon(Icons.map, size: 80, color: AppColors.teal)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & route type
                  Row(
                    children: [
                      _InfoChip(label: trip.statusLabel, color: AppColors.teal),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Date & distance
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppSpacing.radiusLg), border: Border.all(color: AppColors.divider)),
                    child: Column(
                      children: [
                        if (trip.scheduledAt != null)
                          _InfoRow(icon: Icons.calendar_today, label: 'Data', value: '${trip.scheduledAt!.relativeLabel} às ${trip.scheduledAt!.formattedTime}'),
                        if (trip.estimatedDistance != null) ...[
                          const Divider(height: AppSpacing.lg),
                          _InfoRow(icon: Icons.straighten, label: 'Distância', value: trip.estimatedDistance!.formattedKm),
                        ],
                        if (trip.estimatedDuration != null) ...[
                          const Divider(height: AppSpacing.lg),
                          _InfoRow(icon: Icons.timer_outlined, label: 'Duração est.', value: trip.estimatedDuration!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Route
                  Text('Rota', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppSpacing.radiusLg), border: Border.all(color: AppColors.divider)),
                    child: Column(
                      children: [
                        _RoutePoint(icon: Icons.radio_button_on, color: AppColors.teal, label: trip.origin.address ?? 'Origem', sublabel: 'Partida'),
                        ...trip.waypoints.asMap().entries.map((e) => _RoutePoint(icon: Icons.place, color: AppColors.warning, label: e.value.address ?? 'Parada ${e.key + 1}', sublabel: 'Parada')),
                        _RoutePoint(icon: Icons.location_on, color: AppColors.error, label: trip.destination.address ?? 'Destino', sublabel: 'Chegada'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Map
                  AppMap(
                    height: 160,
                    center: trip.origin,
                    markers: [trip.origin, trip.destination, ...trip.waypoints],
                    routePoints: [trip.origin, ...trip.waypoints, trip.destination],
                    interactive: false,
                    onTap: () => _openMaps(trip),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Participants
                  Text('Participantes', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  ...trip.participants.map((u) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: [
                            AppAvatar(name: u.name, imageUrl: u.avatarUrl, size: 40),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(u.name, style: AppTextStyles.titleMedium),
                                  Text(u.motoModel ?? '', style: AppTextStyles.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),

                  if (trip.stops.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text('Paradas', style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppSpacing.md),
                    ...trip.stops.map((s) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: StopCard(stop: s, horizontal: false))),
                  ],

                  const SizedBox(height: AppSpacing.xxl),

                  if (trip.status == TripStatus.planned) ...[
                    AppButton(
                      label: 'Ver rota no Google Maps',
                      icon: Icons.map,
                      variant: AppButtonVariant.outline,
                      onPressed: () => _openMaps(trip),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Iniciar Viagem',
                      icon: Icons.play_arrow,
                      onPressed: () {
                        context.read<ActiveSessionViewModel>().startSession(
                          id: trip.id,
                          title: trip.title,
                          isRide: false,
                          participants: trip.participants,
                        );
                        context.push('/session/waiting/${trip.id}');
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(label, style: AppTextStyles.labelMedium.copyWith(color: color)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTextStyles.bodyMedium),
        const Spacer(),
        Text(value, style: AppTextStyles.titleMedium.copyWith(color: AppColors.lightCyan)),
      ],
    );
  }
}

class _RoutePoint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sublabel;
  const _RoutePoint({required this.icon, required this.color, required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary)),
                Text(sublabel, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
