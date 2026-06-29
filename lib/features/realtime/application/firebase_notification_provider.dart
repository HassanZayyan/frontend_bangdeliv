import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_router.dart';
import '../../../core/di/app_providers.dart';
import '../../../services/firebase_notification_service.dart';
import '../../../services/notification_navigation_service.dart';
import '../../../utils/map_picker_helpers.dart';
import '../../auth/application/auth_session_provider.dart';
import '../../location/application/post_login_location_permission_provider.dart';

final Set<int> _postLoginLocationPromptedUserIds = <int>{};
Future<void>? _postLoginPermissionSequenceFuture;
int? _postLoginPermissionSequenceUserId;

final firebaseNotificationBootstrapProvider = Provider<void>((ref) {
  final router = ref.watch(appRouterProvider);
  final session = ref.watch(authSessionProvider);
  final deviceTokenApi = ref.watch(deviceTokenApiServiceProvider);

  unawaited(
    FirebaseNotificationService.initializeNotifications(
      onOpenRoute: (route) async {
        await NotificationNavigationService.queueRoute(route);
        if (!ref.mounted) {
          return;
        }

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
    _syncNotificationsThenLocationPermission(
      ref: ref,
      userId: profile.id,
      registerToken: (token) {
        return deviceTokenApi.registerDeviceToken(token: token);
      },
    ),
  );
});

Future<void> _syncNotificationsThenLocationPermission({
  required Ref ref,
  required int userId,
  required Future<void> Function(String token) registerToken,
}) {
  final currentFuture = _postLoginPermissionSequenceFuture;
  if (_postLoginPermissionSequenceUserId == userId && currentFuture != null) {
    return currentFuture;
  }

  final nextFuture = _runPostLoginPermissionSequence(
    ref: ref,
    userId: userId,
    registerToken: registerToken,
  );
  _postLoginPermissionSequenceUserId = userId;
  _postLoginPermissionSequenceFuture = nextFuture;

  return nextFuture.whenComplete(() {
    if (identical(_postLoginPermissionSequenceFuture, nextFuture)) {
      _postLoginPermissionSequenceFuture = null;
      _postLoginPermissionSequenceUserId = null;
    }
  });
}

Future<void> _runPostLoginPermissionSequence({
  required Ref ref,
  required int userId,
  required Future<void> Function(String token) registerToken,
}) async {
  await FirebaseNotificationService.syncTokenWithBackend(
    userId: userId,
    registerToken: registerToken,
  );

  if (!ref.mounted) {
    return;
  }

  await _requestPostLoginLocationPermission(ref: ref, userId: userId);
}

Future<void> _requestPostLoginLocationPermission({
  required Ref ref,
  required int userId,
}) async {
  if (_postLoginLocationPromptedUserIds.contains(userId)) {
    return;
  }

  final session = ref.read(authSessionProvider);
  if (!session.isAuthenticated ||
      session.profile?.id != userId ||
      session.profile?.requiresPhoneCompletion == true) {
    return;
  }

  try {
    final permission = await MapPickerHelpers.requestLocationPermission();
    _postLoginLocationPromptedUserIds.add(userId);

    if (!ref.mounted ||
        !MapPickerHelpers.isLocationPermissionGranted(permission)) {
      return;
    }

    final notifier = ref.read(
      postLoginLocationPermissionRefreshProvider.notifier,
    );
    notifier.markGranted();
  } catch (_) {
    return;
  }
}

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
