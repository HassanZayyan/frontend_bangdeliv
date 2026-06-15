import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _trackOrderSourcePath =
    'lib/features/tracking/presentation/screens/track_order_screen.dart';
const _trackOrderWidgetsPath =
    'lib/features/tracking/presentation/widgets/track_order_widgets.dart';

void main() {
  test(
    'customer payment card does not expose manual payment method switch',
    () {
      final source = File(_trackOrderSourcePath).readAsStringSync();

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
    final source = File(_trackOrderSourcePath).readAsStringSync();
    final summaryMethod = source.substring(
      source.indexOf('String _paymentMessage('),
      source.indexOf('Widget _buildProofsCard('),
    );

    expect(summaryMethod, contains('isTransfer'));
    expect(summaryMethod, contains("return '';"));
  });

  test('shopping item card does not duplicate COD payment instruction', () {
    final source =
        File(_trackOrderSourcePath).readAsStringSync() +
        File(_trackOrderWidgetsPath).readAsStringSync();
    final widgetsSource = File(_trackOrderWidgetsPath).readAsStringSync();
    final shoppingItemsCard = widgetsSource.substring(
      widgetsSource.indexOf('class TrackShoppingOrderItemsCard'),
      widgetsSource.indexOf('Widget _failedStopNotice('),
    );

    expect(source, isNot(contains('String _shoppingPaymentMessage(')));
    expect(shoppingItemsCard, isNot(contains('Bayar tunai ke driver')));
    expect(shoppingItemsCard, isNot(contains('paymentMessage')));
  });

  test(
    'failed shopping merchant actions only show while order is editable',
    () {
      final widgetsSource = File(_trackOrderWidgetsPath).readAsStringSync();
      final failedStopNotice = widgetsSource.substring(
        widgetsSource.indexOf('Widget _failedStopNotice('),
        widgetsSource.indexOf('Widget _stopSection('),
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
