import 'package:flutter/material.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/location_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_ride_service.dart';

class RideViewModel extends ChangeNotifier {
  List<RideModel> _rides = [];
  RideModel? _selectedRide;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _saveError;

  // Form state
  String _title = '';
  LocationModel? _meetingPoint;
  List<UserModel> _participants = [];
  DateTime? _scheduledAt;
  bool _isImmediate = false;

  List<RideModel> get rides => _rides;
  RideModel? get selectedRide => _selectedRide;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get saveError => _saveError;
  String get title => _title;
  LocationModel? get meetingPoint => _meetingPoint;
  List<UserModel> get participants => _participants;
  DateTime? get scheduledAt => _scheduledAt;
  bool get isImmediate => _isImmediate;

  Future<void> loadRides() async {
    _isLoading = true;
    notifyListeners();
    try {
      _rides = await SupabaseRideService.getRides();
    } catch (_) {
      _rides = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadRideById(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      _selectedRide = await SupabaseRideService.getRideById(id);
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  // Form setters
  void setTitle(String v) { _title = v; notifyListeners(); }
  void setMeetingPoint(LocationModel? v) { _meetingPoint = v; notifyListeners(); }
  void setScheduledAt(DateTime? v) { _scheduledAt = v; notifyListeners(); }
  void setImmediate(bool v) { _isImmediate = v; notifyListeners(); }

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
    _meetingPoint = null;
    _participants = [];
    _scheduledAt = null;
    _isImmediate = false;
    notifyListeners();
  }

  Future<RideModel?> saveRide() async {
    if (_title.isEmpty || _meetingPoint == null) return null;
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      final ride = await SupabaseRideService.createRide(
        title: _title,
        meetingPoint: _meetingPoint!,
        participantIds: _participants.map((u) => u.id).toList(),
        scheduledAt: _scheduledAt,
        isImmediate: _isImmediate,
      );
      _rides = [ride, ..._rides];
      resetForm();
      _isSaving = false;
      notifyListeners();
      return ride;
    } catch (e) {
      _saveError = e.toString();
      _isSaving = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> startRide(String id) async {
    try {
      await SupabaseRideService.updateStatus(id, RideStatus.active);
      await loadRides();
    } catch (_) {}
  }

  Future<void> deleteRide(String id) async {
    try {
      await SupabaseRideService.deleteRide(id);
      _rides = _rides.where((r) => r.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }
}
