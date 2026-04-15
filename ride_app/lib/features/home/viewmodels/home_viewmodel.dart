import 'package:flutter/material.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/models/ride_model.dart';
import '../../../core/models/stop_model.dart';
import '../../../core/services/supabase_trip_service.dart';
import '../../../core/services/supabase_ride_service.dart';

class HomeViewModel extends ChangeNotifier {
  List<TripModel> _upcomingTrips = [];
  List<RideModel> _upcomingRides = [];
  List<StopModel> _suggestedStops = [];
  bool _isLoading = false;

  List<TripModel> get upcomingTrips => _upcomingTrips;
  List<RideModel> get upcomingRides => _upcomingRides;
  List<StopModel> get suggestedStops => _suggestedStops;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        SupabaseTripService.getTrips(),
        SupabaseRideService.getRides(),
      ]);
      _upcomingTrips = (results[0] as List<TripModel>)
          .where((t) => t.status == TripStatus.planned || t.status == TripStatus.active)
          .take(5)
          .toList();
      _upcomingRides = (results[1] as List<RideModel>)
          .where((r) => r.status != RideStatus.completed && r.status != RideStatus.cancelled)
          .take(5)
          .toList();
      _suggestedStops = [];
    } catch (_) {
      _upcomingTrips = [];
      _upcomingRides = [];
    }
    _isLoading = false;
    notifyListeners();
  }
}
