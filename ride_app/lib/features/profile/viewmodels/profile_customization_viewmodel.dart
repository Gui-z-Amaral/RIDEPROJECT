import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/models/profile_customization.dart';
import '../../../core/services/supabase_profile_customization_service.dart';

/// Personalização visual do PRÓPRIO usuário (banner, moldura, cores).
/// Compartilhado entre a tela de perfil e a de Configurações > Aparência,
/// para que uma edição apareça imediatamente nas duas.
class ProfileCustomizationViewModel extends ChangeNotifier {
  ProfileCustomization? _customization;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _saveError;

  ProfileCustomization? get customization => _customization;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get saveError => _saveError;

  Future<void> load(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _customization = await SupabaseProfileCustomizationService.get(userId);
    } catch (_) {
      _customization = ProfileCustomization.empty(userId);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> save(ProfileCustomization updated) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();
    try {
      await SupabaseProfileCustomizationService.save(updated);
      _customization = updated;
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ProfileCustomizationViewModel.save: $e');
      _saveError = 'Não foi possível salvar. Tente novamente.';
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> uploadBanner(Uint8List bytes) async {
    try {
      return await SupabaseProfileCustomizationService.uploadBanner(bytes);
    } catch (e) {
      debugPrint('❌ ProfileCustomizationViewModel.uploadBanner: $e');
      return null;
    }
  }

  Future<bool> resetToDefault(String userId) async {
    _isSaving = true;
    notifyListeners();
    try {
      await SupabaseProfileCustomizationService.reset();
      _customization = ProfileCustomization.empty(userId);
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ ProfileCustomizationViewModel.resetToDefault: $e');
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Limpa estado — chamado no logout.
  void reset() {
    _customization = null;
    _isLoading = false;
    _isSaving = false;
    _saveError = null;
    notifyListeners();
  }
}
