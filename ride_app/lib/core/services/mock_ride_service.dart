import '../models/ride_model.dart';
import 'mock_data.dart';

class MockRideService {
  static List<RideModel> _rides = List.from(MockData.rides);

  static Future<List<RideModel>> getRides() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _rides;
  }

  static Future<RideModel?> getRideById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _rides.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<RideModel> createRide(RideModel ride) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _rides.insert(0, ride);
    return ride;
  }

  static Future<void> startRide(String id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final idx = _rides.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _rides[idx] = _rides[idx].copyWith(status: RideStatus.active);
    }
  }

  static Future<void> confirmParticipation(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  static Future<void> leaveRide(String rideId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }
}
