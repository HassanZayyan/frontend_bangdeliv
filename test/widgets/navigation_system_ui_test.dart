import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/features/navigation/presentation/screens/driver_main_layout.dart';
import 'package:frontend_bangdeliv/features/navigation/presentation/screens/main_layout.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('customer shell resets system bars to the light app style', (
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
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(_hasLightSystemUiRegion(tester), isTrue);
  });

  testWidgets('driver shell resets system bars to the light app style', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DriverMainLayout(child: _ShellBody('driver'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(_hasLightSystemUiRegion(tester), isTrue);
  });
}

bool _hasLightSystemUiRegion(WidgetTester tester) {
  final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
    find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
  );

  return regions.any((region) {
    final style = region.value;
    return style.statusBarColor == AppColors.white &&
        style.statusBarIconBrightness == Brightness.dark &&
        style.statusBarBrightness == Brightness.light &&
        style.systemNavigationBarColor == AppColors.white &&
        style.systemNavigationBarIconBrightness == Brightness.dark;
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
