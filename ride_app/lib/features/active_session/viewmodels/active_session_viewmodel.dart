import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/mock_data.dart';

enum ParticipantStatus { waiting, confirmed, declined }

class SessionParticipant {
  final UserModel user;
  ParticipantStatus status;
  double lat;
  double lng;

  SessionParticipant({required this.user, this.status = ParticipantStatus.waiting, required this.lat, required this.lng});
}

class ActiveSessionViewModel extends ChangeNotifier {
  bool _hasActiveSession = false;
  String _sessionId = '';
  String _sessionTitle = '';
  bool _isRide = true;
  bool _isLeader = true;
  bool _voiceChannelActive = false;
  bool _myVoiceMuted = false;
  List<SessionParticipant> _participants = [];
  bool _allConfirmed = false;
  List<UserModel> _newDestinations = [];

  bool get hasActiveSession => _hasActiveSession;
  String get sessionId => _sessionId;
  String get sessionTitle => _sessionTitle;
  bool get isRide => _isRide;
  bool get isLeader => _isLeader;
  bool get voiceChannelActive => _voiceChannelActive;
  bool get myVoiceMuted => _myVoiceMuted;
  List<SessionParticipant> get participants => _participants;
  bool get allConfirmed => _allConfirmed;
  int get confirmedCount => _participants.where((p) => p.status == ParticipantStatus.confirmed).length;

  void startSession({required String id, required String title, required bool isRide}) {
    _hasActiveSession = true;
    _sessionId = id;
    _sessionTitle = title;
    _isRide = isRide;
    _isLeader = true;
    _allConfirmed = false;
    _participants = MockData.friends.take(4).map((u) => SessionParticipant(
      user: u, status: ParticipantStatus.waiting, lat: -27.59 + (u.id.hashCode % 10) * 0.001, lng: -48.54 + (u.id.hashCode % 10) * 0.001,
    )).toList();
    notifyListeners();
  }

  void confirmParticipant(String userId) {
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx >= 0) {
      _participants[idx].status = ParticipantStatus.confirmed;
      _allConfirmed = _participants.every((p) => p.status == ParticipantStatus.confirmed);
      notifyListeners();
    }
  }

  // Simulate participants confirming over time
  Future<void> simulateConfirmations() async {
    for (final p in _participants) {
      await Future.delayed(const Duration(seconds: 2));
      p.status = ParticipantStatus.confirmed;
      _allConfirmed = _participants.every((p) => p.status == ParticipantStatus.confirmed);
      notifyListeners();
    }
  }

  void toggleVoiceChannel() {
    _voiceChannelActive = !_voiceChannelActive;
    notifyListeners();
  }

  void toggleMute() {
    _myVoiceMuted = !_myVoiceMuted;
    notifyListeners();
  }

  void transferLeadership(String userId) {
    // Visual leadership transfer
    notifyListeners();
  }

  void endSession() {
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
    final idx = _participants.indexWhere((p) => p.user.id == userId);
    if (idx >= 0) {
      _participants[idx].lat = lat;
      _participants[idx].lng = lng;
      notifyListeners();
    }
  }
}
