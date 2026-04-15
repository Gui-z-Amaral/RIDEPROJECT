import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../features/auth/viewmodels/auth_viewmodel.dart';
import '../features/home/viewmodels/home_viewmodel.dart';
import '../features/profile/viewmodels/profile_viewmodel.dart';
import '../features/social/viewmodels/social_viewmodel.dart';
import '../features/trips/viewmodels/trip_viewmodel.dart';
import '../features/rides/viewmodels/ride_viewmodel.dart';
import '../features/active_session/viewmodels/active_session_viewmodel.dart';
import '../features/notifications/viewmodels/notifications_viewmodel.dart';
import 'routes.dart';

class RideApp extends StatelessWidget {
  const RideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => SocialViewModel()),
        ChangeNotifierProvider(create: (_) => TripViewModel()),
        ChangeNotifierProvider(create: (_) => RideViewModel()),
        ChangeNotifierProvider(create: (_) => ActiveSessionViewModel()),
        ChangeNotifierProvider(create: (_) => NotificationsViewModel()),
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
