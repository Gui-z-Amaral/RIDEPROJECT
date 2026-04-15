import '../models/trip_model.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import 'mock_data.dart';

class MockTripService {
  static List<TripModel> _trips = List.from(MockData.trips);

  static Future<List<TripModel>> getTrips() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _trips;
  }

  static Future<TripModel?> getTripById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _trips.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<TripModel> createTrip(TripModel trip) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _trips.insert(0, trip);
    return trip;
  }

  static Future<TripModel> updateTrip(TripModel trip) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final idx = _trips.indexWhere((t) => t.id == trip.id);
    if (idx >= 0) _trips[idx] = trip;
    return trip;
  }

  static Future<void> deleteTrip(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _trips.removeWhere((t) => t.id == id);
  }

  static Future<void> startTrip(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final idx = _trips.indexWhere((t) => t.id == id);
    if (idx >= 0) {
      _trips[idx] = _trips[idx].copyWith(status: TripStatus.active);
    }
  }
}
