import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/auth/application/auth_session_provider.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/screens/driver_history_screen.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/user_profile_model.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';

final _historyDate = DateTime.now().toUtc();

void main() {
  testWidgets('cancelled with fee order still shows driver income', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_driverSession()),
          ),
          driverOrderServiceProvider.overrideWithValue(
            _FakeHistoryService([
              DriverHistoryOrderModel(
                id: 'BDR-FEE-34',
                orderId: 34,
                orderNumber: 'BDR-FEE-34',
                customerName: 'Mhn Zayyan',
                date: _historyDate,
                fee: 2500,
                driverIncome: 2500,
                driverIncomeGross: 2500,
                driverAdminFeePercent: 10,
                driverAdminFee: 250,
                driverIncomeNet: 2250,
                status: 'Dibatalkan (Berbiaya)',
                statusCode: 'CANCELLED_WITH_FEE',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: DriverHistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Nominal mengikuti nilainya, bukan statusnya.
    expect(find.text('Tidak ada pendapatan'), findsNothing);
    expect(find.text('Pendapatan Bersih'), findsOneWidget);
    // Muncul di kartu order sekaligus ikut terhitung di ringkasan Pendapatan.
    expect(find.text('Rp 2.250'), findsNWidgets(2));
    expect(find.text('Bruto Rp 2.500 - Admin 10% Rp 250'), findsOneWidget);

    // Label status tetap membedakan pembatalan berbiaya dari order selesai.
    final statusText = tester.widget<Text>(find.text('Dibatalkan (Berbiaya)'));
    expect(statusText.style?.color, isNot(AppColors.success));
  });

  testWidgets('cancelled order without fee shows no income', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuthSessionNotifier(_driverSession()),
          ),
          driverOrderServiceProvider.overrideWithValue(
            _FakeHistoryService([
              DriverHistoryOrderModel(
                id: 'BDR-CANCEL-35',
                orderId: 35,
                orderNumber: 'BDR-CANCEL-35',
                customerName: 'Mhn Zayyan',
                date: _historyDate,
                fee: 0,
                status: 'Dibatalkan',
                statusCode: 'CANCELLED',
              ),
            ]),
          ),
        ],
        child: const MaterialApp(home: DriverHistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Tidak ada pendapatan'), findsOneWidget);
    expect(find.text('Pendapatan Bersih'), findsNothing);
  });
}

class _FakeHistoryService extends DriverOrderService {
  _FakeHistoryService(this._orders);

  final List<DriverHistoryOrderModel> _orders;

  @override
  Future<List<DriverHistoryOrderModel>> fetchHistory() async => _orders;
}

class _FakeAuthSessionNotifier extends AuthSessionNotifier {
  _FakeAuthSessionNotifier(this._initialState);

  final AuthSessionState _initialState;

  @override
  AuthSessionState build() => _initialState;
}

AuthSessionState _driverSession() {
  return AuthSessionState.fromProfile(
    UserProfileModel(
      id: 77,
      name: 'Driver 77',
      phone: '0823477',
      email: 'driver77@example.com',
      avatar: null,
      avatarUrl: null,
      role: 'driver',
      driverProfile: const DriverProfileModel(
        registrationStatus: 'active',
        status: 'available',
        vehicleType: 'Motor Matic',
        vehicleBrand: 'Honda',
        vehicleModel: 'Beat',
        vehiclePlate: 'H 1234 DL',
        totalDeliveries: 12,
      ),
      stats: const UserStatsModel(totalOrders: 0, totalPaid: 0),
      addresses: const <SavedAddressModel>[],
    ),
  );
}
