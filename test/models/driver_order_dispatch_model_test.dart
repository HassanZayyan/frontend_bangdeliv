import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/driver_orders/application/driver_dispatch_presenter.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';

void main() {
  test('DriverOrderModel parses dispatch metadata', () {
    final order = DriverOrderModel.fromJson(const <String, dynamic>{
      'id': '10',
      'customer_name': 'Customer',
      'pickup_address': 'Pickup',
      'dropoff_address': 'Dropoff',
      'eta_minutes': 0,
      'fee': 12000,
      'item_count': 1,
      'dispatch': <String, dynamic>{
        'priority_rank': 1,
        'distance_to_pickup_meters': 1250,
        'distance_to_pickup_km': 1.25,
        'distance_to_customer_meters': 1250,
        'distance_to_customer_km': 1.25,
        'distance_target_role': 'customer_pickup',
        'distance_target_label': 'titik jemput',
        'distance_label': '1,3 km dari titik jemput',
        'distance_bucket': 'NEAR',
        'location_fresh': true,
      },
    });

    expect(order.dispatch?.priorityRank, 1);
    expect(order.dispatch?.distanceToPickupMeters, 1250);
    expect(order.dispatch?.distanceToPickupKm, 1.25);
    expect(order.dispatch?.distanceToCustomerMeters, 1250);
    expect(order.dispatch?.distanceToCustomerKm, 1.25);
    expect(order.dispatch?.distanceTargetRole, 'customer_pickup');
    expect(order.dispatch?.distanceTargetLabel, 'titik jemput');
    expect(order.dispatch?.distanceLabel, '1,3 km dari titik jemput');
    expect(order.dispatch?.distanceBucket, 'NEAR');
    expect(order.dispatch?.locationFresh, isTrue);
  });

  test('DriverOrderModel parses driver admin fee breakdown', () {
    final order = DriverOrderModel.fromJson(const <String, dynamic>{
      'id': '10',
      'customer_name': 'Customer',
      'pickup_address': 'Pickup',
      'dropoff_address': 'Dropoff',
      'eta_minutes': 0,
      'fee': 15000,
      'driver_income_gross': 15000,
      'driver_admin_fee_percent': 10,
      'driver_admin_fee': 1500,
      'driver_income_net': 13500,
      'item_count': 1,
    });

    expect(order.fee, 15000);
    expect(order.driverIncomeGross, 15000);
    expect(order.driverAdminFeePercent, 10);
    expect(order.driverAdminFee, 1500);
    expect(order.driverIncomeNet, 13500);
  });

  test('DriverDispatchPresenter falls back to unknown distance', () {
    final viewData = DriverDispatchPresenter.present(null);

    expect(viewData.label, 'Jarak belum tersedia');
    expect(viewData.bucket, 'UNKNOWN');
    expect(viewData.priorityRank, isNull);
  });
}
