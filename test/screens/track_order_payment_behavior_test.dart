import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'customer payment card does not expose manual payment method switch',
    () {
      final source = File(
        'lib/screens/track_order_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('Ubah ke Transfer')));
      expect(source, isNot(contains('_changePaymentMethodToTransfer')));
      expect(source, contains('Upload Bukti Transfer'));
      expect(source, contains('isTransfer || isCancelledWithFee'));
    },
  );

  test('customer order api no longer exposes payment method switch helper', () {
    final source = File(
      'lib/services/customer_order_api_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('updatePaymentMethod')));
    expect(source, isNot(contains('/payment-method')));
    expect(source, contains('uploadTransferEvidence'));
  });

  test('transfer orders do not show cash payment instructions in summary', () {
    final source = File(
      'lib/screens/track_order_screen.dart',
    ).readAsStringSync();
    final summaryMethod = source.substring(
      source.indexOf('String _paymentMessage('),
      source.indexOf('Widget _buildProofsCard('),
    );

    expect(summaryMethod, contains('isTransfer'));
    expect(summaryMethod, contains("return '';"));
  });

  test('shopping item card does not duplicate COD payment instruction', () {
    final source = File(
      'lib/screens/track_order_screen.dart',
    ).readAsStringSync();
    final shoppingItemsCard = source.substring(
      source.indexOf('class _ShoppingOrderItemsCard'),
      source.indexOf('Widget _failedStopNotice('),
    );

    expect(source, isNot(contains('String _shoppingPaymentMessage(')));
    expect(shoppingItemsCard, isNot(contains('Bayar tunai ke driver')));
    expect(shoppingItemsCard, isNot(contains('paymentMessage')));
  });

  test(
    'failed shopping merchant actions only show while order is editable',
    () {
      final source = File(
        'lib/screens/track_order_screen.dart',
      ).readAsStringSync();
      final failedStopNotice = source.substring(
        source.indexOf('Widget _failedStopNotice('),
        source.indexOf('Widget _stopSection('),
      );

      expect(
        failedStopNotice,
        contains(
          'final canResolveFailedStop = widget.detail.canEditShoppingItems',
        ),
      );
      expect(failedStopNotice, contains('if (canResolveFailedStop)'));
      expect(failedStopNotice, contains('Tambah pengganti'));
      expect(failedStopNotice, contains('Lanjut tanpa ini'));
    },
  );
}
