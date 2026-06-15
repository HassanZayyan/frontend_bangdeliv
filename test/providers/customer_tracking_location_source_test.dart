import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer tracking provider applies realtime driver location events', () {
    final source = File(
      'lib/features/tracking/application/customer_order_tracking_provider.dart',
    ).readAsStringSync();

    expect(source, contains('bool get hasLiveDriverLocation =>'));
    expect(source, contains('_applyLocationEvent(event)'));
    expect(source, contains('driverLatitude: event.latitude'));
    expect(source, contains('driverLongitude: event.longitude'));
  });
}
