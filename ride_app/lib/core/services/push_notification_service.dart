import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/routes.dart';
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
    if (_initialized) return;
    _initialized = true;
    try {
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

      await FirebaseMessaging.instance.requestPermission();

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
        if (_isAuthed) SupabaseNotificationService.saveDeviceToken(t);
      });

      if (_isAuthed) await registerForCurrentUser();
    } catch (e) {
      debugPrint('PushNotificationService.initialize: $e');
    }
  }

  /// Pega o token atual e salva em device_tokens para o usuário logado.
  Future<void> registerForCurrentUser() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await SupabaseNotificationService.saveDeviceToken(token);
      }
    } catch (e) {
      debugPrint('PushNotificationService.registerForCurrentUser: $e');
    }
  }

  /// Remove o token do aparelho — chamar ANTES do signOut (precisa do uid).
  Future<void> removeForCurrentUser() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
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
    try {
      await _local.cancelAll();
    } catch (_) {}
  }

  Future<void> _showForeground(RemoteMessage m) async {
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
