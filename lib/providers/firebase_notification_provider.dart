import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_router.dart';
import '../services/firebase_notification_service.dart';
import '../services/notification_navigation_service.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';

final firebaseNotificationBootstrapProvider = Provider<void>((ref) {
  final router = ref.watch(appRouterProvider);
  final session = ref.watch(authSessionProvider);
  final deviceTokenApi = ref.watch(deviceTokenApiServiceProvider);

  unawaited(
    FirebaseNotificationService.initializeNotifications(
      onOpenRoute: (route) async {
        await NotificationNavigationService.queueRoute(route);
        await _drainPendingNotificationRoute(
          router: router,
          session: ref.read(authSessionProvider),
        );
      },
      shouldShowForegroundMessage: (message) {
        final targetRoute =
            FirebaseNotificationService.routeForNotificationData(message.data);
        if (targetRoute == null) {
          return false;
        }

        final currentRoute = router.routeInformationProvider.value.uri
            .toString();
        return currentRoute != targetRoute;
      },
    ),
  );

  unawaited(_drainPendingNotificationRoute(router: router, session: session));

  final profile = session.profile;
  final shouldRegisterToken =
      session.isAuthenticated &&
      profile != null &&
      (session.role == SessionUserRole.customer ||
          session.role == SessionUserRole.driver);

  if (!shouldRegisterToken) {
    FirebaseNotificationService.clearBackendTokenSync();
    return;
  }

  unawaited(
    FirebaseNotificationService.syncTokenWithBackend(
      userId: profile.id,
      registerToken: (token) {
        return deviceTokenApi.registerDeviceToken(token: token);
      },
    ),
  );
});

Future<void> _drainPendingNotificationRoute({
  required GoRouter router,
  required AuthSessionState session,
}) async {
  if (!session.initialized) {
    return;
  }

  final targetRoute = await NotificationNavigationService.takePendingRoute();
  if (targetRoute == null) {
    return;
  }

  final currentRoute = router.routeInformationProvider.value.uri.toString();
  if (currentRoute == targetRoute) {
    return;
  }

  if (_shouldPushNotificationRoute(
    session: session,
    currentRoute: currentRoute,
  )) {
    unawaited(router.push<void>(targetRoute));
    return;
  }

  router.go(targetRoute);
}

bool _shouldPushNotificationRoute({
  required AuthSessionState session,
  required String currentRoute,
}) {
  if (!session.isAuthenticated) {
    return false;
  }

  final currentPath = Uri.tryParse(currentRoute)?.path ?? currentRoute;
  return currentPath != '/splash' && currentPath != '/login';
}
