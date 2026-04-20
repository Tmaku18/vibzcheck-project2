import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class VibzcheckApp extends ConsumerWidget {
  const VibzcheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Vibzcheck',
      debugShowCheckedModeBanner: false,
      theme: VibzcheckTheme.light(),
      darkTheme: VibzcheckTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
