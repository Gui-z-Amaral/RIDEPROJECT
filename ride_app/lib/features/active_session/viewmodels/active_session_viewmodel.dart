import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/services/supabase_ride_service.dart';
import '../../../core/services/supabase_trip_service.dart';

enum ParticipantStatus { waiting, confirmed, declined }

class SessionParticipant {
  final UserModel user;
  ParticipantStatus status;
  double lat;
  double lng;

  SessionParticipant({
    required this.user,
    this.status = ParticipantStatus.waiting,
    this.lat = 0,
    this.lng = 0,
  });
}

class ActiveSessionViewModel extends ChangeNotifier {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser?.id ?? '';

  bool _hasActiveSession = false;
  String _sessionId = '';
  String _sessionTitle = '';
  bool _isRide = true;
  bool _isLeader = true;
  bool _voiceChannelActive = false;
  bool _myVoiceMuted = false;
  List<SessionParticipant> _participants = [];

  // Subscriptions
  RealtimeChannel? _participantsChannel;
  RealtimeChannel? _locationChannel;
  StreamSubscription<Position>? _positionStream;

  bool get hasActiveSession => _hasActiveSession;
  String get sessionId => _sessionId;
  String get sessionTitle => _sessionTitle;
  bool get isRide => _isRide;
  bool get isLeader => _isLeader;
  bool get voiceChannelActive => _voiceChannelActive;
  bool get myVoiceMuted => _myVoiceMuted;
  List<SessionParticipant> get participants => _participants;

  bool get allConfirmed =>
      _participants.isNotEmpty &&
      _participants.every((p) =>
          p.status == ParticipantStatus.confirmed ||
          p.status == ParticipantStatus.declined);

  int get confirmedCount =>
      _participants.where((p) => p.status == ParticipantStatus.confirmed).length;

  // ── Criador inicia o rolê/viagem ──────────────────────────
  Future<void> startSession({
    required String id,
    required String title,
    required bool isRide,
    List<UserModel> participants = const [],
  }) async {
    _cancelAllSubscriptions();

    _hasActiveSession = true;
    _sessionId = id;
    _sessionTitle = title;
    _isRide = isRide;
    _isLeader = true;

    _participants = participants
        .map((u) => SessionParticipant(
              user: u,
              status: u.id == _uid
                  ? ParticipantStatus.confirmed
                  : ParticipantStatus.waiting,
            ))
        .toList();

    notifyListeners();

    // Marca criador como confirmado no banco
    try {
      if (isRide) {
        await SupabaseRideService.confirmParticipation(id);
      } else {
        await SupabaseTripService.confirmParticipation(id);
      }
    } catch (_) {}

    _subscribeToParticipantStatus(id, isRide);
  }

  // ── Chamado ao entrar na tela do mapa ativo ───────────────
  // Funciona tanto para criador quanto para convidados.
  Future<void> startActiveTracking(String sessionId, {bool isRide = true}) async {
    // Já rastreando esta sessão — não reinicia
    if (_locationChannel != null && _sessionId == sessionId) return;

    if (_sessionId != sessionId) {
      // Participante entrou direto (ex: convidado confirmou)
      _sessionId = sessionId;
      _isRide = isRide;
      _hasActiveSession = true;
      _isLeader = false;
    }

    // Carrega localizações existentes para mostrar imediatamente
    await _loadInitialLocations(sessionId);

    // Escuta atualizações de localização dos outros em tempo real
    _subscribeToLocations(sessionId);

    // Começa a publicar a própria localização
    await _startGPS(sessionId);
  }

  Future<void> _loadInitialLocations(String sessionId) async {
    try {
      final rows = await SupabaseRideService.getLocations(sessionId);
      for (final row in rows) {
        final userId = row['user_id'] as String?;
        final lat = (row['lat'] as num?)?.toDouble();
        final lng = (row['lng'] as num?)?.toDouble();
        if (userId != null && lat != null && lng != null) {
          _setParticipantLocation(userId, lat, lng);
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _startGPS(String sessionId) async {
    await _positionStream?.cancel();

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return;

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // publica a cada 10 metros de deslocamento
        ),
      ).listen((pos) async {
        _setParticipantLocation(_uid, pos.latitude, pos.longitude);
        notifyListeners();
        try {
          await SupabaseRideService.upsertLocation(
              sessionId, pos.latitude, pos.longitude);
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _subscribeToLocations(String sessionId) {
    _locationChannel?.unsubscribe();
    _locationChannel = _db
        .channel('locations-$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: sessionId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final userId = record['user_id'] as String?;
            final lat = (record['lat'] as num?)?.toDouble();
            final lng = (record['lng'] as num?)?.toDouble();
            // Atualiza localização de outros participantes (própria já é local)
            if (userId != null && lat != null && lng != null &&
                userId != _uid) {
              _setParticipantLocation(userId, lat, lng);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  void _setParticipantLocation(String userId, double lat, double lng) {
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx >= 0) {
      _participants[idx].lat = lat;
      _participants[idx].lng = lng;
    }
  }

  // ── Inicia o rolê sem esperar todos confirmarem ────────────
  Future<void> startNow() async {
    try {
      if (_isRide) {
        await SupabaseRideService.updateStatus(_sessionId, RideStatus.active);
      } else {
        await SupabaseTripService.updateStatus(_sessionId, TripStatus.active);
      }
    } catch (_) {}
  }

  // ── Status de confirmação (tela de espera) ─────────────────
  void _subscribeToParticipantStatus(String sessionId, bool isRide) {
    _participantsChannel?.unsubscribe();
    final table = isRide ? 'ride_participants' : 'trip_participants';
    final column = isRide ? 'ride_id' : 'trip_id';

    _participantsChannel = _db
        .channel('session-$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: table,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: column,
            value: sessionId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            final userId = record['user_id'] as String?;
            final statusStr = record['status'] as String?;
            if (userId == null || statusStr == null) return;
            final idx = _participants.indexWhere((p) => p.user.id == userId);
            if (idx >= 0) {
              _participants[idx].status = _parseStatus(statusStr);
              notifyListeners();
            }
          },
        )
        .subscribe();
  }

  ParticipantStatus _parseStatus(String s) => switch (s) {
        'confirmed' => ParticipantStatus.confirmed,
        'declined' => ParticipantStatus.declined,
        _ => ParticipantStatus.waiting,
      };

  void toggleVoiceChannel() {
    _voiceChannelActive = !_voiceChannelActive;
    notifyListeners();
  }

  void toggleMute() {
    _myVoiceMuted = !_myVoiceMuted;
    notifyListeners();
  }

  void transferLeadership(String userId) => notifyListeners();

  void confirmParticipant(String userId) {
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx >= 0) {
      _participants[idx].status = ParticipantStatus.confirmed;
      notifyListeners();
    }
  }

  void endSession() {
    _cancelAllSubscriptions();
    _hasActiveSession = false;
    _sessionId = '';
    _sessionTitle = '';
    _participants.clear();
    _voiceChannelActive = false;
    notifyListeners();
  }

  void removeParticipant(String userId) {
    _participants.removeWhere((p) => p.user.id == userId);
    notifyListeners();
  }

  void updateParticipantLocation(String userId, double lat, double lng) {
    _setParticipantLocation(userId, lat, lng);
    notifyListeners();
  }

  void _cancelAllSubscriptions() {
    _positionStream?.cancel();
    _positionStream = null;
    _participantsChannel?.unsubscribe();
    _participantsChannel = null;
    _locationChannel?.unsubscribe();
    _locationChannel = null;
  }

  @override
  void dispose() {
    _cancelAllSubscriptions();
    super.dispose();
  }
}
