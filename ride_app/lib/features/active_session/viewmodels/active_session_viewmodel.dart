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

class ActiveSessionViewModel extends ChangeNotifier with WidgetsBindingObserver {
  static SupabaseClient get _db => Supabase.instance.client;
  static String get _uid => _db.auth.currentUser?.id ?? '';

  ActiveSessionViewModel() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    if (_hasActiveSession) {
      // Reinicia GPS e canais realtime que podem ter caído em background
      await _loadParticipantsFromDb(_sessionId, _isRide);
      await _loadInitialLocations(_sessionId);
      _subscribeToLocations(_sessionId);
      await _startGPS(_sessionId);
    } else {
      await restoreSession();
    }
  }

  /// Busca no banco se há sessão ativa para este usuário e restaura o estado.
  Future<void> restoreSession() async {
    if (_hasActiveSession) return;
    try {
      final participantRows = await _db
          .from('ride_participants')
          .select('ride_id')
          .eq('user_id', _uid)
          .isFilter('left_at', null);

      if ((participantRows as List).isEmpty) return;

      final rideIds = participantRows
          .map((r) => r['ride_id'] as String)
          .toList();

      final activeRides = await _db
          .from('rides')
          .select('id, title, creator_id, status')
          .inFilter('id', rideIds)
          .inFilter('status', ['active', 'waiting']);

      if ((activeRides as List).isEmpty) return;

      final ride = activeRides.first;
      _hasActiveSession = true;
      _sessionId = ride['id'] as String;
      _sessionTitle = ride['title'] as String;
      _isRide = true;
      _isLeader = (ride['creator_id'] as String) == _uid;
      notifyListeners();

      await startActiveTracking(_sessionId, isRide: true);
    } catch (_) {}
  }

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
    // Se trocou de sessão, cancela tudo antes de recomeçar
    if (_sessionId.isNotEmpty && _sessionId != sessionId) {
      _cancelAllSubscriptions();
      _participants = [];
    }

    // Primeira entrada do convidado (sem passar por startSession/restoreSession)
    if (_sessionId != sessionId) {
      _sessionId = sessionId;
      _isRide = isRide;
      _hasActiveSession = true;
      _isLeader = false;
    }

    // Carrega lista real de participantes do banco (corrige convidados sem lista)
    await _loadParticipantsFromDb(sessionId, isRide);

    // Carrega localizações existentes para mostrar imediatamente
    await _loadInitialLocations(sessionId);

    // Escuta atualizações de localização dos outros em tempo real
    _subscribeToLocations(sessionId);

    // Começa a publicar a própria localização
    await _startGPS(sessionId);
  }

  /// Carrega participantes do banco e faz merge preservando lat/lng já conhecidos.
  Future<void> _loadParticipantsFromDb(String sessionId, bool isRide) async {
    try {
      List<UserModel> users;
      if (isRide) {
        final ride = await SupabaseRideService.getRideById(sessionId);
        if (ride == null) return;
        users = ride.participants;
        // Garante que o criador também está na lista
        if (users.every((u) => u.id != ride.creator.id)) {
          users = [ride.creator, ...users];
        }
      } else {
        final trip = await SupabaseTripService.getTripById(sessionId);
        if (trip == null) return;
        users = trip.participants;
        if (users.every((u) => u.id != trip.creator.id)) {
          users = [trip.creator, ...users];
        }
      }
      _mergeParticipants(users);
    } catch (_) {}
  }

  /// Mantém lat/lng dos participantes já em memória, adiciona novos e
  /// remove quem saiu da sessão.
  void _mergeParticipants(List<UserModel> users) {
    final existing = {for (final p in _participants) p.user.id: p};
    _participants = users.map((u) {
      final prev = existing[u.id];
      if (prev != null) {
        return SessionParticipant(
          user: u,
          status: prev.status == ParticipantStatus.waiting
              ? ParticipantStatus.confirmed
              : prev.status,
          lat: prev.lat,
          lng: prev.lng,
        );
      }
      return SessionParticipant(user: u, status: ParticipantStatus.confirmed);
    }).toList();
    notifyListeners();
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
              final known =
                  _participants.any((p) => p.user.id == userId);
              if (!known) {
                // Novo convidado apareceu em tempo real — recarrega lista do banco
                _loadParticipantsFromDb(sessionId, _isRide).then((_) {
                  _setParticipantLocation(userId, lat, lng);
                  notifyListeners();
                });
              } else {
                _setParticipantLocation(userId, lat, lng);
                notifyListeners();
              }
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

  void addInvitedParticipants(List<UserModel> users) {
    for (final u in users) {
      if (_participants.every((p) => p.user.id != u.id)) {
        _participants.add(SessionParticipant(user: u));
      }
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllSubscriptions();
    super.dispose();
  }
}
