import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/order_formatters.dart';

void main() {
  test('shopping attempt starts at one and hides zero total failures', () {
    expect(
      formatShoppingAttemptProgress(
        attemptNo: 0,
        attemptLimit: 3,
        totalFailed: 0,
      ),
      'Percobaan 1/3',
    );
  });

  test('shopping attempt shows concise total after a failure', () {
    expect(
      formatShoppingAttemptProgress(
        attemptNo: 2,
        attemptLimit: 3,
        totalFailed: 1,
      ),
      'Percobaan 2/3 • Total gagal 1',
    );
  });
}
