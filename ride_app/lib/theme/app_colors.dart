import 'package:flutter/material.dart';

/// Paleta do app. A maioria dos campos é `static const` (zero custo, zero
/// mudança de comportamento). Os campos de SUPERFÍCIE/TEXTO/MARCA que
/// precisam trocar no modo escuro viram getters que consultam [isDark] —
/// setado uma vez no boot (main.dart) e alterado pelo toggle em
/// Configurações > Aparência. Nada aqui depende de BuildContext: é lido
/// diretamente como `AppColors.background` em todo o app, então o estado
/// precisa ficar aqui (estático) para o rebuild global (ver app.dart)
/// recolorir tudo de uma vez.
class AppColors {
  AppColors._();

  static bool _isDark = false;
  static bool get isDark => _isDark;

  /// Troca o modo (chamado pelo ThemeViewModel). Não persiste nada — isso é
  /// responsabilidade de quem chama.
  static void setDark(bool value) => _isDark = value;

  // ── Marca (adapta no escuro: navy escuro fica ilegível em fundo preto) ──
  static Color get navy => _isDark ? const Color(0xFF6E8FC9) : const Color(0xFF1B3058);
  static Color get navyLight => _isDark ? const Color(0xFF8FA9D6) : const Color(0xFF2A4A7F);
  static const Color teal = Color(0xFF4BBECF);
  static const Color tealLight = Color(0xFF7DD4DF);

  // ── Background / Surface ────────────────────────────────────
  static Color get background => _isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color get surface => _isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FB);
  static Color get surfaceVariant => _isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3F4F6);
  static Color get card => _isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
  static Color get inputFill => _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8EAED);

  // ── Text ─────────────────────────────────────────────────────
  static Color get textPrimary => _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1B3058);
  static Color get textSecondary => _isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563);
  static Color get textMuted => _isDark ? const Color(0xFFA0A8B4) : const Color(0xFF9CA3AF);
  static Color get textHint => _isDark ? const Color(0xFF7C8798) : const Color(0xFFB0BAC6);

  // ── Status (mesmas cores nos dois modos — já contrastam bem) ────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = teal;

  // ── Misc ─────────────────────────────────────────────────────
  static Color get divider => _isDark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E7EB);
  static const Color overlay = Color(0x80000000);
  static const Color online = Color(0xFF22C55E);
  static const Color offline = Color(0xFF9CA3AF);
  static Color get deepNavy => navy; // alias kept for compat
  static Color get darkNavy => navyLight;
  static const Color mediumBlue = Color(0xFF3B6CB5);
  static const Color lightCyan = tealLight;
  static Color get primary => navy;
  static Color get primaryLight => navyLight;
  static const Color primaryDark = Color(0xFF0F1F3D);
  static Color get shimmerBase => _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8EAED);
  static Color get shimmerHighlight => _isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF3F4F6);
}
