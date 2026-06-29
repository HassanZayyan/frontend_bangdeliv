import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/auth/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('splash brand text stays within compact large-font layouts', (
    tester,
  ) async {
    final scenarios = <({Size size, double textScale})>[
      (size: Size(320, 640), textScale: 2),
      (size: Size(280, 560), textScale: 2.4),
      (size: Size(640, 320), textScale: 2),
    ];

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final scenario in scenarios) {
      tester.view
        ..physicalSize = scenario.size
        ..devicePixelRatio = 1;

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scenario.textScale)),
              child: child!,
            );
          },
          home: const SplashScreen(),
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    }
  });
}
