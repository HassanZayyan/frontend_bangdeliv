import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/order_formatters.dart';

void main() {
  test('shopping progress shows zero failures against the quota', () {
    expect(
      formatShoppingAttemptProgress(
        attemptNo: 0,
        attemptLimit: 3,
        totalFailed: 0,
      ),
      'Gagal 0/3',
    );
  });

  test('shopping progress counts failed stores against the quota', () {
    expect(
      formatShoppingAttemptProgress(
        attemptNo: 2,
        attemptLimit: 3,
        totalFailed: 1,
      ),
      'Gagal 1/3',
    );
  });
}
