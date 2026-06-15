import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('home header no longer exposes the local notification inbox', () {
    final homeSource = File(
      'lib/features/home/presentation/screens/home_screen.dart',
    ).readAsStringSync();
    final routerSource = File('lib/config/app_router.dart').readAsStringSync();
    final routesSource = File('lib/config/app_routes.dart').readAsStringSync();

    expect(homeSource, isNot(contains('AppRoutes.notifications')));
    expect(homeSource, isNot(contains('notifications_none_rounded')));
    expect(routerSource, isNot(contains('NotificationsScreen')));
    expect(routerSource, isNot(contains('notifications_screen.dart')));
    expect(routesSource, isNot(contains("notifications = '/notifications'")));
    expect(File('lib/screens/notifications_screen.dart').existsSync(), isFalse);
  });
}
