import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/utils/notification_router.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../theme/app_colors.dart';

/// Ponto de chegada de quem tocou numa notificação push na web (`/n?t=&p=`).
///
/// O service worker não sabe para onde cada tipo de notificação vai — e não
/// deve saber: o mapeamento vive em [routeForNotification], e tê-lo também em
/// JavaScript garantiria que um dia os dois discordassem. Ele entrega o `type`
/// e o `payload` crus e esta tela resolve.
///
/// Sem sessão, manda para o login levando o destino no `next`, então depois de
/// entrar a pessoa chega onde a notificação prometia — e não na tela de início.
class NotificationRouteScreen extends StatefulWidget {
  final String type;
  final String payloadJson;

  const NotificationRouteScreen({
    super.key,
    required this.type,
    required this.payloadJson,
  });

  @override
  State<NotificationRouteScreen> createState() =>
      _NotificationRouteScreenState();
}

class _NotificationRouteScreenState extends State<NotificationRouteScreen> {
  @override
  void initState() {
    super.initState();
    // Depois do primeiro frame: navegar durante o build derruba o GoRouter.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolver());
  }

  void _resolver() {
    if (!mounted) return;

    Map<String, dynamic> payload = const {};
    try {
      final d = jsonDecode(widget.payloadJson);
      if (d is Map) payload = Map<String, dynamic>.from(d);
    } catch (_) {
      // Payload corrompido não pode virar tela branca: cai na lista.
    }

    final destino = routeForNotification(widget.type, payload);
    final logado = Supabase.instance.client.auth.currentUser != null;

    if (logado) {
      context.go(destino);
    } else {
      context.go('/login?next=${Uri.encodeQueryComponent(
          AppLinks.safeNext(destino, fallback: '/notifications'))}');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: LoadingWidget(),
      );
}
