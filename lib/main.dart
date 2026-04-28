import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/notifications/fcm_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Background handler must be registered before runApp so FCM can invoke
  // it in a fresh isolate while the app is killed.
  FirebaseMessaging.onBackgroundMessage(vibzcheckFcmBackgroundHandler);
  runApp(const ProviderScope(child: VibzcheckApp()));
}
