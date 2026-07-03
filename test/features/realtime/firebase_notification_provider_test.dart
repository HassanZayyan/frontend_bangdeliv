import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/realtime/application/firebase_notification_provider.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  test(
    'notification bootstrap waits until Google phone completion is done',
    () {
      final incompleteGoogleCustomer = AuthSessionState.fromProfile(
        _profile(requiresPhoneCompletion: true),
      );

      expect(
        shouldBootstrapFirebaseNotifications(incompleteGoogleCustomer),
        isFalse,
      );
    },
  );

  test(
    'notification bootstrap runs for completed customer and driver sessions',
    () {
      final customer = AuthSessionState.fromProfile(
        _profile(requiresPhoneCompletion: false),
      );
      final driver = AuthSessionState.fromProfile(
        _profile(
          role: 'driver',
          requiresPhoneCompletion: false,
          driverProfile: const DriverProfileModel(
            registrationStatus: 'active',
            status: 'available',
            vehicleType: 'Motor Matic',
            vehicleBrand: 'Honda',
            vehicleModel: 'Beat',
            vehiclePlate: 'H 1234 BD',
            totalDeliveries: 0,
          ),
        ),
      );

      expect(shouldBootstrapFirebaseNotifications(customer), isTrue);
      expect(shouldBootstrapFirebaseNotifications(driver), isTrue);
    },
  );

  test('notification bootstrap ignores guest sessions', () {
    expect(
      shouldBootstrapFirebaseNotifications(const AuthSessionState.guest()),
      isFalse,
    );
  });

  test(
    'driver incoming order foreground notification shows on driver orders route',
    () {
      final driver = AuthSessionState.fromProfile(
        _profile(
          role: 'driver',
          driverProfile: const DriverProfileModel(
            registrationStatus: 'active',
            status: 'available',
            vehicleType: 'Motor Matic',
            vehicleBrand: 'Honda',
            vehicleModel: 'Beat',
            vehiclePlate: 'H 1234 BD',
            totalDeliveries: 0,
          ),
        ),
      );

      expect(
        shouldShowForegroundNotification(
          session: driver,
          data: const <String, dynamic>{'type': 'driver_order_available'},
          targetRoute: '/driver/orders',
          currentRoute: '/driver/orders',
        ),
        isTrue,
      );
    },
  );

  test(
    'customer does not show driver incoming order foreground notification',
    () {
      final customer = AuthSessionState.fromProfile(_profile());

      expect(
        shouldShowForegroundNotification(
          session: customer,
          data: const <String, dynamic>{'type': 'driver_order_available'},
          targetRoute: '/driver/orders',
          currentRoute: '/home',
        ),
        isFalse,
      );
    },
  );

  test('order status foreground notification shows on tracking route', () {
    final customer = AuthSessionState.fromProfile(_profile());

    expect(
      shouldShowForegroundNotification(
        session: customer,
        data: const <String, dynamic>{'type': 'order_status_changed'},
        targetRoute: '/orders/42/track',
        currentRoute: '/orders/42/track',
      ),
      isTrue,
    );
  });

  test(
    'non-driver foreground notifications keep route duplicate suppression',
    () {
      final customer = AuthSessionState.fromProfile(_profile());

      expect(
        shouldShowForegroundNotification(
          session: customer,
          data: const <String, dynamic>{'type': 'order_chat_message'},
          targetRoute: '/orders/42/chat',
          currentRoute: '/orders/42/chat',
        ),
        isFalse,
      );
      expect(
        shouldShowForegroundNotification(
          session: customer,
          data: const <String, dynamic>{'type': 'order_chat_message'},
          targetRoute: '/orders/42/chat',
          currentRoute: '/home',
        ),
        isTrue,
      );
    },
  );
}

UserProfileModel _profile({
  String role = 'customer',
  bool requiresPhoneCompletion = false,
  DriverProfileModel? driverProfile,
}) {
  return UserProfileModel(
    id: 7,
    name: 'Google User',
    phone: requiresPhoneCompletion ? '' : '081234567890',
    email: 'google.user@example.com',
    avatar: null,
    avatarUrl: null,
    role: role,
    authProvider: 'google',
    hasPassword: false,
    requiresPhoneCompletion: requiresPhoneCompletion,
    driverProfile: driverProfile,
    stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
    addresses: const [],
  );
}
