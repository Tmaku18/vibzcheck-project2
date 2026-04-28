import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../auth/data/user_repository.dart';

/// Top-level handler invoked by FCM when a push arrives while the app is
/// terminated or backgrounded. It **must** be a top-level function so the
/// platform channel can invoke it in a fresh isolate. Keeping it as a no-op
/// right now satisfies the firebase_messaging contract; real side effects
/// (e.g. updating the notification tray) can be added once Cloud Functions
/// are sending payloads.
@pragma('vm:entry-point')
Future<void> vibzcheckFcmBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('FCM background message: ${message.messageId} - '
        '${message.notification?.title}');
  }
}

/// Owns the FCM lifecycle for the current authenticated user:
///   * requests notification permission
///   * fetches + persists the device token under `users/{uid}.fcmTokens`
///   * listens for token refresh
///   * pipes foreground messages to the active [ScaffoldMessengerState]
class FcmService {
  FcmService({
    required FirebaseMessaging messaging,
    required UserRepository userRepository,
  })  : _messaging = messaging,
        _userRepository = userRepository;

  final FirebaseMessaging _messaging;
  final UserRepository _userRepository;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  GlobalKey<ScaffoldMessengerState>? _messengerKey;
  String? _currentToken;
  String? _currentUid;

  Future<void> initForUser({
    required String uid,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  }) async {
    _messengerKey = messengerKey;
    _currentUid = uid;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User declined — still safe to continue; we just won't receive pushes.
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      _currentToken = token;
      await _userRepository.addFcmToken(uid: uid, token: token);
    }

    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription =
        _messaging.onTokenRefresh.listen((newToken) async {
      if (_currentUid == null) return;
      if (_currentToken != null) {
        await _userRepository.removeFcmToken(
          uid: _currentUid!,
          token: _currentToken!,
        );
      }
      _currentToken = newToken;
      await _userRepository.addFcmToken(
        uid: _currentUid!,
        token: newToken,
      );
    });

    _foregroundSubscription?.cancel();
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  /// Called on sign-out so the device token is removed from the old user's
  /// tokens array and incoming pushes don't leak across accounts.
  Future<void> clearForSignOut() async {
    if (_currentUid != null && _currentToken != null) {
      try {
        await _userRepository.removeFcmToken(
          uid: _currentUid!,
          token: _currentToken!,
        );
      } catch (_) {
        // Best-effort cleanup; we'll retry on next sign-in.
      }
    }
    _currentUid = null;
    _currentToken = null;
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundSubscription = null;
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final text = notification.body?.trim().isNotEmpty == true
        ? '${notification.title}: ${notification.body}'
        : notification.title ?? 'New notification';
    _messengerKey?.currentState?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService(
    messaging: ref.watch(firebaseMessagingProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});
