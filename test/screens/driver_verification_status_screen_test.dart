import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/profile/presentation/screens/driver_verification_status_screen.dart';
import 'package:frontend_bangdeliv/models/driver_verification_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';

void main() {
  testWidgets('active verification shows driver home action only', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_driverSession('active')),
          ),
        ],
        child: MaterialApp(
          home: DriverVerificationStatusScreen(
            initialStatus: _status('active'),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Akun Driver Aktif'), findsOneWidget);
    expect(find.text('Buka Beranda Driver'), findsOneWidget);
    expect(find.text('Kirim Dokumen'), findsNothing);
    expect(find.text('Batalkan Pengajuan'), findsNothing);
  });
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() => _initialState;
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

DriverVerificationStatusModel _status(String registrationStatus) {
  return DriverVerificationStatusModel(
    driver: DriverVerificationDriverModel(
      id: 10,
      name: 'Driver Test',
      email: 'driver.test@example.com',
      phone: '081277771111',
      vehicleType: 'motor',
      vehicleBrand: 'Honda',
      vehicleModel: 'Beat',
      vehiclePlate: 'H 1234 QA',
      registrationStatus: registrationStatus,
      status: registrationStatus == 'active' ? 'available' : 'offline',
      submittedAt: null,
      updatedAt: null,
    ),
    documents: const <DriverVerificationDocumentModel>[
      DriverVerificationDocumentModel(
        documentType: 'ktp',
        isUploaded: true,
        filePath: null,
        fileUrl: null,
        fileExists: false,
        verificationStatus: 'approved',
        rejectionReason: null,
        verifiedAt: null,
        verifiedBy: 'Admin',
      ),
      DriverVerificationDocumentModel(
        documentType: 'sim',
        isUploaded: true,
        filePath: null,
        fileUrl: null,
        fileExists: false,
        verificationStatus: 'approved',
        rejectionReason: null,
        verifiedAt: null,
        verifiedBy: 'Admin',
      ),
      DriverVerificationDocumentModel(
        documentType: 'selfie',
        isUploaded: true,
        filePath: null,
        fileUrl: null,
        fileExists: false,
        verificationStatus: 'approved',
        rejectionReason: null,
        verifiedAt: null,
        verifiedBy: 'Admin',
      ),
    ],
  );
}
