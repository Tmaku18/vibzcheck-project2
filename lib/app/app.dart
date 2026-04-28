import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/firebase/firebase_providers.dart';
import '../features/notifications/fcm_service.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget for Vibzcheck. Also plays host to the [FcmService] lifecycle
/// so notification tokens are kept in sync with the signed-in user without
/// cluttering every feature screen.
class VibzcheckApp extends ConsumerStatefulWidget {
  const VibzcheckApp({super.key});

  @override
  ConsumerState<VibzcheckApp> createState() => _VibzcheckAppState();
}

class _VibzcheckAppState extends ConsumerState<VibzcheckApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _initialisedForUid;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    ref.listen(authStateChangesProvider, (previous, next) {
      final user = next.value;
      final service = ref.read(fcmServiceProvider);
      if (user == null) {
        if (_initialisedForUid != null) {
          service.clearForSignOut();
          _initialisedForUid = null;
        }
        return;
      }
      if (_initialisedForUid == user.uid) return;
      _initialisedForUid = user.uid;
      // Fire and forget: permission prompt + token sync happen on whatever
      // thread the caller is on; errors are swallowed so sign-in isn't
      // blocked if the user declines notifications.
      service
          .initForUser(uid: user.uid, messengerKey: _messengerKey)
          .catchError((_) {});
    });

    return MaterialApp.router(
      title: 'Vibzcheck',
      debugShowCheckedModeBanner: false,
      theme: VibzcheckTheme.light(),
      darkTheme: VibzcheckTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      scaffoldMessengerKey: _messengerKey,
    );
  }
}
