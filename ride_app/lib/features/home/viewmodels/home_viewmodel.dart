import 'package:flutter/material.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../../core/services/supabase_ride_service.dart';
import '../../../core/services/supabase_social_service.dart';
import '../../../core/services/places_service.dart';

class HomeViewModel extends ChangeNotifier {
  List<TripModel> _upcomingTrips = [];
  List<RideModel> _upcomingRides = [];
  List<PlaceRecommendation> _recommendations = [];
  List<FriendTripStory> _friendStories = [];
  bool _isLoading = false;
  bool _isLoadingRecs = false;
  bool _isLoadingStories = false;

  List<TripModel> get upcomingTrips => _upcomingTrips;
  List<RideModel> get upcomingRides => _upcomingRides;
  List<PlaceRecommendation> get recommendations => _recommendations;
  List<FriendTripStory> get friendStories => _friendStories;
  bool get isLoading => _isLoading;
  bool get isLoadingRecs => _isLoadingRecs;
  bool get isLoadingStories => _isLoadingStories;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        SupabaseTripService.getTrips(),
        SupabaseRideService.getRides(),
      ]);
      _upcomingTrips = (results[0] as List<TripModel>)
          .where((t) =>
              t.status == TripStatus.planned ||
              t.status == TripStatus.active)
          .take(5)
          .toList();
      _upcomingRides = (results[1] as List<RideModel>)
          .where((r) =>
              r.status != RideStatus.completed &&
              r.status != RideStatus.cancelled)
          .take(5)
          .toList();
    } catch (_) {
      _upcomingTrips = [];
      _upcomingRides = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadFriendsStories() async {
    _isLoadingStories = true;
    notifyListeners();
    try {
      _friendStories = await SupabaseSocialService.getFriendsRecentTrips();
    } catch (_) {
      _friendStories = [];
    }
    _isLoadingStories = false;
    notifyListeners();
  }

  /// Carrega recomendações de lugares com base na localização do usuário.
  /// Usa o destino da próxima viagem planejada para sugerir lugares no destino.
  Future<void> loadRecommendations(double lat, double lng) async {
    _isLoadingRecs = true;
    notifyListeners();
    try {
      String? tripDestName;
      double? tripDestLat;
      double? tripDestLng;

      if (_upcomingTrips.isNotEmpty) {
        final dest = _upcomingTrips.first.destination;
        tripDestLat = dest.lat;
        tripDestLng = dest.lng;
        final raw = (dest.label ?? dest.address ?? '').split(',').first.trim();
        if (raw.isNotEmpty) tripDestName = raw;
      }

      _recommendations = await PlacesService.getRecommendations(
        lat: lat,
        lng: lng,
        tripDestLat: tripDestLat,
        tripDestLng: tripDestLng,
        tripDestName: tripDestName,
      );
    } catch (_) {
      _recommendations = [];
    }
    _isLoadingRecs = false;
    notifyListeners();
  }
}
