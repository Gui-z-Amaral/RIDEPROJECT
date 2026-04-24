import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/trip_photo_model.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../../core/services/supabase_ride_service.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../viewmodels/active_session_viewmodel.dart';

/// Tela de finalização de viagem/rolê.
/// Mostra trajeto, paradas, participantes e permite enviar fotos —
/// uma delas pode ser destacada (visível por 7 dias para os amigos).
class FinishTripScreen extends StatefulWidget {
  final String sessionId;
  final bool isRide;
  const FinishTripScreen({
    super.key,
    required this.sessionId,
    this.isRide = false,
  });

  @override
  State<FinishTripScreen> createState() => _FinishTripScreenState();
}

class _FinishTripScreenState extends State<FinishTripScreen> {
  bool _loading = true;
  bool _finishing = false;
  TripModel? _trip;
  RideModel? _ride;
  List<TripPhotoModel> _photos = [];
  String? _featuredPhotoUrl;
  final _picker = ImagePicker();
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.isRide) {
        _ride = await SupabaseRideService.getRideById(widget.sessionId);
      } else {
        _trip = await SupabaseTripService.getTripById(widget.sessionId);
        _photos = await SupabaseTripService.getTripPhotos(widget.sessionId);
        final featured = await SupabaseTripService.getMyFeaturedPhoto();
        if (featured != null && featured.tripId == widget.sessionId) {
          _featuredPhotoUrl = featured.photoUrl;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final photo = await SupabaseTripService.uploadTripPhoto(
        widget.sessionId,
        bytes,
        ext == 'jpg' ? 'jpeg' : ext,
      );
      if (mounted) {
        setState(() => _photos = [photo, ..._photos]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar foto: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _toggleFeatured(String photoUrl) async {
    final wasFeatured = _featuredPhotoUrl == photoUrl;
    setState(() => _featuredPhotoUrl = wasFeatured ? null : photoUrl);
    try {
      if (wasFeatured) {
        await SupabaseTripService.clearFeaturedPhoto();
      } else {
        await SupabaseTripService.setFeaturedPhoto(
          tripId: widget.sessionId,
          photoUrl: photoUrl,
        );
      }
    } catch (_) {
      // Rollback on failure
      if (mounted) {
        setState(() => _featuredPhotoUrl = wasFeatured ? photoUrl : null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar destaque. Tente novamente.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _finalize() async {
    setState(() => _finishing = true);
    try {
      if (widget.isRide) {
        await SupabaseRideService.updateStatus(
            widget.sessionId, RideStatus.completed);
      } else {
        await SupabaseTripService.finalizeTrip(widget.sessionId);
      }
      if (mounted) context.read<ActiveSessionViewModel>().endSession();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _finishing = false);
    context.go('/home');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Viagem finalizada!'),
        backgroundColor: AppColors.teal,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }

    final origin = _trip?.origin ?? _ride?.meetingPoint;
    final destination = _trip?.destination;
    final participants = _trip?.participants ?? _ride?.participants ?? [];
    final stops = _trip?.stops ?? const [];
    final waypoints = _trip?.waypoints ?? const [];
    final title = _trip?.title ?? _ride?.title ?? 'Sessão';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Finalizar viagem',
          style: AppTextStyles.headlineMedium
              .copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl + MediaQuery.of(context).padding.bottom),
        children: [
          // ── Cabeçalho ───────────────────────────────────────
          Text(
            title,
            style: AppTextStyles.headlineLarge
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Trajeto ─────────────────────────────────────────
          _SectionLabel(label: 'TRAJETO'),
          const SizedBox(height: AppSpacing.sm),
          _RouteCard(
            origin: origin,
            destination: destination,
            waypoints: waypoints,
            stops: stops,
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Participantes ───────────────────────────────────
          _SectionLabel(label: 'QUEM VIAJOU COM VOCÊ'),
          const SizedBox(height: AppSpacing.sm),
          if (participants.isEmpty)
            Text(
              'Você fez essa viagem sozinho.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            )
          else
            _ParticipantsRow(participants: participants),
          const SizedBox(height: AppSpacing.xl),

          // ── Fotos ──────────────────────────────────────────
          _SectionLabel(label: 'FOTOS DA VIAGEM'),
          const SizedBox(height: 4),
          Text(
            'Adicione fotos. Toque na ⭐ para destacar uma — ela aparecerá '
            'para seus amigos por 7 dias.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          _PhotoGrid(
            photos: _photos,
            featuredUrl: _featuredPhotoUrl,
            uploading: _uploading,
            onAdd: _pickAndUpload,
            onToggleFeature: _toggleFeatured,
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ── Botão finalizar ─────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _finishing ? null : _finalize,
              icon: _finishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.deepNavy,
                      ),
                    )
                  : const Icon(Icons.flag, size: 20),
              label: Text(
                _finishing ? 'FINALIZANDO...' : 'FINALIZAR E SAIR',
                style: AppTextStyles.labelLarge,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.deepNavy,
                disabledBackgroundColor: AppColors.teal.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppTextStyles.titleLarge
            .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
      );
}

// ─── Route card (origem → paradas → destino) ────────────────────────────────

class _RouteCard extends StatelessWidget {
  final LocationModel? origin;
  final LocationModel? destination;
  final List<LocationModel> waypoints;
  final List<dynamic> stops;
  const _RouteCard({
    required this.origin,
    required this.destination,
    required this.waypoints,
    required this.stops,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_RoutePoint>[];
    if (origin != null) {
      items.add(_RoutePoint(
        icon: Icons.trip_origin,
        color: AppColors.success,
        title: 'Saída',
        subtitle: origin!.label ?? origin!.address ?? 'Ponto de partida',
      ));
    }
    for (final w in waypoints) {
      items.add(_RoutePoint(
        icon: Icons.alt_route,
        color: AppColors.teal,
        title: 'Waypoint',
        subtitle: w.label ?? w.address ?? '${w.lat}, ${w.lng}',
      ));
    }
    for (final s in stops) {
      final loc = s.location as LocationModel;
      items.add(_RoutePoint(
        icon: Icons.place,
        color: AppColors.navy,
        title: s.name as String,
        subtitle: loc.label ?? loc.address ?? '${loc.lat}, ${loc.lng}',
      ));
    }
    if (destination != null) {
      items.add(_RoutePoint(
        icon: Icons.flag,
        color: AppColors.error,
        title: 'Destino',
        subtitle:
            destination!.label ?? destination!.address ?? 'Destino final',
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _PointTile(
              point: items[i],
              isLast: i == items.length - 1,
            ),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Sem trajeto registrado.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoutePoint {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  _RoutePoint({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

class _PointTile extends StatelessWidget {
  final _RoutePoint point;
  final bool isLast;
  const _PointTile({required this.point, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical line + dot
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Icon(point.icon, color: point.color, size: 18),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(point.title,
                      style: AppTextStyles.titleMedium
                          .copyWith(fontWeight: FontWeight.w700)),
                  Text(point.subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Participants strip ─────────────────────────────────────────────────────

class _ParticipantsRow extends StatelessWidget {
  final List<UserModel> participants;
  const _ParticipantsRow({required this.participants});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        itemBuilder: (_, i) {
          final p = participants[i];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
              children: [
                AppAvatar(name: p.name, imageUrl: p.avatarUrl, size: 50),
                const SizedBox(height: 6),
                SizedBox(
                  width: 60,
                  child: Text(
                    p.name.split(' ').first,
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Photos grid ────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<TripPhotoModel> photos;
  final String? featuredUrl;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(String url) onToggleFeature;

  const _PhotoGrid({
    required this.photos,
    required this.featuredUrl,
    required this.uploading,
    required this.onAdd,
    required this.onToggleFeature,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        // Add button
        GestureDetector(
          onTap: uploading ? null : onAdd,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: AppColors.navy.withOpacity(0.3),
                style: BorderStyle.solid,
                width: 1.5,
              ),
            ),
            child: Center(
              child: uploading
                  ? const CircularProgressIndicator(
                      color: AppColors.navy, strokeWidth: 2)
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_a_photo,
                            color: AppColors.navy, size: 28),
                        SizedBox(height: 4),
                        Text(
                          'Adicionar',
                          style: TextStyle(
                              color: AppColors.navy, fontSize: 11),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        // Photo tiles
        ...photos.map((p) {
          final isFeatured = p.photoUrl == featuredUrl;
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: CachedNetworkImage(
                  imageUrl: p.photoUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.inputFill,
                    child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.navy),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.inputFill,
                    child: const Icon(Icons.broken_image,
                        color: AppColors.textMuted),
                  ),
                ),
              ),
              if (isFeatured)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.teal, width: 3),
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onToggleFeature(p.photoUrl),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isFeatured
                          ? AppColors.teal
                          : Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFeatured ? Icons.star : Icons.star_border,
                      color: isFeatured ? AppColors.deepNavy : Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
