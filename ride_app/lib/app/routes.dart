import 'package:go_router/go_router.dart';
import '../core/models/share_preview.dart';
import '../core/models/user_model.dart';
import '../features/share/screens/shared_link_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/edit_business_profile_screen.dart';
import '../features/profile/screens/settings_screen.dart';
import '../features/profile/screens/profile_appearance_screen.dart';
import '../features/profile/screens/history_screen.dart';
import '../features/social/screens/friend_profile_screen.dart';
import '../features/social/screens/search_users_screen.dart';
import '../features/social/screens/chat_screen.dart';
import '../features/social/screens/messages_screen.dart';
import '../features/social/screens/nearby_riders_screen.dart';
import '../features/social/screens/invites_screen.dart';
import '../features/events/screens/events_screen.dart';
import '../features/trips/screens/trips_list_screen.dart';
import '../features/trips/screens/trip_detail_screen.dart';
import '../features/trips/screens/create_trip_screen.dart';
import '../features/rides/screens/rides_list_screen.dart';
import '../features/rides/screens/ride_detail_screen.dart';
import '../features/rides/screens/create_ride_screen.dart';
import '../features/rides/screens/schedule_ride_screen.dart';
import '../features/active_session/screens/waiting_screen.dart';
import '../features/active_session/screens/active_map_screen.dart';
import '../features/active_session/screens/guest_confirm_screen.dart';
import '../features/active_session/screens/finish_trip_screen.dart';
import '../features/map/screens/map_select_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/businesses/screens/businesses_screen.dart';
import '../features/events/screens/create_event_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/calls/screens/voice_call_screen.dart';
import '../features/calls/screens/group_voice_screen.dart';
import '../features/clubs/screens/clubs_tab_screen.dart';
import '../features/clubs/screens/create_club_screen.dart';
import '../features/clubs/screens/club_profile_screen.dart';
import '../features/clubs/screens/club_settings_screen.dart';
import '../features/clubs/screens/manage_members_screen.dart';
import '../features/clubs/screens/attendance_screen.dart';
import '../features/clubs/screens/trip_schedule_screen.dart';
import 'shell_screen.dart';

final router = GoRouter(
  initialLocation: '/splash',
  // Com o deep linking nativo ligado, a abertura normal chega como '/'.
  // Redireciona pra splash; deep links (/e/:id etc.) passam direto.
  redirect: (context, state) => state.uri.path == '/' ? '/splash' : null,
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: '/verify-email',
      builder: (_, state) =>
          VerifyEmailScreen(email: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (_, state) =>
          ForgotPasswordScreen(initialEmail: state.extra as String?),
    ),

    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/trips', builder: (_, __) => const TripsListScreen()),
        GoRoute(path: '/rides', builder: (_, __) => const RidesListScreen()),
        GoRoute(path: '/clubs', builder: (_, __) => const ClubsTabScreen()),
        GoRoute(path: '/events', builder: (_, __) => const EventsScreen()),
        GoRoute(path: '/chat', builder: (_, __) => const MessagesScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    ),

    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
    GoRoute(path: '/businesses', builder: (_, __) => const BusinessesScreen()),
    GoRoute(
      path: '/events/create',
      builder: (_, state) => CreateEventScreen(
        clubId: (state.extra as Map?)?['clubId'] as String?,
      ),
    ),
    GoRoute(
      path: '/events/:id/edit',
      builder: (_, state) =>
          CreateEventScreen(eventId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (_, state) => EventDetailScreen(eventId: state.pathParameters['id']!),
    ),

    // ── Deep links curtos (compartilhamento) → resolvem no app ──
    // Passam pelo SharedLinkScreen: logado cai no detalhe de sempre, visitante
    // vê a prévia pública com convite para entrar.
    GoRoute(
      path: '/e/:id',
      builder: (_, state) => SharedLinkScreen(
          kind: ShareKind.event, id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/v/:id',
      builder: (_, state) => SharedLinkScreen(
          kind: ShareKind.trip, id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/r/:id',
      builder: (_, state) => SharedLinkScreen(
          kind: ShareKind.ride, id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/c/:id',
      builder: (_, state) =>
          ClubProfileScreen(clubId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: '/profile/business/edit', builder: (_, __) => const EditBusinessProfileScreen()),
    GoRoute(path: '/profile/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/profile/appearance', builder: (_, __) => const ProfileAppearanceScreen()),
    GoRoute(path: '/profile/history', builder: (_, __) => const HistoryScreen()),
    GoRoute(path: '/friends/search', builder: (_, __) => const SearchUsersScreen()),
    GoRoute(
      path: '/friends/chat/:userId',
      builder: (_, state) => ChatScreen(userId: state.pathParameters['userId']!),
    ),
    GoRoute(path: '/friends/invites', builder: (_, __) => const InvitesScreen()),
    GoRoute(path: '/riders/nearby', builder: (_, __) => const NearbyRidersScreen()),
    GoRoute(
      path: '/profile/:userId',
      builder: (_, state) {
        final user = state.extra as UserModel;
        return FriendProfileScreen(user: user);
      },
    ),

    GoRoute(
      path: '/trips/create',
      builder: (_, state) => CreateTripScreen(
        clubId: (state.extra as Map?)?['clubId'] as String?,
      ),
    ),
    GoRoute(
      path: '/trips/:id',
      builder: (_, state) => TripDetailScreen(tripId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/trips/:id/edit',
      builder: (_, state) =>
          CreateTripScreen(tripId: state.pathParameters['id']!),
    ),

    GoRoute(path: '/clubs/create', builder: (_, __) => const CreateClubScreen()),
    GoRoute(
      path: '/clubs/:id/settings',
      builder: (_, state) =>
          ClubSettingsScreen(clubId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/clubs/:id/members/manage',
      builder: (_, state) =>
          ManageMembersScreen(clubId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/clubs/:id',
      builder: (_, state) =>
          ClubProfileScreen(clubId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/attendance',
      builder: (_, state) {
        final e = state.extra as Map? ?? const {};
        return AttendanceScreen(
          isTrip: e['isTrip'] as bool? ?? false,
          id: e['id'] as String? ?? '',
          title: e['title'] as String? ?? '',
          canCheckIn: e['canCheckIn'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/trips/:id/schedule',
      builder: (_, state) {
        final e = state.extra as Map? ?? const {};
        return TripScheduleScreen(
          tripId: state.pathParameters['id']!,
          title: e['title'] as String? ?? 'Viagem',
          canEdit: e['canEdit'] as bool? ?? false,
        );
      },
    ),

    GoRoute(path: '/rides/create', builder: (_, __) => const CreateRideScreen()),
    GoRoute(path: '/rides/schedule', builder: (_, __) => const ScheduleRideScreen()),
    GoRoute(
      path: '/rides/:id',
      builder: (_, state) => RideDetailScreen(rideId: state.pathParameters['id']!),
    ),

    GoRoute(
      path: '/session/waiting/:id',
      builder: (_, state) => WaitingScreen(sessionId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/session/active/:id',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ActiveMapScreen(
          sessionId: state.pathParameters['id']!,
          isRide: extra?['isRide'] as bool? ?? true,
        );
      },
    ),
    GoRoute(
      path: '/session/confirm/:id',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return GuestConfirmScreen(
          sessionId: state.pathParameters['id']!,
          isRide: extra?['isRide'] as bool? ?? true,
        );
      },
    ),
    GoRoute(
      path: '/session/finish/:id',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return FinishTripScreen(
          sessionId: state.pathParameters['id']!,
          isRide: extra?['isRide'] as bool? ?? false,
        );
      },
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
