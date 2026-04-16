import 'package:flutter/material.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_trip_service.dart';

class TripViewModel extends ChangeNotifier {
  List<TripModel> _trips = [];
  TripModel? _selectedTrip;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _hasError = false;

  // Form state
  String _title = '';
  LocationModel? _origin;
  LocationModel? _destination;
  List<LocationModel> _waypoints = [];
  List<UserModel> _participants = [];
  RouteType _routeType = RouteType.none;
  DateTime? _scheduledAt;

  List<TripModel> get trips => _trips;
  TripModel? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasError => _hasError;
  String get title => _title;
  LocationModel? get origin => _origin;
  LocationModel? get destination => _destination;
  List<LocationModel> get waypoints => _waypoints;
  List<UserModel> get participants => _participants;
  RouteType get routeType => _routeType;
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

  Future<void> loadTripById(String id) async {
    _isLoading = true;
    _hasError = false;
    _selectedTrip = null;
    notifyListeners();
    try {
      _selectedTrip = await SupabaseTripService.getTripById(id);
      if (_selectedTrip == null) _hasError = true;
    } catch (_) {
      _hasError = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  // Form setters
  void setTitle(String v) { _title = v; notifyListeners(); }
  void setOrigin(LocationModel? v) { _origin = v; notifyListeners(); }
  void setDestination(LocationModel? v) { _destination = v; notifyListeners(); }
  void setRouteType(RouteType v) { _routeType = v; notifyListeners(); }
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
    _routeType = RouteType.none;
    _scheduledAt = null;
    notifyListeners();
  }

  /// Resets detail state synchronously (no notifyListeners) so the very
  /// first build of TripDetailScreen always shows LoadingWidget instead of
  /// a stale error/trip from a previous navigation.
  void clearForLoad() {
    _hasError = false;
    _selectedTrip = null;
    // intentionally no notifyListeners — loadTripById will call it
  }

  Future<TripModel?> saveTrip() async {
    if (_title.isEmpty || _origin == null || _destination == null) return null;
    _isSaving = true;
    notifyListeners();
    try {
      final trip = await SupabaseTripService.createTrip(
        title: _title,
        origin: _origin!,
        destination: _destination!,
        participantIds: _participants.map((u) => u.id).toList(),
        routeType: _routeType,
        scheduledAt: _scheduledAt,
      );
      _trips = [trip, ..._trips];
      resetForm();
      _isSaving = false;
      notifyListeners();
      return trip;
    } catch (_) {
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
