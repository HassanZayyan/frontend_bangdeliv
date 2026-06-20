import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/features/navigation/presentation/screens/main_layout.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('customer shell shows activity as the single orders nav item', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const _ShellBody('home'),
            ),
            GoRoute(
              path: AppRoutes.activity,
              builder: (context, state) => const _ShellBody('activity'),
            ),
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const _ShellBody('profile'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Aktivitas'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Riwayat'), findsNothing);

    await tester.tap(find.text('Aktivitas'));
    await tester.pumpAndSettle();

    expect(find.text('activity'), findsOneWidget);
  });
}

class _ShellBody extends StatelessWidget {
  const _ShellBody(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
