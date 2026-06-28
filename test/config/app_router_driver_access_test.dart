import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/app_router.dart';
import 'package:frontend_bangdeliv/config/app_routes.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  test('active driver is redirected away from customer shell routes', () {
    final session = _driverSession('active');

    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.home,
        fullLocation: AppRoutes.home,
      ),
      AppRoutes.driverHome,
    );
    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.profile,
        fullLocation: AppRoutes.profile,
      ),
      AppRoutes.driverHome,
    );
  });

  test('active driver can still open verification status screen', () {
    final session = _driverSession('active');

    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.driverVerificationStatus,
        fullLocation: AppRoutes.driverVerificationStatus,
      ),
      isNull,
    );
  });

  test('pending driver remains allowed in customer flow while waiting', () {
    final session = _driverSession('pending');

    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.home,
        fullLocation: AppRoutes.home,
      ),
      isNull,
    );
    expect(
      resolveAppRedirectForTest(
        session: session,
        location: AppRoutes.profile,
        fullLocation: AppRoutes.profile,
      ),
      isNull,
    );
  });
}

AuthSessionState _driverSession(String registrationStatus) {
  return AuthSessionState.fromProfile(
    UserProfileModel(
      id: 77,
      name: 'Driver Test',
      phone: '081277771111',
      email: 'driver.test@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'driver',
      driverProfile: DriverProfileModel(
        registrationStatus: registrationStatus,
        status: registrationStatus == 'active' ? 'available' : 'offline',
        vehicleType: 'motor',
        vehicleBrand: 'Honda',
        vehicleModel: 'Beat',
        vehiclePlate: 'H 1234 QA',
        totalDeliveries: 0,
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}
