import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/models/location_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';

class MapSelectScreen extends StatefulWidget {
  final String title;
  final void Function(LocationModel)? onSelected;

  const MapSelectScreen({super.key, required this.title, this.onSelected});

  @override
  State<MapSelectScreen> createState() => _MapSelectScreenState();
}

class _MapSelectScreenState extends State<MapSelectScreen> {
  final _searchCtrl = TextEditingController();
  LocationModel? _selected;
  LatLng _mapCenter = const LatLng(-27.5954, -48.5480);
  bool _locationReady = false;

  final _suggestions = [
    LocationModel(lat: -27.5954, lng: -48.5480, address: 'Praça XV de Novembro, Florianópolis', label: 'Centro'),
    LocationModel(lat: -27.6271, lng: -48.4901, address: 'Lagoa da Conceição, Florianópolis', label: 'Lagoa'),
    LocationModel(lat: -27.5969, lng: -48.5480, address: 'Terminal Rodoviário TICEN', label: 'Rodoviária'),
    LocationModel(lat: -27.5816, lng: -48.5222, address: 'Shopping Iguatemi Florianópolis', label: 'Shopping'),
    LocationModel(lat: -27.6200, lng: -48.6500, address: 'Praia do Campeche, Florianópolis', label: 'Campeche'),
  ];

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
          setState(() => _mapCenter = LatLng(pos.latitude, pos.longitude));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _locationReady = true);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppSearchInput(
              controller: _searchCtrl,
              hint: 'Buscar endereço ou local',
              autofocus: false,
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Map
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            height: 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: !_locationReady
                  ? Container(
                      color: AppColors.darkNavy,
                      child: const Center(child: CircularProgressIndicator(color: AppColors.teal)),
                    )
                  : _InteractiveMap(
                      center: _mapCenter,
                      selected: _selected,
                      onTap: (loc) => setState(() => _selected = loc),
                    ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),

          Expanded(
            child: ListView.separated(
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
              itemBuilder: (_, i) {
                final loc = _suggestions[i];
                final isSelected = _selected?.address == loc.address;
                return ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.teal.withOpacity(0.2) : AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.place, color: isSelected ? AppColors.teal : AppColors.textMuted, size: 20),
                  ),
                  title: Text(loc.label ?? '', style: AppTextStyles.titleMedium.copyWith(color: isSelected ? AppColors.teal : AppColors.textPrimary)),
                  subtitle: Text(loc.address ?? '', style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.teal) : null,
                  onTap: () => setState(() => _selected = loc),
                );
              },
            ),
          ),

          if (_selected != null)
            Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg, right: AppSpacing.lg,
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
                top: AppSpacing.md,
              ),
              child: AppButton(
                label: 'Confirmar local',
                icon: Icons.check,
                onPressed: () {
                  widget.onSelected?.call(_selected!);
                  context.pop(_selected);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _InteractiveMap extends StatefulWidget {
  final LatLng center;
  final LocationModel? selected;
  final void Function(LocationModel) onTap;

  const _InteractiveMap({required this.center, this.selected, required this.onTap});

  @override
  State<_InteractiveMap> createState() => _InteractiveMapState();
}

class _InteractiveMapState extends State<_InteractiveMap> {
  GoogleMapController? _controller;
  LatLng? _tapped;

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

  Set<Marker> get _markers {
    if (_tapped == null) return {};
    return {
      Marker(
        markerId: const MarkerId('selected'),
        position: _tapped!,
        infoWindow: const InfoWindow(title: 'Local selecionado'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.center, zoom: 14),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        c.setMapStyle(_mapStyle);
      },
      onTap: (latLng) {
        setState(() => _tapped = latLng);
        widget.onTap(LocationModel(
          lat: latLng.latitude,
          lng: latLng.longitude,
          address: '${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}',
        ));
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
