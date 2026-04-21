import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_map.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/location_model.dart';
import '../../../core/utils/extensions.dart';
import '../viewmodels/ride_viewmodel.dart';
import '../../active_session/viewmodels/active_session_viewmodel.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final vm = context.read<RideViewModel>();
      await vm.loadRideById(widget.rideId);
      if (!mounted) return;
      final ride = vm.selectedRide;
      if (ride != null &&
          (ride.status == RideStatus.active ||
              ride.status == RideStatus.waiting)) {
        context.read<ActiveSessionViewModel>().startActiveTracking(
              widget.rideId,
              isRide: true,
            );
      }
    });
  }

  Future<void> _openMaps(RideModel ride) async {
    final url = ride.buildGoogleMapsUrl(const LocationModel(lat: -27.5954, lng: -48.5480, address: 'Minha localização'));
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RideViewModel>();
    final ride = vm.selectedRide;

    if (vm.isLoading || ride == null) {
      return Scaffold(appBar: AppBar(), body: const LoadingWidget());
    }

    final isCreator = ride.creator.id == 'u1';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
        title: Text(ride.title),
        actions: [
          if (isCreator) IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Row(
              children: [
                _StatusChip(ride.statusLabel, _statusColor(ride.status)),
                const SizedBox(width: AppSpacing.sm),
                if (ride.isImmediate) _StatusChip('Imediato', AppColors.warning),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Meeting point
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppSpacing.radiusLg), border: Border.all(color: AppColors.divider)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ponto de encontro', style: AppTextStyles.titleSmall.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.error, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(ride.meetingPoint.address ?? 'Ponto definido', style: AppTextStyles.titleLarge)),
                    ],
                  ),
                  if (ride.scheduledAt != null) ...[
                    const Divider(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: AppColors.textMuted, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Text('${ride.scheduledAt!.relativeLabel} às ${ride.scheduledAt!.formattedTime}', style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppMap(
              height: 160,
              center: ride.meetingPoint,
              markers: [ride.meetingPoint],
              interactive: false,
              onTap: () => _openMaps(ride),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Participants
            Text('Participantes (${ride.participants.length})', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            ...ride.participants.map((u) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      AppAvatar(name: u.name, imageUrl: u.avatarUrl, size: 40, showOnline: true, isOnline: u.isOnline),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name, style: AppTextStyles.titleMedium),
                            if (u.motoModel != null) Text(u.motoModel!, style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                      if (u.id == ride.creator.id)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(AppSpacing.radiusFull), border: Border.all(color: AppColors.teal)),
                          child: Text('Criador', style: AppTextStyles.labelSmall.copyWith(color: AppColors.teal)),
                        ),
                    ],
                  ),
                )),

            const SizedBox(height: AppSpacing.lg),

            // Live participant map
            if (ride.status == RideStatus.active ||
                ride.status == RideStatus.waiting)
              _LiveParticipantMap(
                rideId: widget.rideId,
                meetingPoint: ride.meetingPoint,
              ),

            const SizedBox(height: AppSpacing.xxl),

            // Actions
            AppButton(
              label: 'Iniciar rota até o ponto de encontro',
              icon: Icons.navigation,
              variant: AppButtonVariant.outline,
              onPressed: () => _openMaps(ride),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isCreator && ride.status == RideStatus.scheduled || ride.status == RideStatus.waiting)
              AppButton(
                label: 'Iniciar Rolê',
                icon: Icons.play_arrow,
                onPressed: () {
                  context.read<ActiveSessionViewModel>().startSession(id: ride.id, title: ride.title, isRide: true);
                  context.push('/session/waiting/${ride.id}');
                },
              ),
            if (!isCreator)
              AppButton(
                label: 'Sair do rolê',
                variant: AppButtonVariant.danger,
                icon: Icons.exit_to_app,
                onPressed: () {
                  MockRideService.leaveRide(ride.id);
                  context.pop();
                },
              ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  Color _statusColor(RideStatus s) {
    switch (s) {
      case RideStatus.active: return AppColors.teal;
      case RideStatus.waiting: return AppColors.warning;
      case RideStatus.completed: return AppColors.success;
      default: return AppColors.textMuted;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(AppSpacing.radiusFull), border: Border.all(color: color)),
      child: Text(label, style: AppTextStyles.labelMedium.copyWith(color: color)),
    );
  }
}

class MockRideService {
  static Future<void> leaveRide(String id) async {}
}

// ─── Mapa de localização em tempo real dos participantes ──────────────────────

class _LiveParticipantMap extends StatefulWidget {
  final String rideId;
  final LocationModel meetingPoint;
  const _LiveParticipantMap({required this.rideId, required this.meetingPoint});

  @override
  State<_LiveParticipantMap> createState() => _LiveParticipantMapState();
}

class _LiveParticipantMapState extends State<_LiveParticipantMap> {
  GoogleMapController? _controller;

  static const _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0d1f3c"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1d2c4d"}]}
]
''';

  Set<Marker> _buildMarkers(List<SessionParticipant> participants) {
    final markers = <Marker>{};

    // Meeting point marker
    markers.add(Marker(
      markerId: const MarkerId('meeting_point'),
      position: LatLng(widget.meetingPoint.lat, widget.meetingPoint.lng),
      infoWindow: InfoWindow(
        title: widget.meetingPoint.label ?? 'Ponto de encontro',
        snippet: widget.meetingPoint.address,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    // Participant markers (only those with actual positions)
    for (int i = 0; i < participants.length; i++) {
      final p = participants[i];
      if (p.lat == 0 && p.lng == 0) continue;
      markers.add(Marker(
        markerId: MarkerId('participant_${p.user.id}'),
        position: LatLng(p.lat, p.lng),
        infoWindow: InfoWindow(
          title: p.user.name,
          snippet: p.user.motoModel,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final sessionVm = context.watch<ActiveSessionViewModel>();
    final participants = sessionVm.participants;
    final markers = _buildMarkers(participants);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Localização em tempo real',
                style: AppTextStyles.headlineSmall),
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: SizedBox(
            height: 220,
            child: GestureDetector(
              onTap: () => context.push(
                '/session/active/${widget.rideId}',
                extra: {'isRide': true},
              ),
              child: AbsorbPointer(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                        widget.meetingPoint.lat, widget.meetingPoint.lng),
                    zoom: 13,
                  ),
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (c) {
                    _controller = c;
                    c.setMapStyle(_mapStyle);
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            'Toque para abrir o mapa completo',
            style:
                AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
