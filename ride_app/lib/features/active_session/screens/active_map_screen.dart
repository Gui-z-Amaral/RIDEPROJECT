import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../viewmodels/active_session_viewmodel.dart';

class ActiveMapScreen extends StatefulWidget {
  final String sessionId;
  final bool isRide;
  const ActiveMapScreen({super.key, required this.sessionId, this.isRide = true});

  @override
  State<ActiveMapScreen> createState() => _ActiveMapScreenState();
}

class _ActiveMapScreenState extends State<ActiveMapScreen> {
  bool _showParticipants = true;
  bool _showAddDestination = false;
  final _destCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ActiveSessionViewModel>().startActiveTracking(
          widget.sessionId,
          isRide: widget.isRide,
        );
      }
    });
  }

  @override
  void dispose() { _destCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ActiveSessionViewModel>();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          children: [
            // Map background
            _MapView(participants: vm.participants),

            // Top bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(AppSpacing.md),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(vm.sessionTitle, style: AppTextStyles.titleLarge),
                            Text(
                              vm.isRide ? 'Rolê em andamento' : 'Viagem em andamento',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.teal),
                            ),
                          ],
                        ),
                      ),
                      // Voice button
                      GestureDetector(
                        onTap: () {
                          vm.toggleVoiceChannel();
                          if (vm.voiceChannelActive) {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _VoiceChannelPanel(vm: vm),
                            );
                          }
                        },
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: vm.voiceChannelActive ? AppColors.teal.withOpacity(0.2) : AppColors.surfaceVariant,
                            shape: BoxShape.circle,
                            border: vm.voiceChannelActive ? Border.all(color: AppColors.teal) : null,
                          ),
                          child: Icon(
                            vm.voiceChannelActive ? Icons.mic : Icons.mic_none,
                            size: 18,
                            color: vm.voiceChannelActive ? AppColors.teal : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Participant avatars strip
            if (_showParticipants)
              Positioned(
                top: 100, left: AppSpacing.md, right: AppSpacing.md,
                child: SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: vm.participants.length,
                    itemBuilder: (_, i) {
                      final p = vm.participants[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              AppAvatar(name: p.user.name, imageUrl: p.user.avatarUrl, size: 28, showOnline: true, isOnline: true),
                              const SizedBox(width: 6),
                              Text(p.user.name.split(' ').first, style: AppTextStyles.labelMedium),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.97),
                  border: const Border(top: BorderSide(color: AppColors.divider)),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
                ),
                padding: EdgeInsets.only(
                  left: AppSpacing.lg, right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showAddDestination) ...[
                      TextField(
                        controller: _destCtrl,
                        autofocus: true,
                        style: AppTextStyles.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Adicionar novo destino...',
                          hintStyle: AppTextStyles.bodyMedium,
                          filled: true,
                          fillColor: AppColors.surfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusFull), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => setState(() { _showAddDestination = false; _destCtrl.clear(); }),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => setState(() { _showAddDestination = false; _destCtrl.clear(); }),
                                child: const Text('Adicionar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Row(
                      children: [
                        _ControlBtn(icon: Icons.add_location_alt, label: 'Destino', onTap: () => setState(() => _showAddDestination = !_showAddDestination)),
                        const SizedBox(width: AppSpacing.sm),
                        _ControlBtn(icon: Icons.person_add, label: 'Convidar', onTap: () {}),
                        const SizedBox(width: AppSpacing.sm),
                        _ControlBtn(icon: Icons.route, label: 'Rota', onTap: () {}),
                        const SizedBox(width: AppSpacing.sm),
                        _ControlBtn(
                          icon: Icons.exit_to_app,
                          label: 'Sair',
                          color: AppColors.error,
                          onTap: () => _showLeaveDialog(context, vm),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, ActiveSessionViewModel vm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Sair do rolê?'),
        content: vm.isLeader
            ? const Text('Como criador, sair transferirá a liderança para outro participante.')
            : const Text('Você será removido do grupo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              vm.endSession();
              context.go('/rides');
            },
            child: const Text('Sair', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ControlBtn({required this.icon, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.teal;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: c.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: c, size: 20),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapView extends StatefulWidget {
  final List<SessionParticipant> participants;
  const _MapView({required this.participants});

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  GoogleMapController? _controller;
  LatLng _center = const LatLng(-27.5954, -48.5480);
  bool _locationReady = false;

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
          setState(() => _center = LatLng(pos.latitude, pos.longitude));
          _controller?.animateCamera(CameraUpdate.newLatLng(_center));
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _locationReady = true);
  }

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

  Set<Marker> get _markers => widget.participants.asMap().entries.map((e) {
    return Marker(
      markerId: MarkerId('participant_${e.key}'),
      position: LatLng(e.value.lat, e.value.lng),
      infoWindow: InfoWindow(title: e.value.user.name, snippet: e.value.user.motoModel),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }).toSet();

  @override
  Widget build(BuildContext context) {
    if (!_locationReady) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.darkNavy, AppColors.mediumBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _center, zoom: 14),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      onMapCreated: (c) {
        _controller = c;
        c.setMapStyle(_mapStyle);
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

class _FallbackActiveMap extends StatelessWidget {
  final List<SessionParticipant> participants;
  const _FallbackActiveMap({required this.participants});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.darkNavy, AppColors.mediumBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: CustomPaint(painter: _ActiveMapPainter(participants: participants), child: Container()),
    );
  }
}

class _ActiveMapPainter extends CustomPainter {
  final List<SessionParticipant> participants;
  _ActiveMapPainter({required this.participants});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = AppColors.teal.withOpacity(0.06)..strokeWidth = 0.5;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) { canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint); }
    for (double y = 0; y < size.height; y += step) { canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint); }

    final linePaint = Paint()..color = AppColors.teal.withOpacity(0.4)..strokeWidth = 2..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.7);
    path.cubicTo(size.width * 0.3, size.height * 0.5, size.width * 0.6, size.height * 0.4, size.width * 0.8, size.height * 0.3);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < participants.length; i++) {
      final markerPaint = Paint()..color = AppColors.teal..style = PaintingStyle.fill;
      final x = size.width * (0.25 + i * 0.15);
      final y = size.height * (0.55 - i * 0.05);
      canvas.drawCircle(Offset(x, y), 8, markerPaint);
    }
  }

  @override
  bool shouldRepaint(_ActiveMapPainter old) => true;
}

class _VoiceChannelPanel extends StatelessWidget {
  final ActiveSessionViewModel vm;
  const _VoiceChannelPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(Icons.graphic_eq, color: AppColors.teal),
              const SizedBox(width: AppSpacing.sm),
              Text('Canal de voz do grupo', style: AppTextStyles.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...vm.participants.map((p) => ListTile(
                leading: AppAvatar(name: p.user.name, imageUrl: p.user.avatarUrl, size: 36),
                title: Text(p.user.name, style: AppTextStyles.titleMedium),
                trailing: Icon(Icons.mic, size: 18, color: AppColors.success),
              )),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: vm.toggleMute,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: vm.myVoiceMuted ? AppColors.error.withOpacity(0.1) : AppColors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(color: vm.myVoiceMuted ? AppColors.error : AppColors.teal),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(vm.myVoiceMuted ? Icons.mic_off : Icons.mic, color: vm.myVoiceMuted ? AppColors.error : AppColors.teal, size: 18),
                        const SizedBox(width: 6),
                        Text(vm.myVoiceMuted ? 'Ativar mic' : 'Silenciar', style: AppTextStyles.labelMedium.copyWith(color: vm.myVoiceMuted ? AppColors.error : AppColors.teal)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: () { vm.toggleVoiceChannel(); Navigator.pop(context); },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Text('Sair do canal', style: AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
