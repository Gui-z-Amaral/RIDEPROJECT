import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/social/screens/friends_screen.dart';
import '../features/social/screens/search_users_screen.dart';
import '../features/social/screens/chat_screen.dart';
import '../features/social/screens/invites_screen.dart';
import '../features/trips/screens/trips_list_screen.dart';
import '../features/trips/screens/trip_detail_screen.dart';
import '../features/trips/screens/create_trip_screen.dart';
import '../features/trips/screens/start_trip_screen.dart';
import '../features/rides/screens/rides_list_screen.dart';
import '../features/rides/screens/ride_detail_screen.dart';
import '../features/rides/screens/create_ride_screen.dart';
import '../features/rides/screens/schedule_ride_screen.dart';
import '../features/rides/screens/start_ride_screen.dart';
import '../features/active_session/screens/waiting_screen.dart';
import '../features/active_session/screens/active_map_screen.dart';
import '../features/active_session/screens/guest_confirm_screen.dart';
import '../features/map/screens/map_select_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/calls/screens/voice_call_screen.dart';
import '../features/calls/screens/group_voice_screen.dart';
import 'shell_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/trips', builder: (_, __) => const TripsListScreen()),
        GoRoute(path: '/rides', builder: (_, __) => const RidesListScreen()),
        GoRoute(path: '/friends', builder: (_, __) => const FriendsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),

    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: '/friends/search', builder: (_, __) => const SearchUsersScreen()),
    GoRoute(
      path: '/friends/chat/:userId',
      builder: (_, state) => ChatScreen(userId: state.pathParameters['userId']!),
    ),
    GoRoute(path: '/friends/invites', builder: (_, __) => const InvitesScreen()),

    GoRoute(path: '/trips/create', builder: (_, __) => const CreateTripScreen()),
    GoRoute(
      path: '/trips/:id',
      builder: (_, state) => TripDetailScreen(tripId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/trips/start',
      builder: (_, state) {
        final e = state.extra as Map<String, dynamic>;
        return StartTripScreen(
          lat: (e['lat'] as num).toDouble(),
          lng: (e['lng'] as num).toDouble(),
          placeName: e['name'] as String,
          placeAddress: e['address'] as String,
          originLat: (e['originLat'] as num?)?.toDouble(),
          originLng: (e['originLng'] as num?)?.toDouble(),
        );
      },
    ),

    GoRoute(path: '/rides/create', builder: (_, __) => const CreateRideScreen()),
    GoRoute(
      path: '/rides/:id',
      builder: (_, state) => RideDetailScreen(rideId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/rides/schedule', builder: (_, __) => const ScheduleRideScreen()),
    GoRoute(
      path: '/rides/start',
      builder: (_, state) {
        final e = state.extra as Map<String, dynamic>;
        return StartRideScreen(
          lat: (e['lat'] as num).toDouble(),
          lng: (e['lng'] as num).toDouble(),
          placeName: e['name'] as String,
          placeAddress: e['address'] as String,
        );
      },
    ),

    GoRoute(
      path: '/session/waiting/:id',
      builder: (_, state) => WaitingScreen(sessionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/session/active/:id',
      builder: (_, state) => ActiveMapScreen(sessionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/session/confirm/:id',
      builder: (_, state) => GuestConfirmScreen(sessionId: state.pathParameters['id']!),
    ),

    GoRoute(
      path: '/map/select',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return MapSelectScreen(
          title: extra?['title'] ?? 'Selecionar local',
          onSelected: extra?['onSelected'],
        );
      },
    ),

    GoRoute(
      path: '/calls/voice/:userId',
      builder: (_, state) => VoiceCallScreen(userId: state.pathParameters['userId']!),
    ),
    GoRoute(
      path: '/calls/group/:sessionId',
      builder: (_, state) => GroupVoiceScreen(sessionId: state.pathParameters['sessionId']!),
    ),
  ],
);
