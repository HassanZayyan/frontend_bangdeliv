import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/features/auth/presentation/widgets/guest_login_prompt.dart';

void main() {
  testWidgets('guest login prompt opens login without returnTo', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) {
            return Scaffold(
              body: TextButton(
                onPressed: () => showGuestLoginPrompt(
                  context,
                  title: 'Masuk untuk lanjut',
                  message: 'Login diperlukan.',
                  returnTo: AppRoutes.activity,
                ),
                child: const Text('open prompt'),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            return Scaffold(body: Text('login query: ${state.uri.query}'));
          },
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('open prompt'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk untuk lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('login query: '), findsOneWidget);
    expect(find.textContaining('returnTo'), findsNothing);
  });
}
