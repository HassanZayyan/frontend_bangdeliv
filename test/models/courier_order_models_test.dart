import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';

void main() {
  test(
    'customer order summary uses courier package description as item summary',
    () {
      final order = CustomerOrderSummaryModel.fromJson({
        'id': 42,
        'order_number': 'BD-COU-0001',
        'service_type': {'code': 'COURIER', 'display_name': 'Kurir'},
        'status_ref': {
          'code': 'PENDING',
          'display_name': 'Menunggu Driver',
          'is_terminal': false,
        },
        'courier_order': {'package_description': 'dokumen kontrak'},
        'items': [],
        'total_price': 18000,
        'delivery_address': 'Jl. Tujuan',
        'payment_status': 'unpaid',
        'payment_method': 'COD',
      });

      expect(order.serviceTypeCode, 'COURIER');
      expect(order.itemsSummary, 'dokumen kontrak');
    },
  );

  test('driver order parses courier package safety metadata', () {
    final order = DriverOrderModel.fromJson({
      'id': '77',
      'order_number': 'BD-COU-0077',
      'customer_name': 'Customer Kurir',
      'service_type_code': 'COURIER',
      'pickup_address': 'Pickup',
      'dropoff_address': 'Dropoff',
      'eta_minutes': 12,
      'fee': 18000,
      'total_price': 18000,
      'item_count': 1,
      'status_code': 'ARRIVED_PICKUP',
      'payment_status': 'unpaid',
      'payment_method': 'COD',
      'package_description': 'dokumen kontrak',
      'package_estimated_weight_kg': 1.5,
      'package_length_cm': 30,
      'package_width_cm': 20,
      'package_height_cm': 5,
      'package_size_class': 'SMALL',
      'package_safety_status': 'ALLOWED',
      'package_safety_reason': 'Paket aman untuk layanan kurir motor.',
      'package_packing_note': 'Amplop cokelat',
    });

    expect(order.packageDescription, 'dokumen kontrak');
    expect(order.packageEstimatedWeightKg, 1.5);
    expect(order.packageLengthCm, 30);
    expect(order.packageSafetyStatus, 'ALLOWED');
    expect(order.packagePackingNote, 'Amplop cokelat');
  });
}
