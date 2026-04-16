import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_auth_service.dart';

class ProfileViewModel extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _isSaving = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await SupabaseAuthService.getCurrentUser();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? city,
    String? motoModel,
    String? motoYear,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final updated = await SupabaseAuthService.updateProfile(
        name: name,
        bio: bio,
        city: city,
        motoModel: motoModel,
        motoYear: motoYear,
      );
      if (updated != null) {
        _user = updated;
        _isSaving = false;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    _isSaving = false;
    notifyListeners();
    return false;
  }
}
