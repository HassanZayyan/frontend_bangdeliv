import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/order_ui_helpers.dart';

void main() {
  test('careful carry default delivery fee adds 50 percent', () {
    expect(carefulCarryDefaultDeliveryFee(5000), 7500);
    expect(carefulCarryDefaultDeliveryFee(5500), 8250);
    expect(carefulCarryDefaultDeliveryFee(0), 0);
  });
}
