import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';

void main() {
  test('DriverHistoryOrderModel parses server id and display order number', () {
    final order = DriverHistoryOrderModel.fromJson(const {
      'id': 'BDR-260616-5029',
      'order_id': 42,
      'order_number': 'BDR-260616-5029',
      'customer_name': 'Mhn Zayyan',
      'date': '2026-06-16T00:19:00+07:00',
      'fee': 9000,
      'status': 'Selesai',
    });

    expect(order.id, 'BDR-260616-5029');
    expect(order.orderId, 42);
    expect(order.orderNumber, 'BDR-260616-5029');
    expect(order.displayOrderNumber, 'BDR-260616-5029');
  });

  test('DriverHistoryOrderModel keeps old numeric id payload navigable', () {
    final order = DriverHistoryOrderModel.fromJson(const {
      'id': 42,
      'customer_name': 'Mhn Zayyan',
      'date': '2026-06-16T00:19:00+07:00',
      'fee': 9000,
      'status': 'Selesai',
    });

    expect(order.id, '42');
    expect(order.orderId, 42);
    expect(order.displayOrderNumber, '42');
  });

  test('DriverHistoryOrderModel parses driver admin fee breakdown', () {
    final order = DriverHistoryOrderModel.fromJson(const {
      'id': 'BDR-FEE-1',
      'order_id': 51,
      'customer_name': 'Mhn Zayyan',
      'date': '2026-06-16T00:19:00+07:00',
      'fee': 15000,
      'driver_income': 15000,
      'driver_income_gross': 15000,
      'driver_admin_fee_percent': 10,
      'driver_admin_fee': 1500,
      'driver_income_net': 13500,
      'status': 'Selesai',
    });

    expect(order.driverIncome, 15000);
    expect(order.driverIncomeGross, 15000);
    expect(order.driverAdminFeePercent, 10);
    expect(order.driverAdminFee, 1500);
    expect(order.driverIncomeNet, 13500);
    expect(order.netIncomeRounded, 13500);
    expect(order.hasAdminFeeBreakdown, isTrue);
  });
}
