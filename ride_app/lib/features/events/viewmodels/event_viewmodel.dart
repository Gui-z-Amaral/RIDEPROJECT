import 'package:flutter/material.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/supabase_event_service.dart';

class EventViewModel extends ChangeNotifier {
  // Eventos da UF atual (home)
  List<EventModel> _nearbyEvents = [];
  bool _isLoadingNearby = false;
  String? _loadedUf;

  // Eventos da empresa logada (perfil)
  List<EventModel> _myEvents = [];
  bool _isLoadingMine = false;

  // Detalhe
  EventModel? _selected;
  bool _isLoadingDetail = false;

  bool _isSaving = false;
  String? _saveError;

  List<EventModel> get nearbyEvents => _nearbyEvents;
  bool get isLoadingNearby => _isLoadingNearby;
  String? get loadedUf => _loadedUf;
  List<EventModel> get myEvents => _myEvents;
  bool get isLoadingMine => _isLoadingMine;
  EventModel? get selected => _selected;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isSaving => _isSaving;
  String? get saveError => _saveError;

  EventModel? get myNextEvent => _myEvents.isNotEmpty ? _myEvents.first : null;

  // ── Home: eventos da UF ──────────────────────────────────────
  Future<void> loadNearby(String uf) async {
    _isLoadingNearby = true;
    notifyListeners();
    try {
      _nearbyEvents = await SupabaseEventService.getEventsByState(uf);
      _loadedUf = uf;
    } catch (_) {
      _nearbyEvents = [];
    }
    _isLoadingNearby = false;
    notifyListeners();
  }

  // ── Perfil empresa: meus eventos ─────────────────────────────
  Future<void> loadMyEvents(String creatorId) async {
    _isLoadingMine = true;
    notifyListeners();
    try {
      _myEvents = await SupabaseEventService.getEventsByCreator(creatorId,
          upcomingOnly: true);
    } catch (_) {
      _myEvents = [];
    }
    _isLoadingMine = false;
    notifyListeners();
  }

  // ── Detalhe ──────────────────────────────────────────────────
  Future<void> loadDetail(String id) async {
    _isLoadingDetail = true;
    _selected = null;
    notifyListeners();
    try {
      _selected = await SupabaseEventService.getEventById(id);
    } catch (_) {
      _selected = null;
    }
    _isLoadingDetail = false;
    notifyListeners();
  }

  // ── Criar ────────────────────────────────────────────────────
  Future<EventModel?> createEvent({
    required String title,
    String? description,
    String? bannerUrl,
    double? lat,
    double? lng,
    String? address,
    String? locationLabel,
    String? stateUf,
    String? city,
    required DateTime startsAt,
    DateTime? endsAt,
    List<EventScheduleItem> schedule = const [],
    List<EventSponsor> sponsors = const [],
    List<String> participantIds = const [],
  }) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final event = await SupabaseEventService.createEvent(
        title: title,
        description: description,
        bannerUrl: bannerUrl,
        lat: lat,
        lng: lng,
        address: address,
        locationLabel: locationLabel,
        stateUf: stateUf,
        city: city,
        startsAt: startsAt,
        endsAt: endsAt,
        schedule: schedule,
        sponsors: sponsors,
        participantIds: participantIds,
      );
      _myEvents = [event, ..._myEvents];
      _isSaving = false;
      notifyListeners();
      return event;
    } catch (e) {
      debugPrint('❌ EventViewModel.createEvent: $e');
      _saveError = 'Não foi possível criar o evento. Tente novamente.';
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  // ── Atualizar ────────────────────────────────────────────────
  Future<EventModel?> updateEvent(
    String eventId, {
    String? title,
    String? description,
    String? bannerUrl,
    double? lat,
    double? lng,
    String? address,
    String? locationLabel,
    String? stateUf,
    String? city,
    DateTime? startsAt,
    DateTime? endsAt,
    List<EventScheduleItem>? schedule,
    List<EventSponsor>? sponsors,
    List<String>? participantIds,
    bool notifyInterested = true,
  }) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final event = await SupabaseEventService.updateEvent(
        eventId,
        title: title,
        description: description,
        bannerUrl: bannerUrl,
        lat: lat,
        lng: lng,
        address: address,
        locationLabel: locationLabel,
        stateUf: stateUf,
        city: city,
        startsAt: startsAt,
        endsAt: endsAt,
        schedule: schedule,
        sponsors: sponsors,
        participantIds: participantIds,
        notifyInterested: notifyInterested,
      );
      if (event != null) {
        _selected = event;
        _myEvents =
            _myEvents.map((e) => e.id == eventId ? event : e).toList();
        _nearbyEvents =
            _nearbyEvents.map((e) => e.id == eventId ? event : e).toList();
      }
      _isSaving = false;
      notifyListeners();
      return event;
    } catch (e) {
      debugPrint('❌ EventViewModel.updateEvent: $e');
      _saveError = 'Não foi possível salvar as alterações. Tente novamente.';
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  // ── Interesse ────────────────────────────────────────────────
  /// Alterna interesse otimisticamente (atualiza UI antes do round-trip) e
  /// reverte se falhar. Sincroniza o estado em todas as listas.
  Future<void> toggleInterest(String eventId) async {
    _applyInterest(eventId, toggle: true);
    notifyListeners();
    try {
      final nowInterested =
          await SupabaseEventService.toggleInterest(eventId);
      _setInterest(eventId, nowInterested);
      notifyListeners();
    } catch (_) {
      // Reverte
      _applyInterest(eventId, toggle: true);
      notifyListeners();
    }
  }

  // Aplica toggle local (flag + contador) em selected e nas listas.
  void _applyInterest(String eventId, {required bool toggle}) {
    EventModel apply(EventModel e) {
      if (e.id != eventId) return e;
      final next = !e.isInterested;
      return e.copyWith(
        isInterested: next,
        interestsCount: (e.interestsCount + (next ? 1 : -1)).clamp(0, 1 << 31),
      );
    }

    if (_selected?.id == eventId) _selected = apply(_selected!);
    _nearbyEvents = _nearbyEvents.map(apply).toList();
    _myEvents = _myEvents.map(apply).toList();
  }

  // Força o estado de interesse pro valor canônico vindo do servidor.
  void _setInterest(String eventId, bool interested) {
    EventModel fix(EventModel e) {
      if (e.id != eventId || e.isInterested == interested) return e;
      return e.copyWith(
        isInterested: interested,
        interestsCount:
            (e.interestsCount + (interested ? 1 : -1)).clamp(0, 1 << 31),
      );
    }

    if (_selected?.id == eventId) _selected = fix(_selected!);
    _nearbyEvents = _nearbyEvents.map(fix).toList();
    _myEvents = _myEvents.map(fix).toList();
  }

  // ── Deletar ──────────────────────────────────────────────────
  Future<bool> deleteEvent(String eventId) async {
    try {
      await SupabaseEventService.deleteEvent(eventId);
      _myEvents = _myEvents.where((e) => e.id != eventId).toList();
      _nearbyEvents = _nearbyEvents.where((e) => e.id != eventId).toList();
      if (_selected?.id == eventId) _selected = null;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Limpa estado — chamado no logout.
  void reset() {
    _nearbyEvents = [];
    _myEvents = [];
    _selected = null;
    _loadedUf = null;
    _isLoadingNearby = false;
    _isLoadingMine = false;
    _isLoadingDetail = false;
    _isSaving = false;
    _saveError = null;
    notifyListeners();
  }
}
