import 'package:shared_preferences/shared_preferences.dart';

/// Persistência local (por aparelho) do modo escuro. Diferente das outras
/// preferências do app (que ficam no Supabase), esta fica só no dispositivo:
/// é uma configuração de exibição instantânea, sem necessidade de round-trip
/// de rede nem de sincronizar entre aparelhos.
class ThemePreferenceService {
  static const _key = 'dark_mode_enabled';

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> save(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}
