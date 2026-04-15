import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    Future.microtask(() => context.read<RideViewModel>().loadRideById(widget.rideId));
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
