import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/models/ride_model.dart';
import '../viewmodels/ride_viewmodel.dart';

const _rideAccent = Color(0xFF9C6FE4);

class RidesListScreen extends StatefulWidget {
  const RidesListScreen({super.key});

  @override
  State<RidesListScreen> createState() => _RidesListScreenState();
}

class _RidesListScreenState extends State<RidesListScreen> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;
  LatLng? _destination;
  PlaceInfo? _placeInfo;
  bool _locationReady = false;
  bool _geocoding = false;

  static const _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0d1f3c"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.deniedForever &&
          permission != LocationPermission.denied) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
            _locationReady = true;
          });
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_userLocation!, 15),
          );
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _locationReady = true);
  }

  Future<void> _onMapTap(LatLng pos) async {
    setState(() {
      _destination = pos;
      _placeInfo = null;
      _geocoding = true;
    });

    final info = await GeocodingService.reverseGeocode(pos.latitude, pos.longitude);
    if (mounted) {
      setState(() {
        _placeInfo = info ??
            PlaceInfo(
              name: '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
              address: 'Local selecionado no mapa',
            );
        _geocoding = false;
      });
    }
  }

  Set<Marker> get _markers {
    if (_destination == null) return {};
    return {
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination!,
        infoWindow: InfoWindow(
          title: _placeInfo?.name ?? 'Ponto de encontro',
          snippet: _placeInfo?.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final hasDestination = _destination != null;

    return Scaffold(
      body: Stack(
        children: [
          // ── Mapa full-screen ──────────────────────────────────────
          if (!_locationReady)
            Container(
              color: AppColors.darkNavy,
              child: const Center(
                  child: CircularProgressIndicator(color: AppColors.teal)),
            )
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _userLocation ?? const LatLng(-27.5954, -48.5480),
                zoom: 15,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              onMapCreated: (c) {
                _mapController = c;
                c.setMapStyle(_mapStyle);
              },
              onTap: _onMapTap,
            ),

          // ── Barra superior ────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchBar(
                        text: _placeInfo?.name ??
                            (_geocoding
                                ? 'Buscando local...'
                                : 'Toque no mapa para definir ponto de encontro'),
                        hasValue: _placeInfo != null,
                        loading: _geocoding,
                        accentColor: _rideAccent,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _FloatingBtn(
                      icon: Icons.list_alt,
                      onTap: () => _showHistory(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Botão minha localização ───────────────────────────────
          Positioned(
            right: AppSpacing.md,
            bottom: hasDestination ? 220 + bottomPad : 110 + bottomPad,
            child: _FloatingBtn(
              icon: Icons.my_location,
              onTap: () {
                if (_userLocation != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_userLocation!, 15),
                  );
                }
              },
            ),
          ),

          // ── Painel inferior ───────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _destination == null
                ? _HintPanel(
                    icon: Icons.groups_outlined,
                    text: 'Toque no mapa para definir o ponto de encontro do rolê',
                    accentColor: _rideAccent,
                    bottomPad: bottomPad,
                  )
                : _PlaceInfoPanel(
                    place: _placeInfo,
                    loading: _geocoding,
                    accentColor: _rideAccent,
                    actionLabel: 'Iniciar Rolê',
                    actionIcon: Icons.groups,
                    bottomPad: bottomPad,
                    onClear: () =>
                        setState(() { _destination = null; _placeInfo = null; }),
                    onStart: () {
                      if (_destination == null || _placeInfo == null) return;
                      context.push('/rides/start', extra: {
                        'lat': _destination!.latitude,
                        'lng': _destination!.longitude,
                        'name': _placeInfo!.name,
                        'address': _placeInfo!.address,
                      });
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showHistory(BuildContext context) {
    context.read<RideViewModel>().loadHistory();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => _RideHistorySheet(
        onCreateNew: () { Navigator.pop(context); context.push('/rides/create'); },
        onRejoin: (rideId) { Navigator.pop(context); context.push('/session/active/$rideId', extra: {'isRide': true}); },
      ),
    );
  }

  @override
  void dispose() { _mapController?.dispose(); super.dispose(); }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final String text;
  final bool hasValue;
  final bool loading;
  final Color accentColor;
  const _SearchBar({required this.text, required this.hasValue, this.loading = false, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
      ),
      child: Row(
        children: [
          if (loading)
            SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: accentColor))
          else
            const Icon(Icons.search, color: AppColors.textMuted, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: hasValue ? accentColor : AppColors.textMuted),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _FloatingBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FloatingBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.95),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
        ),
        child: Icon(icon, color: AppColors.teal, size: 20),
      ),
    );
  }
}

class _HintPanel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accentColor;
  final double bottomPad;
  const _HintPanel({required this.icon, required this.text, required this.accentColor, required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.97),
        border: const Border(top: BorderSide(color: AppColors.divider)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg, right: AppSpacing.lg,
        top: AppSpacing.lg, bottom: bottomPad + AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withOpacity(0.3)),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _PlaceInfoPanel extends StatelessWidget {
  final PlaceInfo? place;
  final bool loading;
  final Color accentColor;
  final String actionLabel;
  final IconData actionIcon;
  final double bottomPad;
  final VoidCallback onClear;
  final VoidCallback onStart;

  const _PlaceInfoPanel({
    required this.place, required this.loading,
    required this.accentColor, required this.actionLabel,
    required this.actionIcon, required this.bottomPad,
    required this.onClear, required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.97),
        border: const Border(top: BorderSide(color: AppColors.divider)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg, right: AppSpacing.lg,
        top: AppSpacing.md, bottom: bottomPad + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: loading
                    ? Center(child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)))
                    : Icon(Icons.location_on, color: accentColor, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: loading
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(height: 16, width: 180,
                            decoration: BoxDecoration(color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 6),
                        Container(height: 12, width: 120,
                            decoration: BoxDecoration(color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4))),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(place?.name ?? '', style: AppTextStyles.titleLarge,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (place?.category != null) ...[
                          const SizedBox(height: 2),
                          Text(place!.category!,
                              style: AppTextStyles.labelSmall.copyWith(color: accentColor)),
                        ],
                        const SizedBox(height: 2),
                        Text(place?.address ?? '',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
              ),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: AppColors.deepNavy,
                disabledBackgroundColor: accentColor.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
                elevation: 0,
              ),
              icon: Icon(actionIcon, size: 20),
              label: Text(actionLabel,
                  style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.deepNavy, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideHistorySheet extends StatelessWidget {
  final VoidCallback onCreateNew;
  final void Function(String rideId) onRejoin;

  const _RideHistorySheet({required this.onCreateNew, required this.onRejoin});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd/MM/yy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Consumer<RideViewModel>(
      builder: (ctx, vm, _) {
        final active = vm.activeUserRides;
        final hist = vm.history;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Column(
            children: [
              // Handle + header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: Column(
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Icon(Icons.groups_outlined, color: _rideAccent),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Rolês', style: AppTextStyles.headlineSmall),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: onCreateNew,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Novo rolê'),
                          style: TextButton.styleFrom(
                              foregroundColor: _rideAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 16, color: AppColors.divider),
              Expanded(
                child: vm.isHistoryLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _rideAccent))
                    : (active.isEmpty && hist.isEmpty)
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.groups_outlined,
                                      color: AppColors.textMuted, size: 48),
                                  const SizedBox(height: AppSpacing.md),
                                  Text('Nenhum rolê ainda',
                                      style: AppTextStyles.titleMedium.copyWith(
                                          color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollCtrl,
                            padding: EdgeInsets.only(
                                bottom: bottomPad + AppSpacing.lg),
                            children: [
                              if (active.isNotEmpty) ...[
                                _SectionHeader(
                                    label: 'Em andamento',
                                    color: _rideAccent),
                                ...active.map((e) => _ActiveRideTile(
                                      entry: e,
                                      onRejoin: () => onRejoin(e.rideId),
                                    )),
                              ],
                              if (hist.isNotEmpty) ...[
                                _SectionHeader(
                                    label: 'Histórico',
                                    color: AppColors.textMuted),
                                ...hist.map((e) => _HistoryTile(
                                      entry: e,
                                      formatDate: _formatDate,
                                    )),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Text(label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
              color: color, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActiveRideTile extends StatelessWidget {
  final RideHistoryEntry entry;
  final VoidCallback onRejoin;
  const _ActiveRideTile({required this.entry, required this.onRejoin});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
            color: _rideAccent.withOpacity(0.12), shape: BoxShape.circle),
        child: const Icon(Icons.groups, color: _rideAccent, size: 22),
      ),
      title: Text(entry.title, style: AppTextStyles.titleMedium),
      subtitle: Text(entry.meetingName,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: ElevatedButton(
        onPressed: onRejoin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _rideAccent,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppSpacing.radiusFull)),
          elevation: 0,
        ),
        child: Text('Voltar',
            style: AppTextStyles.labelSmall
                .copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final RideHistoryEntry entry;
  final String Function(DateTime?) formatDate;
  const _HistoryTile({required this.entry, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
            color: AppColors.surfaceVariant, shape: BoxShape.circle),
        child: const Icon(Icons.groups_outlined,
            color: AppColors.textMuted, size: 22),
      ),
      title: Text(entry.title, style: AppTextStyles.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.meetingName,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 11, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(formatDate(entry.startedAt ?? entry.createdAt),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted)),
            if (entry.durationLabel.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.timer_outlined,
                  size: 11, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(entry.durationLabel,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted)),
            ],
          ]),
        ],
      ),
    );
  }
}
