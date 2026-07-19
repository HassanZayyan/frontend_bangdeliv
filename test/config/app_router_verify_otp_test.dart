import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_router.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  test('unverified phone forces the OTP screen from anywhere in the app', () {
    final session = _session(requiresPhoneVerification: true);

    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.home,
        fullLocation: AppRoutes.home,
      ),
      AppRoutes.verifyOtp,
    );
  });

  test('OTP screen itself is not redirected while verification pending', () {
    final session = _session(requiresPhoneVerification: true);

    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.verifyOtp,
        fullLocation: AppRoutes.verifyOtp,
      ),
      isNull,
    );
  });

  test('phone completion is handled before phone verification', () {
    final session = _session(
      requiresPhoneCompletion: true,
      requiresPhoneVerification: true,
      phone: '',
    );

    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.home,
        fullLocation: AppRoutes.home,
      ),
      AppRoutes.completePhone,
    );
  });

  test('verified user is sent away from the OTP screen', () {
    final session = _session(requiresPhoneVerification: false);

    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.verifyOtp,
        fullLocation: AppRoutes.verifyOtp,
      ),
      AppRoutes.home,
    );
  });

  test('guest cannot reach the OTP screen', () {
    final redirect = resolveAppRedirectForTest(
      session: const AuthSessionState.guest(),
      location: AppRoutes.verifyOtp,
      fullLocation: AppRoutes.verifyOtp,
    );

    expect(redirect, isNotNull);
    expect(redirect, contains(AppRoutes.login));
  });
}

AuthSessionState _session({
  bool requiresPhoneCompletion = false,
  bool requiresPhoneVerification = false,
  String phone = '081234567890',
}) {
  return AuthSessionState.fromProfile(
    UserProfileModel(
      id: 12,
      name: 'Customer Test',
      phone: phone,
      email: 'customer.test@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'customer',
      requiresPhoneCompletion: requiresPhoneCompletion,
      requiresPhoneVerification: requiresPhoneVerification,
      driverProfile: null,
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const [],
    ),
  );
}
