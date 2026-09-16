import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/firebase_web_config.dart';
import 'core/constants/supabase_config.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/theme_preference_service.dart';
import 'core/utils/url_strategy.dart';
import 'theme/app_colors.dart';
import 'app/app.dart';

/// Handler de push em segundo plano/fechado. Quando a mensagem traz bloco
/// `notification` (é o caso do worker), o Android exibe sozinho — não há nada
/// a fazer aqui, mas o FCM exige uma função top-level registrada.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URL sem `#` na web. Tem que vir antes do runApp: é o que permite o link
  // compartilhado (`/v/<id>`) abrir direto no conteúdo — com `#`, o Flutter
  // iniciava em `/` e o link caía no splash. No nativo é no-op.
  configureUrlStrategy();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializa locale pt_BR para DateFormat (relativeLabel/formattedShort)
  await initializeDateFormatting('pt_BR', null);

  // Carrega o modo escuro ANTES do primeiro frame — evita flash do tema errado.
  try {
    final isDark = await ThemePreferenceService.load();
    AppColors.setDark(isDark);
  } catch (_) {}

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    // Chave FIXA de onde a sessão fica guardada.
    //
    // Por padrão o pacote monta a chave a partir do host
    // (`sb-${host.split('.').first}-auth-token`), então trocar o domínio da API
    // deslogaria todo mundo: a sessão continuaria salva, mas debaixo de um nome
    // que o app não procura mais. Fixando aqui, o domínio pode mudar sem
    // derrubar ninguém.
    authOptions: FlutterAuthClientOptions(
      localStorage: SharedPreferencesLocalStorage(
        persistSessionKey: SupabaseConfig.sessionKey,
      ),
    ),
  );

  // Push notifications (FCM). Tolerante a falha — não bloqueia o app se o
  // device não tiver Google Play Services ou o Firebase falhar ao iniciar.
  try {
    // Android lê o google-services.json; a web precisa das opções na mão.
    await Firebase.initializeApp(
      options: kIsWeb ? FirebaseWebConfig.options : null,
    );
    // Na web quem exibe a notificação com o app fechado é o service worker
    // (web/firebase-messaging-sw.js), não um handler Dart.
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    }
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Push init falhou (seguindo sem push): $e');
  }

  runApp(const RideApp());
}