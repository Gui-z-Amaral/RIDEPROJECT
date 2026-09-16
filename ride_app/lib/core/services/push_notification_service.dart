import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/routes.dart';
import '../constants/firebase_web_config.dart';
import '../utils/notification_router.dart';
import 'supabase_notification_service.dart';

/// Integração de push (FCM):
///  - pede permissão (Android 13+),
///  - registra o token do aparelho em `device_tokens`,
///  - exibe a notificação quando o app está em PRIMEIRO PLANO
///    (em background/fechado o Android exibe sozinho),
///  - navega para a tela certa ao tocar (via [routeForNotification]).
///
/// O ENVIO em si é feito pelo worker na VPS — aqui é só o lado do cliente.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// userId da conversa aberta no momento. Setado pela ChatScreen ao entrar e
  /// limpo ao sair. Usado para NÃO exibir push de mensagem de quem você já
  /// está conversando (foreground).
  static String? activeChatUserId;

  // Deve casar com o channel_id do worker e do AndroidManifest.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'rideapp_default',
    'Notificações',
    description: 'Mensagens, convites e eventos',
    importance: Importance.high,
  );

  bool get _isAuthed =>
      Supabase.instance.client.auth.currentUser != null;

  /// Configura permissão, canal, listeners e registra o token se já logado.
  /// Tolerante a falha (ex: device sem Google Play Services).
  Future<void> initialize() async {
    // Na web, sem a chave VAPID não há como inscrever no push — pula em
    // silêncio em vez de estourar.
    if (kIsWeb && !FirebaseWebConfig.hasVapidKey) return;
    if (_initialized) return;
    _initialized = true;
    try {
      // Notificações locais são só do Android (o pacote não tem web). Na web
      // quem exibe com o app fechado é o service worker do FCM.
      if (!kIsWeb) {
        const androidInit =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        await _local.initialize(
          const InitializationSettings(android: androidInit),
          onDidReceiveNotificationResponse: (resp) {
            final payload = resp.payload;
            if (payload != null && payload.isNotEmpty) _navigate(payload);
          },
        );
        await _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
      }

      // No Android pedir aqui é o esperado. Na WEB, pedir permissão no
      // carregamento da página é má prática: o navegador penaliza e quem
      // dispensa pode acabar bloqueando notificações para sempre. Lá a
      // permissão é pedida em registerForCurrentUser — ou seja, depois que a
      // pessoa fez login, uma ação dela.
      if (!kIsWeb) await FirebaseMessaging.instance.requestPermission();

      // App em primeiro plano → exibe manualmente.
      FirebaseMessaging.onMessage.listen(_showForeground);
      // Toque com app em segundo plano.
      FirebaseMessaging.onMessageOpenedApp
          .listen((m) => _navigate(_routeFrom(m)));
      // Toque com app fechado (mensagem que abriu o app).
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _navigate(_routeFrom(initial)));
      }
      // Token rotacionado.
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        if (_isAuthed) {
          SupabaseNotificationService.saveDeviceToken(
            t,
            platform: kIsWeb ? 'web' : 'android',
          );
        }
      });

      if (_isAuthed) await registerForCurrentUser();
    } catch (e) {
      debugPrint('PushNotificationService.initialize: $e');
    }
  }

  /// Pega o token atual e salva em device_tokens para o usuário logado.
  Future<void> registerForCurrentUser() async {
    if (kIsWeb && !FirebaseWebConfig.hasVapidKey) return;
    try {
      if (kIsWeb) {
        // Chegou aqui = usuário logado. É o momento certo de pedir.
        final settings = await FirebaseMessaging.instance.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      }
      final token = await _currentToken();
      if (token != null) {
        await SupabaseNotificationService.saveDeviceToken(
          token,
          platform: kIsWeb ? 'web' : 'android',
        );
      }
    } catch (e) {
      debugPrint('PushNotificationService.registerForCurrentUser: $e');
    }
  }

  /// Remove o token do aparelho — chamar ANTES do signOut (precisa do uid).
  Future<void> removeForCurrentUser() async {
    if (kIsWeb && !FirebaseWebConfig.hasVapidKey) return;
    try {
      final token = await _currentToken();
      if (token != null) {
        await SupabaseNotificationService.removeDeviceToken(token);
      }
    } catch (e) {
      debugPrint('PushNotificationService.removeForCurrentUser: $e');
    }
  }

  /// Remove as notificações já entregues na bandeja do sistema. Chamado ao
  /// abrir/voltar para o app (toque no push ou retorno ao foreground).
  Future<void> clearDeliveredNotifications() async {
    if (kIsWeb) return;
    try {
      await _local.cancelAll();
    } catch (_) {}
  }

  /// Token FCM deste aparelho/navegador. Na web o `getToken` exige a chave
  /// VAPID; no Android ela não existe.
  Future<String?> _currentToken() => kIsWeb
      ? FirebaseMessaging.instance
          .getToken(vapidKey: FirebaseWebConfig.vapidKey)
      : FirebaseMessaging.instance.getToken();

  Future<void> _showForeground(RemoteMessage m) async {
    // Na web, com o app ABERTO, a lista de notificações já se atualiza sozinha
    // pelo realtime do Supabase — exibir outra aqui seria duplicar o aviso.
    // Com o app fechado, quem mostra é o service worker.
    if (kIsWeb) return;
    final n = m.notification;
    if (n == null) return;
    // Não notifica mensagem de quem o usuário já está conversando agora.
    if (!shouldShowForegroundNotification(
      type: m.data['type'] as String?,
      payload: _payloadOf(m),
      activeChatUserId: activeChatUserId,
    )) {
      return;
    }
    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: _routeFrom(m),
    );
  }

  Map<String, dynamic> _payloadOf(RemoteMessage m) {
    final raw = m.data['payload'];
    if (raw is String && raw.isNotEmpty) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  String _routeFrom(RemoteMessage m) =>
      routeForNotification(m.data['type'] as String?, _payloadOf(m));

  void _navigate(String route) {
    // Abriu via toque no push → limpa a bandeja.
    clearDeliveredNotifications();
    try {
      router.push(route);
    } catch (e) {
      debugPrint('PushNotificationService._navigate: $e');
    }
  }
}
