import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/payment_assets.dart';

void main() {
  test('QRIS asset URL uses backend public image path', () {
    expect(
      PaymentAssets.qrisUrl,
      endsWith('/images/payments/qris-bangdeliv-dummy.jpeg'),
    );
    expect(PaymentAssets.qrisUrl, isNot(contains('/api/images/')));
  });
}
