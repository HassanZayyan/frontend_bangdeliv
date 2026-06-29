import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/auth/presentation/screens/register_driver_screen.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  testWidgets('upgrade driver screen loads hero image on narrow layout', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_customerSession()),
          ),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 760),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const RegisterDriverScreen(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Upgrade Jadi Driver'), findsOneWidget);
    expect(find.text('Siap jadi mitra pengantar?'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ilustrasi driver Bang Deliv'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._state);

  final AuthSessionState _state;

  @override
  AuthSessionState build() => _state;
}

AuthSessionState _customerSession() {
  return AuthSessionState.fromProfile(
    const UserProfileModel(
      id: 91,
      name: 'Customer Upgrade',
      phone: '081299990001',
      email: 'customer.upgrade@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'customer',
      driverProfile: null,
      stats: UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: <SavedAddressModel>[],
    ),
  );
}
