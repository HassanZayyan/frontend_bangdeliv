import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_router.dart';
import '../services/firebase_notification_service.dart';
import 'api_providers.dart';
import 'auth_session_provider.dart';

final firebaseNotificationBootstrapProvider = Provider<void>((ref) {
  final router = ref.watch(appRouterProvider);
  final session = ref.watch(authSessionProvider);
  final deviceTokenApi = ref.watch(deviceTokenApiServiceProvider);

  unawaited(
    FirebaseNotificationService.initializeNotifications(onOpenRoute: router.go),
  );

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
