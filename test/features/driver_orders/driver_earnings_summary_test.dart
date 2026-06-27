import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_earnings_summary.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';

void main() {
  test('summarizes completed driver history using net income', () {
    final orders = [
      DriverHistoryOrderModel(
        id: '1',
        customerName: 'Customer A',
        date: DateTime.utc(2026, 6, 27),
        fee: 10000,
        driverIncomeGross: 10000,
        driverAdminFee: 1000,
        driverIncomeNet: 9000,
        status: 'Selesai',
      ),
      DriverHistoryOrderModel(
        id: '2',
        customerName: 'Customer B',
        date: DateTime.utc(2026, 6, 27),
        fee: 7500,
        driverIncomeGross: 7500,
        driverAdminFee: 750,
        driverIncomeNet: 6750,
        status: 'Selesai',
      ),
      DriverHistoryOrderModel(
        id: '3',
        customerName: 'Customer C',
        date: DateTime.utc(2026, 6, 27),
        fee: 12000,
        driverIncomeGross: 12000,
        driverAdminFee: 1200,
        driverIncomeNet: 10800,
        status: 'Dibatalkan',
        statusCode: 'CANCELLED_WITH_FEE',
      ),
      DriverHistoryOrderModel(
        id: '4',
        customerName: 'Customer D',
        date: DateTime.utc(2026, 6, 27),
        fee: 12000,
        driverIncomeGross: 12000,
        driverAdminFee: 1200,
        driverIncomeNet: 10800,
        status: 'Dibatalkan',
        statusCode: 'CANCELLED',
      ),
    ];

    final summary = DriverEarningsSummary.fromHistory(orders);

    expect(summary.completedCount, 2);
    expect(summary.netIncomeTotal, 26550);
  });
}
