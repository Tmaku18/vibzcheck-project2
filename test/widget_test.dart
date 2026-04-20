import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vibzcheck/app/theme.dart';

void main() {
  testWidgets('VibzcheckTheme builds light and dark variants without throwing',
      (WidgetTester tester) async {
    final light = VibzcheckTheme.light();
    final dark = VibzcheckTheme.dark();

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: light,
        home: const Scaffold(body: Center(child: Text('ok'))),
      ),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
