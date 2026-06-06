import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';

void main() {
  test('ride-specific statuses have labels and trackable pickup state', () {
    expect(
      orderStatusLabel(OrderStatusCodes.arrivedMerchant),
      'Driver tiba di lokasi ambil',
    );
    expect(
      orderStatusDisplayLabel(
        OrderStatusCodes.arrivedMerchant,
        fallbackLabel: 'Driver Tiba di Merchant',
      ),
      'Driver tiba di lokasi ambil',
    );
    expect(
      orderStatusLabel(OrderStatusCodes.arrivedPickup),
      'Driver Tiba di Titik Jemput',
    );
    expect(
      orderStatusLabel(OrderStatusCodes.arrivedDropoff),
      'Driver Tiba di Tujuan',
    );
    expect(isDriverLocationTrackable(OrderStatusCodes.arrivedPickup), isTrue);
    expect(isDriverLocationTrackable(OrderStatusCodes.arrivedDropoff), isFalse);
  });
}
