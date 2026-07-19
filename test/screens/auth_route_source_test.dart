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
      final forgotPasswordSource = File(
        'lib/features/auth/presentation/screens/forgot_password_screen.dart',
      ).readAsStringSync();
      final editProfileSource = File(
        'lib/features/profile/presentation/screens/edit_profile_screen.dart',
      ).readAsStringSync();

      expect(routerSource, contains('requiresPhoneCompletion'));
      expect(routerSource, contains('AppRoutes.completePhone'));
      expect(routerSource, contains('requiresPhoneVerification'));
      expect(routerSource, contains('AppRoutes.verifyOtp'));
      expect(routerSource, contains('RegisterScreen'));
      expect(routerSource, contains('RegisterSuccessScreen'));
      expect(routerSource, contains('PasswordFormMode.create'));
      expect(loginSource, contains('AppRoutes.register'));
      expect(loginSource, contains('Daftar Sekarang'));
      expect(profileSource, contains('profile.hasPassword'));
      expect(profileSource, contains('AppRoutes.createPassword'));
      expect(driverProfileSource, contains('profile.hasPassword'));
      expect(driverProfileSource, contains('AppRoutes.createPassword'));
      expect(forgotPasswordSource, contains('AuthService.resetPassword'));
      expect(forgotPasswordSource, contains('Atur Ulang Password'));
      expect(
        forgotPasswordSource,
        isNot(contains('Simulasi pengiriman tautan reset')),
      );
      expect(forgotPasswordSource, isNot(contains('Kirim Tautan Pemulihan')));
      expect(editProfileSource, contains('Email Google'));
      expect(editProfileSource, contains('readOnly: _isGoogleLinked'));
      expect(editProfileSource, contains('profile.authProvider'));
    },
  );
}
