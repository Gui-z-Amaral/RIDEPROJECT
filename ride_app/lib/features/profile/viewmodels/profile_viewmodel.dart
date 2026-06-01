import 'package:flutter/material.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_auth_service.dart';

class ProfileViewModel extends ChangeNotifier {
  // Sentinel para distinguir "não alterar" vs "setar para null" em updates.
  static const _unset = Object();

  UserModel? _user;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _saveError;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get saveError => _saveError;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await SupabaseAuthService.getCurrentUser();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addPhoto(String url) async {
    try {
      final updated = await SupabaseAuthService.addPhoto(url);
      if (updated != null) {
        _user = updated;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? city,
    String? motoModel,
    String? motoYear,
    String? avatarUrl,
    String? accountType,
    Object? tripStyle = _unset, // null = limpa, _unset = não tocar
    // ── Business ──
    String? businessName,
    String? businessDescription,
    String? businessBannerUrl,
    String? businessAddressStreet,
    String? businessAddressNumber,
    String? businessAddressNeighborhood,
    String? businessAddressCity,
    String? businessAddressState,
    List<String>? businessCategories,
  }) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      final updated = await SupabaseAuthService.updateProfile(
        name: name,
        bio: bio,
        city: city,
        motoModel: motoModel,
        motoYear: motoYear,
        avatarUrl: avatarUrl,
        accountType: accountType,
        tripStyle: tripStyle,
        businessName: businessName,
        businessDescription: businessDescription,
        businessBannerUrl: businessBannerUrl,
        businessAddressStreet: businessAddressStreet,
        businessAddressNumber: businessAddressNumber,
        businessAddressNeighborhood: businessAddressNeighborhood,
        businessAddressCity: businessAddressCity,
        businessAddressState: businessAddressState,
        businessCategories: businessCategories,
      );
      if (updated != null) {
        _user = updated;
        _isSaving = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('❌ ProfileViewModel.updateProfile: $e');
      final msg = e.toString();
      _saveError = msg.contains('network') || msg.contains('SocketException')
          ? 'Sem conexão. Verifique sua internet e tente novamente.'
          : 'Não foi possível salvar. Tente novamente.';
    }

    _isSaving = false;
    notifyListeners();
    return false;
  }

  /// Muda o tipo de conta (pessoal ↔ empresa) e persiste.
  /// Retorna `true` se salvou com sucesso.
  Future<bool> setAccountType(String accountType) async {
    if (_user?.accountType == accountType) return true;
    return updateProfile(accountType: accountType);
  }

  /// Limpa estado — chamado no logout.
  void reset() {
    _user = null;
    _isLoading = false;
    _isSaving = false;
    notifyListeners();
  }
}
