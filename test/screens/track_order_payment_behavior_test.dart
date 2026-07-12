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
      expect(source, contains('Upload Bukti QRIS'));
      expect(source, contains('Download QRIS'));
      expect(source, contains('qris-preview-thumbnail'));
      expect(source, contains('showBangNetworkImagePreview'));
      expect(source, isNot(contains('LaunchMode.externalApplication')));
      expect(source, contains('isTransfer && !hasPendingTransferProof'));
      expect(source, isNot(contains('isTransfer || isCancelledWithFee')));
    },
  );

  test(
    'customer payment card renders only through visibility presenter rule',
    () {
      final source = File(_trackOrderSourcePath).readAsStringSync();

      expect(source, contains('List<Widget> _paymentCardSection('));
      expect(
        source,
        contains(
          'TrackOrderPresenter.shouldShowCustomerPaymentCard(order, detail)',
        ),
      );
      expect(source, contains('!hasPendingTransferProof'));
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

  test('payment information is consolidated in payment card', () {
    final source = File(_trackOrderSourcePath).readAsStringSync();
    final detailCard = source.substring(
      source.indexOf('Widget _buildOrderDetailsCard('),
      source.indexOf('Widget _summaryRow('),
    );
    final paymentCard = source.substring(
      source.indexOf('Widget _buildPaymentCard('),
      source.indexOf('Widget _buildTrackingInfoBanner('),
    );

    expect(detailCard, isNot(contains("TrackInfoRow('Pembayaran'")));
    expect(detailCard, isNot(contains("TrackInfoRow('Total'")));

    expect(paymentCard, contains('_paymentMethodSummary'));
    expect(paymentCard, contains('_paymentStatusPill'));
    expect(paymentCard, contains("'Total'"));
    expect(paymentCard, contains('_paymentActionMessage'));
    expect(paymentCard, contains('!hasPendingTransferProof'));
    expect(paymentCard, isNot(contains('Icons.payments_outlined')));
  });

  test(
    'driver card keeps vehicle plate separate from truncated vehicle label',
    () {
      final source = File(_trackOrderSourcePath).readAsStringSync();
      final vehicleLine = source.substring(
        source.indexOf('Widget? _driverVehicleLine('),
        source.indexOf('Widget _buildDriverCard('),
      );

      expect(vehicleLine, contains('Flexible('));
      expect(vehicleLine, contains('flex: 5'));
      expect(vehicleLine, contains("const Text(' - '"));
      expect(vehicleLine, contains('flex: 4'));
      expect(source, isNot(contains("'(driver)'")));
    },
  );

  test('driver card vehicle label uses only vehicle model', () {
    final source = File(_trackOrderSourcePath).readAsStringSync();
    final vehicleLabel = source.substring(
      source.indexOf('String? _driverVehicleLabel('),
      source.indexOf('String? _driverVehiclePlate('),
    );

    expect(vehicleLabel, isNot(contains('driverVehicleType')));
    expect(vehicleLabel, isNot(contains('driverVehicleBrand')));
    expect(vehicleLabel, contains('driverVehicleModel'));
  });

  test('driver card uses compact driver name typography', () {
    final source = File(_trackOrderSourcePath).readAsStringSync();
    final driverCard = source.substring(
      source.indexOf('Widget _buildDriverCard('),
      source.indexOf('String _detailStatusTitle('),
    );

    expect(driverCard, contains('fontSize: 13.5'));
    expect(driverCard, isNot(contains('fontSize: 16')));
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
    'failed shopping merchant notice does not expose resolution actions',
    () {
      final widgetsSource = File(_trackOrderWidgetsPath).readAsStringSync();
      final failedStopNotice = widgetsSource.substring(
        widgetsSource.indexOf('Widget _failedStopNotice('),
        widgetsSource.indexOf('Widget _stopSection('),
      );

      expect(
        failedStopNotice,
        isNot(contains('widget.detail.canResolveFailedShoppingMerchant')),
      );
      expect(failedStopNotice, isNot(contains('if (canResolveFailedStop)')));
      expect(failedStopNotice, isNot(contains('Tambah pengganti')));
      expect(failedStopNotice, isNot(contains('Lanjut tanpa ini')));
    },
  );

  test('driver manual delivery fee notice uses customer-friendly copy', () {
    final source = File(_trackOrderSourcePath).readAsStringSync();

    expect(
      source,
      contains(r"return 'Ongkir diperbarui menjadi $amountText.';"),
    );
    expect(source, isNot(contains('Ongkir diperbarui driver')));
    expect(source, contains('reason: deliveryFeeNoticeReason'));

    final noticeReason = source.substring(
      source.indexOf('String? _deliveryFeeNoticeReason('),
      source.indexOf('String _paymentMessage('),
    );
    expect(noticeReason, contains('detail.deliveryFeeChangeNote'));
    expect(noticeReason, contains('order.deliveryFeeChangeNote'));
    expect(
      noticeReason,
      isNot(contains('detail.deliveryFeeNegotiation?.note')),
    );
  });

  test('customer cancellation action lives in tracking, not activity card', () {
    final trackSource = File(_trackOrderSourcePath).readAsStringSync();
    final activitySource = File(
      'lib/features/orders/presentation/screens/activity_screen.dart',
    ).readAsStringSync();

    expect(trackSource, contains('_buildCustomerCancelOrderAction(order)'));
    expect(trackSource, contains('showCustomerOrderCancelSheet(context)'));
    expect(trackSource, contains("'track-cancel-order-\${order.id}'"));
    expect(trackSource, contains('.cancelOrder(order.id, reason: reason)'));
    expect(activitySource, isNot(contains('showCancelAction:')));
    expect(activitySource, isNot(contains('onCancel:')));
  });

  test('customer Nitip selector excludes dropoff and keeps it in summary', () {
    final source = File(_trackOrderSourcePath).readAsStringSync();
    final selector = source.substring(
      source.indexOf('Widget _buildShoppingPointSelector('),
      source.indexOf('// Progress stepper'),
    );

    expect(selector, contains("('summary', 'Ringkasan')"));
    expect(selector, contains("'Tempat \${stop.sequenceNo"));
    expect(selector, isNot(contains("('dropoff', 'Antar')")));
    expect(source, isNot(contains('onDropoffSelected:')));
    expect(source, contains("_selectedShoppingPointId == 'dropoff'"));
    expect(source, contains("_selectedShoppingPointId = 'summary'"));
  });

  test(
    'customer tracking sheet header uses shared drag region and four snaps',
    () {
      final source = File(_trackOrderSourcePath).readAsStringSync();

      expect(source, contains('DraggableScrollableController'));
      expect(source, contains('BangSheetDragRegion('));
      expect(source, contains('customer-tracking-sheet-header-drag-region'));
      expect(source, contains('customer-tracking-sheet-handle'));
      expect(source, contains('customer-shopping-point-selector'));
      expect(source, contains('_trackingSheetMinChildSize'));
      expect(source, contains('_trackingSheetInitialChildSize'));
      expect(source, contains('_trackingSheetMidChildSize'));
      expect(source, contains('_trackingSheetMaxChildSize'));
    },
  );
}
