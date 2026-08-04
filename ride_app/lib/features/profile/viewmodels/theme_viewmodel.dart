import 'package:flutter/foundation.dart';
import '../../../core/services/theme_preference_service.dart';
import '../../../theme/app_colors.dart';

/// Controla o modo escuro do app inteiro. [AppColors] guarda o estado real
/// (lido diretamente em todas as telas); este ViewModel só existe para:
///  - notificar o widget raiz (app.dart) quando o modo muda, forçando o
///    rebuild de toda a árvore (o gatilho visual do toggle);
///  - persistir a escolha no aparelho.
///
/// `AppColors.setDark()` já é chamado uma vez no boot (main.dart), antes do
/// primeiro frame, para não haver flash de tema errado.
class ThemeViewModel extends ChangeNotifier {
  bool _isDarkMode = AppColors.isDark;
  bool get isDarkMode => _isDarkMode;

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    AppColors.setDark(value);
    notifyListeners();
    try {
      await ThemePreferenceService.save(value);
    } catch (_) {
      // best-effort: se não persistir, só volta ao padrão no próximo boot
    }
  }

  Future<void> toggle() => setDarkMode(!_isDarkMode);
}
