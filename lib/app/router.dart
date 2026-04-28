import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/firebase/firebase_providers.dart';
import '../core/widgets/error_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/session/presentation/add_track_screen.dart';
import '../features/session/presentation/create_session_screen.dart';
import '../features/session/presentation/home_screen.dart';
import '../features/session/presentation/join_session_screen.dart';
import '../features/session/presentation/session_screen.dart';

/// Adapter that lets `go_router` rebuild its redirect logic whenever the
/// underlying Riverpod auth-state stream emits a new value.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authStream =
      ref.watch(firebaseAuthProvider).authStateChanges();
  final refresh = _RouterRefreshNotifier(authStream);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final user = ref.read(firebaseAuthProvider).currentUser;
      final loggedIn = user != null;
      final atSignIn = state.matchedLocation == '/sign-in';
      final atSignUp = state.matchedLocation == '/sign-up';
      final atAuthScreen = atSignIn || atSignUp;

      if (!loggedIn && !atAuthScreen) return '/sign-in';
      if (loggedIn && atAuthScreen) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        name: 'sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        name: 'sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/create-session',
        name: 'create-session',
        builder: (context, state) => const CreateSessionScreen(),
      ),
      GoRoute(
        path: '/join-session',
        name: 'join-session',
        builder: (context, state) => const JoinSessionScreen(),
      ),
      GoRoute(
        path: '/session/:sessionId',
        name: 'session',
        builder: (context, state) => SessionScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
        routes: [
          GoRoute(
            path: 'add-track',
            name: 'add-track',
            builder: (context, state) => AddTrackScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
          GoRoute(
            path: 'chat',
            name: 'session-chat',
            builder: (context, state) => ChatScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ErrorScreen(error: state.error ?? ''),
  );
});
