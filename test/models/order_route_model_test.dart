import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';

void main() {
  test('customer detail parses generic route payload', () {
    final detail = CustomerOrderDetailModel.fromJson({
      'id': 12,
      'order_number': 'BDR-0001',
      'service_type': {'code': 'RIDE', 'display_name': 'Antar Jemput'},
      'status_ref': {
        'code': 'DRIVER_ASSIGNED',
        'display_name': 'Driver Ditugaskan',
        'is_terminal': false,
      },
      'total_price': 12000,
      'delivery_address': 'Dropoff',
      'route': {
        'encoded_polyline': 'ride-polyline',
        'ordered_pickup_location_ids': [1, '2'],
      },
    });

    expect(detail.route?.encodedPolyline, 'ride-polyline');
    expect(detail.route?.orderedPickupLocationIds, [1, 2]);
  });

  test('customer detail falls back to legacy shopping route snapshot', () {
    final detail = CustomerOrderDetailModel.fromJson({
      'id': 13,
      'order_number': 'BDS-0001',
      'service_type': {'code': 'SHOPPING', 'display_name': 'Titip Belanja'},
      'status_ref': {
        'code': 'DRIVER_ASSIGNED',
        'display_name': 'Driver Ditugaskan',
        'is_terminal': false,
      },
      'total_price': 22000,
      'delivery_address': 'Customer',
      'shopping_order': {
        'pricing_snapshot': {
          'shopping_route': {
            'encoded_polyline': 'legacy-shopping-polyline',
            'ordered_pickup_location_ids': [7, '9'],
          },
        },
      },
    });

    expect(detail.route?.encodedPolyline, 'legacy-shopping-polyline');
    expect(detail.shoppingRoute?.orderedPickupLocationIds, [7, 9]);
  });

  test('driver order parses generic and legacy route payloads', () {
    final rideOrder = DriverOrderModel.fromJson({
      'id': '77',
      'customer_name': 'Customer',
      'service_type_code': 'RIDE',
      'pickup_address': 'Pickup',
      'dropoff_address': 'Dropoff',
      'route': {'encoded_polyline': 'driver-ride-polyline'},
    });
    final shoppingOrder = DriverOrderModel.fromJson({
      'id': '78',
      'customer_name': 'Customer',
      'service_type_code': 'SHOPPING',
      'pickup_address': 'Merchant',
      'dropoff_address': 'Customer',
      'shopping_route': {
        'encoded_polyline': 'driver-shopping-polyline',
        'ordered_pickup_location_ids': ['4', 6],
      },
    });

    expect(rideOrder.route?.encodedPolyline, 'driver-ride-polyline');
    expect(shoppingOrder.route?.encodedPolyline, 'driver-shopping-polyline');
    expect(shoppingOrder.shoppingRoute?.orderedPickupLocationIds, [4, 6]);
  });
}
