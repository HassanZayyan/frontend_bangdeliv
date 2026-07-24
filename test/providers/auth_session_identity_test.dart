import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  test('identity stays equal when session is refreshed for the same user', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var rebuilds = 0;
    final derived = Provider<int>((ref) {
      ref.watch(authSessionIdentityProvider);
      rebuilds += 1;
      return rebuilds;
    });

    final subscription = container.listen<int>(derived, (_, _) {});
    addTearDown(subscription.close);
    expect(rebuilds, 1);

    final notifier = container.read(authSessionProvider.notifier);
    notifier.syncProfile(_profile(id: 7, role: 'customer'));
    container.read(derived);
    expect(rebuilds, 2);

    // Refresh sesi menghasilkan objek AuthSessionState + UserProfileModel baru
    // untuk user yang sama. Identity harus tetap dianggap sama supaya provider
    // turunannya tidak reload.
    notifier.syncProfile(_profile(id: 7, role: 'customer'));
    container.read(derived);
    expect(rebuilds, 2);

    // Ganti user harus tetap memicu rebuild.
    notifier.syncProfile(_profile(id: 8, role: 'customer'));
    container.read(derived);
    expect(rebuilds, 3);

    // Begitu juga perubahan role.
    notifier.syncProfile(_profile(id: 8, role: 'driver'));
    container.read(derived);
    expect(rebuilds, 4);
  });

  test('identity checks map roles and driver access state', () {
    final customer = AuthSessionState.fromProfile(
      _profile(id: 1, role: 'customer'),
    ).identity;
    expect(customer.isCustomer, isTrue);
    expect(customer.isDriver, isFalse);
    expect(customer.isOrderChatParticipant, isTrue);

    final pendingDriver = AuthSessionState.fromProfile(
      _profile(id: 2, role: 'driver', registrationStatus: 'pending'),
    ).identity;
    expect(pendingDriver.isDriver, isTrue);
    expect(pendingDriver.isActiveDriver, isFalse);

    final activeDriver = AuthSessionState.fromProfile(
      _profile(id: 3, role: 'driver', registrationStatus: 'active'),
    ).identity;
    expect(activeDriver.isActiveDriver, isTrue);
    expect(activeDriver.isOrderChatParticipant, isTrue);

    const guest = AuthSessionState.guest();
    expect(guest.identity.isCustomer, isFalse);
    expect(guest.identity.isOrderChatParticipant, isFalse);
    expect(guest.identity.hasProfile, isFalse);
  });
}

UserProfileModel _profile({
  required int id,
  required String role,
  String? registrationStatus,
}) {
  return UserProfileModel(
    id: id,
    name: 'User $id',
    phone: '08123$id',
    email: 'user$id@example.com',
    avatar: null,
    avatarUrl: null,
    role: role,
    driverProfile: registrationStatus == null
        ? null
        : DriverProfileModel(
            registrationStatus: registrationStatus,
            status: 'available',
            vehicleType: 'Motor Matic',
            vehicleBrand: 'Honda',
            vehicleModel: 'Beat',
            vehiclePlate: 'H 1234 BD',
            totalDeliveries: 0,
          ),
    stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
    addresses: const <SavedAddressModel>[],
  );
}
