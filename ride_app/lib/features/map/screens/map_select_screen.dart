import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../core/models/location_model.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/constants/app_config.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';

// ── Prediction do autocomplete ────────────────────────────────────────────────

class _PlacePrediction {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const _PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

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
  PlaceInfo? _selectedInfo;
  LatLng _mapCenter = const LatLng(-27.5954, -48.5480);
  bool _locationReady = false;

  // Autocomplete
  List<_PlacePrediction> _predictions = [];
  bool _isSearching = false;
  Timer? _debounce;
  LatLng? _externalTap; // força o mapa a mover para um lugar selecionado via busca

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
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Autocomplete ───────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchPlaces(query.trim()),
    );
  }

  Future<void> _searchPlaces(String query) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeQueryComponent(query)}'
        '&language=pt-BR'
        '&location=${_mapCenter.latitude},${_mapCenter.longitude}'
        '&radius=100000'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() => _isSearching = false);
        return;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final preds = (data['predictions'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      setState(() {
        _isSearching = false;
        _predictions = preds.map((p) {
          final sf = p['structured_formatting'] as Map<String, dynamic>? ?? {};
          return _PlacePrediction(
            placeId: p['place_id'] as String? ?? '',
            mainText: sf['main_text'] as String? ??
                p['description'] as String? ?? '',
            secondaryText: sf['secondary_text'] as String? ?? '',
          );
        }).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPrediction(_PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchCtrl.text = prediction.mainText;
      _predictions = [];
      _isSearching = true;
    });

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${prediction.placeId}'
        '&fields=geometry,formatted_address,name,types,opening_hours,photos,address_components'
        '&language=pt-BR'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() => _isSearching = false);
        return;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        setState(() => _isSearching = false);
        return;
      }
      final result = data['result'] as Map<String, dynamic>;
      final geo = (result['geometry'] as Map<String, dynamic>)['location']
          as Map<String, dynamic>;
      final lat = (geo['lat'] as num).toDouble();
      final lng = (geo['lng'] as num).toDouble();
      final name = result['name'] as String? ?? prediction.mainText;
      final address =
          result['formatted_address'] as String? ?? prediction.secondaryText;
      final types =
          (result['types'] as List<dynamic>? ?? []).cast<String>();
      final category = GeocodingService.categoryFromTypes(types);

      // Horários
      final hours = result['opening_hours'] as Map<String, dynamic>?;
      final openNow = hours?['open_now'] as bool?;
      final weekdayText =
          (hours?['weekday_text'] as List<dynamic>?)?.cast<String>();

      // Foto
      final photos = result['photos'] as List<dynamic>?;
      final photoRef = photos?.isNotEmpty == true
          ? (photos!.first as Map<String, dynamic>)['photo_reference'] as String?
          : null;

      // Endereço estruturado
      final addrComponents = (result['address_components'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      String? getComp(List<String> t) => addrComponents
          .where((c) => (c['types'] as List).any(t.contains))
          .map((c) => c['long_name'] as String)
          .firstOrNull;
      final streetName  = getComp(['route']);
      final streetNum   = getComp(['street_number']);
      final neighborhood = getComp(['sublocality', 'sublocality_level_1', 'neighborhood']);
      final postalCode  = getComp(['postal_code'])?.replaceAll(RegExp(r'\D'), '');

      final loc = LocationModel(lat: lat, lng: lng, label: name, address: address);
      final info = PlaceInfo(
        name: name,
        address: address,
        category: category,
        placeId: prediction.placeId,
        openNow: openNow,
        weekdayText: weekdayText,
        photoRef: photoRef,
        streetName: streetName,
        streetNumber: streetNum,
        neighborhood: neighborhood,
        postalCode: postalCode,
      );

      setState(() {
        _selected = loc;
        _selectedInfo = info;
        _isSearching = false;
        _externalTap = LatLng(lat, lng);
        _mapCenter = LatLng(lat, lng);
      });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPredictions =
        _searchCtrl.text.trim().isNotEmpty && (_predictions.isNotEmpty || _isSearching);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Barra de busca ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AppSearchInput(
              controller: _searchCtrl,
              hint: 'Buscar endereço ou local',
              autofocus: false,
              onChanged: _onSearchChanged,
            ),
          ),

          // ── Mapa — expande ao selecionar ────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            height: _selected != null ? 280 : 200,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: !_locationReady
                  ? Container(
                      color: AppColors.darkNavy,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.teal),
                      ),
                    )
                  : _InteractiveMap(
                      center: _mapCenter,
                      selectedLocation: _selected,
                      externalTap: _externalTap,
                      onTap: (loc, info) => setState(() {
                        _selected = loc;
                        _selectedInfo = info;
                        _searchCtrl.clear();
                        _predictions = [];
                      }),
                    ),
            ),
          ),

          // ── Card do local selecionado ───────────────────────────
          if (_selected != null)
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: _SelectedPlaceCard(
                  loc: _selected!,
                  info: _selectedInfo,
                  onClear: () => setState(() {
                    _selected = null;
                    _selectedInfo = null;
                    _externalTap = null;
                  }),
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),

          // ── Lista: sugestões autocomplete ou placeholder ─────────
          Expanded(
            child: showPredictions
                ? _isSearching && _predictions.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.teal, strokeWidth: 2),
                      )
                    : ListView.separated(
                        itemCount: _predictions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (_, i) {
                          final p = _predictions[i];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.place,
                                  color: AppColors.textMuted, size: 20),
                            ),
                            title: Text(
                              p.mainText,
                              style: AppTextStyles.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: p.secondaryText.isNotEmpty
                                ? Text(
                                    p.secondaryText,
                                    style: AppTextStyles.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () => _selectPrediction(p),
                          );
                        },
                      )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search,
                            size: 40, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Digite o nome de um lugar\nou toque no mapa para selecionar',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),

          // ── Botão confirmar ────────────────────────────────────
          if (_selected != null)
            Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
                top: AppSpacing.md,
              ),
              child: AppButton(
                label: 'Confirmar local',
                icon: Icons.check,
                onPressed: () {
                  widget.onSelected?.call(_selected!);
                  context.pop({'location': _selected, 'info': _selectedInfo});
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Card de local selecionado ──────────────────────────────────────────────────

class _SelectedPlaceCard extends StatelessWidget {
  final LocationModel loc;
  final PlaceInfo? info;
  final VoidCallback onClear;

  const _SelectedPlaceCard(
      {required this.loc, this.info, required this.onClear});

  IconData _iconForCategory(String? category) {
    if (category == null) return Icons.location_on;
    if (category.contains('Restaurante')) return Icons.restaurant;
    if (category.contains('Café')) return Icons.coffee;
    if (category.contains('Bar')) return Icons.local_bar;
    if (category.contains('Posto')) return Icons.local_gas_station;
    if (category.contains('Hosped')) return Icons.hotel;
    if (category.contains('Parque') || category.contains('Natural'))
      return Icons.park;
    if (category.contains('Comércio')) return Icons.store;
    if (category.contains('Turís')) return Icons.tour;
    if (category.contains('Praia')) return Icons.beach_access;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    final category = info?.category;
    final name = loc.label ?? loc.address ?? '';
    final subtitle = [
      if (category != null && category.isNotEmpty) category,
      if (loc.address != null && loc.address!.isNotEmpty) loc.address!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.teal.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(_iconForCategory(category),
                color: AppColors.teal, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.close, size: 18, color: AppColors.textMuted),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ── Mapa interativo ────────────────────────────────────────────────────────────

class _InteractiveMap extends StatefulWidget {
  final LatLng center;
  final LocationModel? selectedLocation;
  final LatLng? externalTap; // quando não-nulo, move o mapa para esse ponto
  final void Function(LocationModel loc, PlaceInfo? info) onTap;

  const _InteractiveMap({
    required this.center,
    this.selectedLocation,
    this.externalTap,
    required this.onTap,
  });

  @override
  State<_InteractiveMap> createState() => _InteractiveMapState();
}

class _InteractiveMapState extends State<_InteractiveMap> {
  GoogleMapController? _controller;
  LatLng? _tapped;
  bool _isLoading = false;
  List<LatLng> _routePoints = [];
  // Incremented on each tap; stale async handlers compare and bail out early.
  int _tapSeq = 0;

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

  @override
  void didUpdateWidget(_InteractiveMap old) {
    super.didUpdateWidget(old);
    // Atualiza câmera quando localização do usuário chega
    if (old.center != widget.center && _tapped == null) {
      _controller?.animateCamera(CameraUpdate.newLatLng(widget.center));
    }
    // Seleciona lugar via busca (autocomplete)
    if (widget.externalTap != null &&
        widget.externalTap != old.externalTap) {
      setState(() {
        _tapped = widget.externalTap;
        _routePoints = [];
        _isLoading = false;
      });
      _controller?.animateCamera(
          CameraUpdate.newLatLngZoom(widget.externalTap!, 15));
    }
  }

  Set<Marker> get _markers {
    if (_tapped == null) return {};
    return {
      Marker(
        markerId: const MarkerId('selected'),
        position: _tapped!,
        infoWindow: InfoWindow(
          title: widget.selectedLocation?.label ?? 'Local selecionado',
          snippet: widget.selectedLocation?.address,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
    };
  }

  Set<Polyline> get _polylines {
    if (_routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: AppColors.teal,
        width: 4,
      ),
    };
  }

  Future<void> _handleTap(LatLng tapLatLng) async {
    final seq = ++_tapSeq;

    setState(() {
      _tapped = tapLatLng;
      _isLoading = true;
      _routePoints = [];
    });

    // Route fetch runs in parallel with place resolution.
    final routeFuture = _fetchRoute(
      widget.center.latitude, widget.center.longitude,
      tapLatLng.latitude, tapLatLng.longitude,
    );

    // ── Magnetic snap: try to find a named POI at the tapped point ──────────
    LatLng resolved = tapLatLng;
    PlaceInfo? info;

    final nearby = await GeocodingService.nearbySearch(
        tapLatLng.latitude, tapLatLng.longitude);
    if (_tapSeq != seq || !mounted) return;

    if (nearby?.placeId != null) {
      final details = await _fetchPlaceDetails(nearby!.placeId!);
      if (_tapSeq != seq || !mounted) return;
      if (details != null) {
        resolved = LatLng(details.$1, details.$2);
        info = details.$3;
        setState(() => _tapped = resolved); // visually snap the pin
      }
    }

    // Fallback: reverseGeocode when no POI snap
    if (info == null) {
      info = await GeocodingService.reverseGeocode(
          tapLatLng.latitude, tapLatLng.longitude);
      if (_tapSeq != seq || !mounted) return;
    }

    final route = await routeFuture;
    if (_tapSeq != seq || !mounted) return;

    setState(() {
      _isLoading = false;
      _routePoints = route;
    });

    widget.onTap(
      LocationModel(
        lat: resolved.latitude,
        lng: resolved.longitude,
        label: info?.name ?? 'Local selecionado',
        address: info?.address ?? '',
      ),
      info,
    );

    if (_controller != null && mounted) {
      if (_routePoints.length > 1) {
        final bounds = _boundsOf([widget.center, resolved, ..._routePoints]);
        await _controller!
            .animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
      } else {
        _controller!.animateCamera(CameraUpdate.newLatLng(resolved));
      }
    }
  }

  /// Fetches full Place Details for [placeId].
  /// Returns (lat, lng, PlaceInfo) on success, null on failure.
  Future<(double, double, PlaceInfo)?> _fetchPlaceDetails(
      String placeId) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry,formatted_address,name,types,opening_hours,photos,address_components'
        '&language=pt-BR'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final result = data['result'] as Map<String, dynamic>;
      final geo = (result['geometry'] as Map<String, dynamic>)['location']
          as Map<String, dynamic>;
      final lat = (geo['lat'] as num).toDouble();
      final lng = (geo['lng'] as num).toDouble();
      final name = result['name'] as String? ?? '';
      final address = result['formatted_address'] as String? ?? '';
      final types =
          (result['types'] as List<dynamic>? ?? []).cast<String>();
      final category = GeocodingService.categoryFromTypes(types);

      final hours = result['opening_hours'] as Map<String, dynamic>?;
      final openNow = hours?['open_now'] as bool?;
      final weekdayText =
          (hours?['weekday_text'] as List<dynamic>?)?.cast<String>();

      final photos = result['photos'] as List<dynamic>?;
      final photoRef = photos?.isNotEmpty == true
          ? (photos!.first as Map<String, dynamic>)['photo_reference']
              as String?
          : null;

      final addrComps =
          (result['address_components'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
      String? getComp(List<String> t) => addrComps
          .where((c) => (c['types'] as List).any(t.contains))
          .map((c) => c['long_name'] as String)
          .firstOrNull;

      return (
        lat,
        lng,
        PlaceInfo(
          name: name.isNotEmpty ? name : 'Local selecionado',
          address: address,
          category: category,
          placeId: placeId,
          openNow: openNow,
          weekdayText: weekdayText,
          photoRef: photoRef,
          streetName: getComp(['route']),
          streetNumber: getComp(['street_number']),
          neighborhood: getComp([
            'sublocality',
            'sublocality_level_1',
            'neighborhood'
          ]),
          postalCode: getComp(['postal_code'])
              ?.replaceAll(RegExp(r'\D'), ''),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<LatLng>> _fetchRoute(
      double oLat, double oLng, double dLat, double dLng) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$oLat,$oLng'
        '&destination=$dLat,$dLng'
        '&mode=driving'
        '&language=pt-BR'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return [];
      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return [];
      final polyline =
          (routes[0] as Map<String, dynamic>)['overview_polyline']
              as Map<String, dynamic>;
      return _decodePolyline(polyline['points'] as String);
    } catch (_) {
      return [];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat =
          ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng =
          ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  LatLngBounds _boundsOf(List<LatLng> list) {
    double minLat = list.first.latitude, maxLat = list.first.latitude;
    double minLng = list.first.longitude, maxLng = list.first.longitude;
    for (final p in list) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: widget.center, zoom: 14),
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          onMapCreated: (c) {
            _controller = c;
            c.setMapStyle(_mapStyle);
          },
          onTap: _handleTap,
        ),
        if (_isLoading)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              color: AppColors.teal,
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
