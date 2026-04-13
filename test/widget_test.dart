import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/main.dart';

void main() {
  testWidgets('App boots into auth flow', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final hasLoginText = find.text('Masuk ke Akun').evaluate().isNotEmpty;
    final hasSplashIndicator = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isNotEmpty;

    expect(hasLoginText || hasSplashIndicator, isTrue);
  });
}
