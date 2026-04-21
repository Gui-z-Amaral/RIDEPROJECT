import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_spacing.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_ride_service.dart';
import '../../../core/services/supabase_notification_service.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../social/viewmodels/social_viewmodel.dart';
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
                        _ControlBtn(
                          icon: Icons.person_add,
                          label: 'Convidar',
                          onTap: () => _showInviteSheet(context, vm),
                        ),
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

  void _showInviteSheet(BuildContext context, ActiveSessionViewModel vm) {
    final socialVm = context.read<SocialViewModel>();
    if (socialVm.friends.isEmpty && !socialVm.isLoading) {
      socialVm.loadFriends();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => _InviteSheet(
        alreadyInIds: vm.participants.map((p) => p.user.id).toSet(),
        sessionTitle: vm.sessionTitle,
        isRide: vm.isRide,
        onInvite: (users) => _inviteUsers(context, vm, users),
      ),
    );
  }

  Future<void> _inviteUsers(
    BuildContext context,
    ActiveSessionViewModel vm,
    List<UserModel> users,
  ) async {
    if (users.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final creatorName =
        context.read<AuthViewModel>().user?.name ?? 'Alguém';

    try {
      if (vm.isRide) {
        await SupabaseRideService.inviteParticipants(
            vm.sessionId, users.map((u) => u.id).toList());
      }
      await SupabaseNotificationService.sendInviteNotifications(
        userIds: users.map((u) => u.id).toList(),
        type: vm.isRide ? 'ride_invite' : 'trip_invite',
        title: vm.isRide ? 'Convite para rolê' : 'Convite para viagem',
        body: '$creatorName te convidou para "${vm.sessionTitle}"',
        data: {
          'rideId': vm.isRide ? vm.sessionId : null,
          'tripId': vm.isRide ? null : vm.sessionId,
          'place': vm.sessionTitle,
        },
      );
      vm.addInvitedParticipants(users);
      messenger.showSnackBar(
        SnackBar(
          content: Text(users.length == 1
              ? '${users.first.name} foi convidado'
              : '${users.length} amigos convidados'),
          backgroundColor: AppColors.teal,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      final msg = e.toString().contains('42501')
          ? 'Sem permissão para convidar. Verifique as políticas de segurança no Supabase.'
          : 'Não foi possível convidar. Tente novamente.';
      messenger.showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  // Cache de ícones por userId (evita re-gerar o avatar a cada build)
  final Map<String, BitmapDescriptor> _markerIcons = {};
  final Set<String> _generatingIcons = {};
  static const double _iconSize = 110; // tamanho do bitmap em px

  BitmapDescriptor _iconFor(UserModel user) {
    final cached = _markerIcons[user.id];
    if (cached != null) return cached;
    if (!_generatingIcons.contains(user.id)) {
      _generatingIcons.add(user.id);
      _buildMarkerIcon(user).then((icon) {
        _generatingIcons.remove(user.id);
        if (mounted) setState(() => _markerIcons[user.id] = icon);
      }).catchError((_) {
        _generatingIcons.remove(user.id);
      });
    }
    // Enquanto o avatar carrega, usa pin padrão
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  Future<BitmapDescriptor> _buildMarkerIcon(UserModel user) async {
    const size = _iconSize;
    const borderWidth = 7.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);

    // Fundo branco (aparece como gap entre foto e borda)
    canvas.drawCircle(
        center, size / 2, Paint()..color = Colors.white);
    // Borda teal
    canvas.drawCircle(
      center,
      size / 2 - borderWidth / 2,
      Paint()
        ..color = AppColors.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    final innerRadius = size / 2 - borderWidth - 2;
    ui.Image? avatar;
    final url = user.avatarUrl;
    if (url != null && url.isNotEmpty) {
      try {
        avatar = await _loadNetworkImage(url);
      } catch (_) {}
    }

    if (avatar != null) {
      canvas.save();
      canvas.clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: center, radius: innerRadius)),
      );
      // Cover: escala a imagem para preencher o círculo mantendo aspect ratio
      final imgW = avatar.width.toDouble();
      final imgH = avatar.height.toDouble();
      final aspect = imgW / imgH;
      final target = innerRadius * 2;
      double drawW, drawH;
      if (aspect >= 1) {
        drawH = target;
        drawW = drawH * aspect;
      } else {
        drawW = target;
        drawH = drawW / aspect;
      }
      canvas.drawImageRect(
        avatar,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromCenter(center: center, width: drawW, height: drawH),
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
    } else {
      // Fallback: círculo navy com inicial do nome
      canvas.drawCircle(
          center, innerRadius, Paint()..color = AppColors.navy);
      final initial =
          user.name.trim().isNotEmpty ? user.name.trim()[0].toUpperCase() : '?';
      final tp = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
          canvas,
          Offset(
              (size - tp.width) / 2, (size - tp.height) / 2));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<ui.Image> _loadNetworkImage(String url) async {
    final completer = Completer<ui.Image>();
    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (e, _) {
        if (!completer.isCompleted) completer.completeError(e);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  Set<Marker> get _markers => widget.participants
      .where((p) => p.lat != 0 || p.lng != 0)
      .map((p) => Marker(
            markerId: MarkerId('participant_${p.user.id}'),
            position: LatLng(p.lat, p.lng),
            anchor: const Offset(0.5, 0.5),
            infoWindow: InfoWindow(
                title: p.user.name, snippet: p.user.motoModel),
            icon: _iconFor(p.user),
          ))
      .toSet();

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

class _InviteSheet extends StatefulWidget {
  final Set<String> alreadyInIds;
  final String sessionTitle;
  final bool isRide;
  final Future<void> Function(List<UserModel>) onInvite;

  const _InviteSheet({
    required this.alreadyInIds,
    required this.sessionTitle,
    required this.isRide,
    required this.onInvite,
  });

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final Set<String> _selected = {};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final socialVm = context.watch<SocialViewModel>();
    final available = socialVm.friends
        .where((u) => !widget.alreadyInIds.contains(u.id))
        .toList();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: bottomPad + AppSpacing.lg,
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Icon(Icons.person_add, color: AppColors.teal),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.isRide
                        ? 'Convidar para o rolê'
                        : 'Convidar para a viagem',
                    style: AppTextStyles.headlineSmall,
                  ),
                ),
                if (_selected.isNotEmpty)
                  Text('${_selected.length} selecionado(s)',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.teal)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: socialVm.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.teal))
                  : available.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people_outline,
                                    color: AppColors.textMuted, size: 48),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  socialVm.friends.isEmpty
                                      ? 'Você ainda não tem amigos'
                                      : 'Todos os amigos já foram convidados',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textMuted),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollCtrl,
                          itemCount: available.length,
                          itemBuilder: (_, i) {
                            final u = available[i];
                            final isSelected = _selected.contains(u.id);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (isSelected) {
                                  _selected.remove(u.id);
                                } else {
                                  _selected.add(u.id);
                                }
                              }),
                              child: Container(
                                margin: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.teal.withOpacity(0.1)
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMd),
                                  border: Border.all(
                                      color: isSelected
                                          ? AppColors.teal
                                          : AppColors.divider),
                                ),
                                child: Row(
                                  children: [
                                    AppAvatar(
                                        name: u.name,
                                        imageUrl: u.avatarUrl,
                                        size: 40),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Text(u.name,
                                          style: AppTextStyles.titleMedium),
                                    ),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 26, height: 26,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.teal
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: isSelected
                                                ? AppColors.teal
                                                : AppColors.divider,
                                            width: 2),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check,
                                              size: 16,
                                              color: AppColors.deepNavy)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isEmpty || _sending
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        final users = socialVm.friends
                            .where((u) => _selected.contains(u.id))
                            .toList();
                        await widget.onInvite(users);
                        if (mounted) Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.deepNavy,
                  disabledBackgroundColor:
                      AppColors.teal.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  elevation: 0,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.deepNavy),
                      )
                    : Text(
                        _selected.isEmpty
                            ? 'Selecione amigos'
                            : 'Convidar ${_selected.length} amigo(s)',
                        style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.deepNavy,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
