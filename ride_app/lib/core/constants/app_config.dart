/// Configurações centrais do app.
///
/// COMO CONFIGURAR A CHAVE DO GOOGLE MAPS:
///
/// Opção 1 — Diretamente neste arquivo (desenvolvimento local):
///   Substitua 'SUA_CHAVE_AQUI' pela sua chave abaixo.
///   ⚠️ Adicione este arquivo ao .gitignore se usar essa opção.
///
/// Opção 2 — Via --dart-define (recomendado para CI/CD):
///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
///   flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=AIza...
///
/// Opção 3 — Via arquivo local.properties (Android):
///   Adicione em android/local.properties:
///   GOOGLE_MAPS_API_KEY=AIza...
///   E leia com project.findProperty("GOOGLE_MAPS_API_KEY") no build.gradle.kts

class AppConfig {
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyBD-bHMpes0uBYnifhR17r0eCExVLej_Xo',
  );

  static bool get hasValidMapsKey => true;
}
