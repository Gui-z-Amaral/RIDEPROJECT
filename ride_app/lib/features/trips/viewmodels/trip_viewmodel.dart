import 'package:flutter/material.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_trip_service.dart';

class TripViewModel extends ChangeNotifier {
  List<TripModel> _trips = [];
  TripModel? _selectedTrip;

  // ── List operations (loadTrips) ────────────────────────────
  bool _isLoading = false;

  // ── Detail operations (loadTripById) ───────────────────────
  // Kept separate so loadTrips() never clobbers the detail loading state.
  bool _isLoadingDetail = false;
  bool _detailError = false;

  bool _isSaving = false;
  String? _saveError;

  // Form state
  String _title = '';
  LocationModel? _origin;
  LocationModel? _destination;
  List<LocationModel> _waypoints = [];
  List<UserModel> _participants = [];
  DateTime? _scheduledAt;

  List<TripModel> get trips => _trips;
  TripModel? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isSaving => _isSaving;
  String? get saveError => _saveError;
  // hasError kept for any external callers; maps to the detail flag.
  bool get hasError => _detailError;
  String get title => _title;
  LocationModel? get origin => _origin;
  LocationModel? get destination => _destination;
  List<LocationModel> get waypoints => _waypoints;
  List<UserModel> get participants => _participants;
  DateTime? get scheduledAt => _scheduledAt;

  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();
    try {
      _trips = await SupabaseTripService.getTrips();
    } catch (_) {
      _trips = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  String? _detailErrorMessage;
  String? get detailErrorMessage => _detailErrorMessage;

  Future<void> loadTripById(String id) async {
    _isLoadingDetail = true;
    _detailError = false;
    _detailErrorMessage = null;
    _selectedTrip = null;
    notifyListeners();
    try {
      _selectedTrip = await SupabaseTripService.getTripById(id);
      if (_selectedTrip == null) {
        _detailError = true;
        _detailErrorMessage = 'Viagem não encontrada.';
      }
    } catch (e) {
      _detailError = true;
      _detailErrorMessage = e.toString();
    }
    _isLoadingDetail = false;
    notifyListeners();
  }

  // Form setters
  void setTitle(String v) { _title = v; notifyListeners(); }
  void setOrigin(LocationModel? v) { _origin = v; notifyListeners(); }
  void setDestination(LocationModel? v) { _destination = v; notifyListeners(); }
  void setScheduledAt(DateTime? v) { _scheduledAt = v; notifyListeners(); }

  void addWaypoint(LocationModel loc) {
    _waypoints = [..._waypoints, loc];
    notifyListeners();
  }
  void removeWaypoint(int index) {
    _waypoints = [..._waypoints]..removeAt(index);
    notifyListeners();
  }
  void toggleParticipant(UserModel user) {
    if (_participants.any((u) => u.id == user.id)) {
      _participants = _participants.where((u) => u.id != user.id).toList();
    } else {
      _participants = [..._participants, user];
    }
    notifyListeners();
  }
  bool isParticipant(UserModel user) =>
      _participants.any((u) => u.id == user.id);

  void resetForm() {
    _title = '';
    _origin = null;
    _destination = null;
    _waypoints = [];
    _participants = [];
    _scheduledAt = null;
    notifyListeners();
  }

  /// Resets detail state and immediately enters loading mode.
  /// Called from TripDetailScreen.initState() before the first build.
  /// Sets _isLoadingDetail = true so the first build always shows the
  /// LoadingWidget, regardless of any previous navigation state.
  /// Uses the separate detail flags so loadTrips() can never interfere.
  void clearForLoad() {
    _isLoadingDetail = true;
    _detailError = false;
    _detailErrorMessage = null;
    _selectedTrip = null;
    // Intentionally no notifyListeners() — called from initState
  }

  Future<TripModel?> saveTrip() async {
    if (_title.isEmpty || _origin == null || _destination == null) return null;
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final trip = await SupabaseTripService.createTrip(
        title: _title,
        origin: _origin!,
        destination: _destination!,
        participantIds: _participants.map((u) => u.id).toList(),
        scheduledAt: _scheduledAt,
      );
      _trips = [trip, ..._trips];
      resetForm();
      _isSaving = false;
      notifyListeners();
      return trip;
    } catch (e) {
      _saveError = e.toString();
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> startTrip(String id) async {
    try {
      await SupabaseTripService.updateStatus(id, TripStatus.active);
      await loadTrips();
    } catch (_) {}
  }

  Future<void> deleteTrip(String id) async {
    try {
      await SupabaseTripService.deleteTrip(id);
      _trips = _trips.where((t) => t.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> leaveTrip(String id) async {
    try {
      await SupabaseTripService.leaveTrip(id);
      _trips = _trips.where((t) => t.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }
}
