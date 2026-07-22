import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../core/services/supabase_auth_service.dart';
import '../core/services/push_notification_service.dart';
import '../features/auth/viewmodels/auth_viewmodel.dart';
import '../features/home/viewmodels/home_viewmodel.dart';
import '../features/profile/viewmodels/profile_viewmodel.dart';
import '../features/profile/viewmodels/profile_customization_viewmodel.dart';
import '../features/social/viewmodels/social_viewmodel.dart';
import '../features/trips/viewmodels/trip_viewmodel.dart';
import '../features/rides/viewmodels/ride_viewmodel.dart';
import '../features/active_session/viewmodels/active_session_viewmodel.dart';
import '../features/notifications/viewmodels/notifications_viewmodel.dart';
import '../features/events/viewmodels/event_viewmodel.dart';
import 'routes.dart';

class RideApp extends StatefulWidget {
  const RideApp({super.key});

  @override
  State<RideApp> createState() => _RideAppState();
}

class _RideAppState extends State<RideApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Marca online ao abrir (se já estiver logado).
    SupabaseAuthService.setOnline(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // online quando em primeiro plano; offline quando sai/fecha.
    final online = state == AppLifecycleState.resumed;
    SupabaseAuthService.setOnline(online);
    // Ao voltar pro app, limpa as notificações já entregues na bandeja.
    if (online) {
      PushNotificationService.instance.clearDeliveredNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileCustomizationViewModel()),
        ChangeNotifierProvider(create: (_) => SocialViewModel()),
        ChangeNotifierProvider(create: (_) => TripViewModel()),
        ChangeNotifierProvider(create: (_) => RideViewModel()),
        ChangeNotifierProvider(create: (_) => ActiveSessionViewModel()),
        ChangeNotifierProvider(create: (_) => NotificationsViewModel()),
        ChangeNotifierProvider(create: (_) => EventViewModel()),
      ],
      child: MaterialApp.router(
        title: 'Ride - Rolês e Viagens',
        theme: AppTheme.light,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
