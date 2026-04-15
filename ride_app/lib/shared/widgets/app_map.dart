import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/location_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_spacing.dart';

/// Mapa Google Maps interativo com suporte a localização do dispositivo.
class AppMap extends StatefulWidget {
  final LocationModel? center;
  final List<LocationModel> markers;
  final List<LocationModel> routePoints;
  final double height;
  final bool interactive;
  final double zoom;
  final VoidCallback? onTap;

  const AppMap({
    super.key,
    this.center,
    this.markers = const [],
    this.routePoints = const [],
    this.height = 200,
    this.interactive = true,
    this.zoom = 14,
    this.onTap,
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  GoogleMapController? _controller;
  LatLng? _deviceLocation;
  bool _locationLoaded = false;

  static const _mapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0d1f3c"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#98a5be"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#255763"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#4e6d70"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]}
]
''';

  @override
  void initState() {
    super.initState();
    if (widget.center == null) {
      _fetchLocation();
    } else {
      _locationLoaded = true;
    }
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationLoaded = true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _deviceLocation = LatLng(pos.latitude, pos.longitude);
          _locationLoaded = true;
        });
        _controller?.animateCamera(
          CameraUpdate.newLatLng(_deviceLocation!),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoaded = true);
    }
  }

  LatLng get _center {
    if (widget.center != null) return LatLng(widget.center!.lat, widget.center!.lng);
    if (_deviceLocation != null) return _deviceLocation!;
    return const LatLng(-27.5954, -48.5480); // fallback Florianópolis
  }

  Set<Marker> get _markers {
    final result = <Marker>{};
    for (int i = 0; i < widget.markers.length; i++) {
      final loc = widget.markers[i];
      result.add(Marker(
        markerId: MarkerId('marker_$i'),
        position: LatLng(loc.lat, loc.lng),
        infoWindow: InfoWindow(
          title: loc.label ?? loc.address ?? 'Local $i',
          snippet: loc.address,
        ),
      ));
    }
    return result;
  }

  Set<Polyline> get _polylines {
    if (widget.routePoints.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: widget.routePoints.map((l) => LatLng(l.lat, l.lng)).toList(),
        color: AppColors.teal,
        width: 4,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_locationLoaded) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          height: widget.height,
          color: AppColors.darkNavy,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.teal),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: SizedBox(
        height: widget.height,
        child: GestureDetector(
          onTap: widget.interactive ? null : widget.onTap,
          child: AbsorbPointer(
            absorbing: !widget.interactive,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: _center, zoom: widget.zoom),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: widget.interactive,
              mapToolbarEnabled: false,
              zoomControlsEnabled: widget.interactive,
              compassEnabled: widget.interactive,
              onMapCreated: (c) {
                _controller = c;
                c.setMapStyle(_mapStyle);
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.teal.withOpacity(0.07)..strokeWidth = 0.5;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(_) => false;
}
