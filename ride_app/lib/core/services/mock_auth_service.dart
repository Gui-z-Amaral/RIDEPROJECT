import '../models/user_model.dart';
import 'mock_data.dart';

class MockAuthService {
  static UserModel? _currentUser;
  static bool _isAuthenticated = false;

  static UserModel? get currentUser => _currentUser;
  static bool get isAuthenticated => _isAuthenticated;

  static Future<UserModel?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (email.isNotEmpty && password.isNotEmpty) {
      _currentUser = MockData.currentUser;
      _isAuthenticated = true;
      return _currentUser;
    }
    return null;
  }

  static Future<UserModel?> register({
    required String name,
    required String email,
    required String password,
    String? username,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    _currentUser = MockData.currentUser.copyWith(name: name, username: username ?? '@${name.toLowerCase().replaceAll(' ', '')}');
    _isAuthenticated = true;
    return _currentUser;
  }

  static Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    _isAuthenticated = false;
  }

  static Future<void> updateProfile(UserModel updated) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = updated;
  }
}
