import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'router routes Google users with missing phone to completion screen',
    () {
      final routerSource = File(
        'lib/config/app_router.dart',
      ).readAsStringSync();
      final loginSource = File(
        'lib/features/auth/presentation/screens/login_screen.dart',
      ).readAsStringSync();
      final profileSource = File(
        'lib/features/profile/presentation/screens/profile_screen.dart',
      ).readAsStringSync();
      final driverProfileSource = File(
        'lib/features/profile/presentation/screens/driver_profile_screen.dart',
      ).readAsStringSync();

      expect(routerSource, contains('requiresPhoneCompletion'));
      expect(routerSource, contains('AppRoutes.completePhone'));
      expect(routerSource, contains('RegisterScreen'));
      expect(routerSource, contains('RegisterSuccessScreen'));
      expect(routerSource, contains('PasswordFormMode.create'));
      expect(loginSource, contains('AppRoutes.register'));
      expect(loginSource, contains('Daftar Sekarang'));
      expect(profileSource, contains('profile.hasPassword'));
      expect(profileSource, contains('AppRoutes.createPassword'));
      expect(driverProfileSource, contains('profile.hasPassword'));
      expect(driverProfileSource, contains('AppRoutes.createPassword'));
    },
  );
}
