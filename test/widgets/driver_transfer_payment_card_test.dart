import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/core/widgets/bang_swipe_action_button.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/payment_proof_feedback_model.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';
import 'package:frontend_bangdeliv/widgets/driver_transfer_payment_card.dart';

void main() {
  testWidgets(
    'shows transfer proof and verifies payment for every service type',
    (tester) async {
      for (final serviceType in const [
        ServiceTypeCodes.ride,
        ServiceTypeCodes.courier,
        ServiceTypeCodes.shopping,
      ]) {
        double? verifiedAmount;

        await _pumpCard(
          tester,
          order: _order(
            serviceTypeCode: serviceType,
            proofs: [
              DriverOrderProofModel(
                id: 1,
                type: 'payment_transfer',
                label: 'Bukti QRIS',
                photoUrl: 'https://example.com/transfer.jpg',
                status: 'pending',
                note: 'Transfer BCA',
                createdAt: DateTime.parse('2026-06-06T14:30:00Z'),
              ),
            ],
          ),
          onConfirmTransfer: ({required amount}) async {
            verifiedAmount = amount;
          },
          onRejectTransfer: ({required reason}) async {},
        );

        expect(find.text('Bukti QRIS Customer'), findsOneWidget);
        expect(find.text('Lihat Bukti'), findsOneWidget);
        expect(find.text('Verifikasi QRIS'), findsOneWidget);
        expect(find.byType(BangSwipeActionButton), findsNothing);

        await tester.tap(find.text('Lihat Bukti'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);

        Navigator.of(tester.element(find.byType(Dialog))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Verifikasi QRIS'));
        await tester.pumpAndSettle();

        expect(find.text('Verifikasi Bukti QRIS'), findsOneWidget);
        expect(find.text('Setujui'), findsOneWidget);
        expect(find.text('Tolak'), findsOneWidget);

        await tester.tap(find.text('Setujui'));
        await tester.pumpAndSettle();

        expect(verifiedAmount, 18000);
      }
    },
  );

  testWidgets('requires reason before rejecting transfer proof', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    String? rejectionReason;

    await _pumpCard(
      tester,
      order: _order(
        proofs: [
          DriverOrderProofModel(
            id: 1,
            type: 'payment_transfer',
            label: 'Bukti QRIS',
            photoUrl: 'https://example.com/transfer.jpg',
            status: 'pending',
            note: 'Bukti QRIS customer.',
            createdAt: DateTime.parse('2026-06-06T14:30:00Z'),
          ),
        ],
      ),
      onConfirmTransfer: ({required amount}) async {},
      onRejectTransfer: ({required reason}) async {
        rejectionReason = reason;
      },
    );

    await tester.tap(find.text('Verifikasi QRIS'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Alasan penolakan'), findsOneWidget);

    await tester.tap(find.text('Tolak Bukti'));
    await tester.pumpAndSettle();

    expect(find.text('Alasan penolakan wajib diisi.'), findsOneWidget);
    expect(rejectionReason, isNull);

    await tester.enterText(find.byType(TextField), 'Nominal tidak sesuai.');
    await tester.tap(find.text('Tolak Bukti'));
    await tester.pumpAndSettle();

    expect(rejectionReason, 'Nominal tidak sesuai.');
  });

  testWidgets('shows waiting state and manual fallback without proof', (
    tester,
  ) async {
    double? recordedAmount;

    await _pumpCard(
      tester,
      order: _order(proofs: const []),
      onConfirmTransfer: ({required amount}) async {
        recordedAmount = amount;
      },
    );

    expect(find.text('Menunggu bukti QRIS dari customer.'), findsOneWidget);
    expect(find.text('Catat Pembayaran QRIS Manual'), findsOneWidget);
    expect(find.text('Verifikasi QRIS'), findsNothing);
    expect(find.byType(BangSwipeActionButton), findsNothing);

    await tester.tap(find.text('Catat Pembayaran QRIS Manual'));
    await tester.pumpAndSettle();

    expect(find.text('Catat Pembayaran QRIS'), findsOneWidget);
    expect(find.text('Catatan'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '18.000',
    );

    await tester.enterText(find.byType(TextField), '50000');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '50.000',
    );

    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();

    expect(recordedAmount, 50000);
  });

  testWidgets('manual QRIS dialog remains usable above keyboard', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);

    await _pumpCard(
      tester,
      order: _order(proofs: const []),
      onConfirmTransfer: ({required amount}) async {},
    );

    await tester.tap(find.text('Catat Pembayaran QRIS Manual'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Catat Pembayaran QRIS'), findsOneWidget);
    expect(find.text('Catat'), findsOneWidget);
  });

  testWidgets('swipes rejected QRIS bypass for every service type', (
    tester,
  ) async {
    for (final serviceType in const [
      ServiceTypeCodes.ride,
      ServiceTypeCodes.courier,
      ServiceTypeCodes.shopping,
    ]) {
      var bypassCalls = 0;

      await _pumpCard(
        tester,
        order: _order(
          serviceTypeCode: serviceType,
          proofs: const [],
          paymentProofFeedback: const PaymentProofFeedbackModel(
            status: 'rejected',
            reason: 'Nominal tidak sesuai.',
          ),
        ),
        onConfirmTransfer: ({required amount}) async {},
        onBypassRejectedTransfer: () async {
          bypassCalls += 1;
        },
      );

      expect(find.text('Ditolak'), findsOneWidget);
      expect(
        find.text(
          'Bukti QRIS ditolak. Tunggu bukti baru atau bypass jika pembayaran sudah dipastikan.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Customer dapat mengirim bukti baru. Jika pembayaran sudah dipastikan, driver dapat melakukan bypass.',
        ),
        findsOneWidget,
      );
      expect(find.text('Nominal tidak sesuai.'), findsOneWidget);
      expect(find.text('Verifikasi QRIS'), findsNothing);
      expect(find.text('Catat Pembayaran QRIS Manual'), findsNothing);
      expect(find.text('Geser untuk bypass QRIS'), findsOneWidget);

      await tester.drag(
        find.byType(BangSwipeActionButton),
        const Offset(800, 0),
      );
      await tester.pumpAndSettle();

      expect(bypassCalls, 1);
    }
  });

  testWidgets('hides rejected QRIS bypass after payment is paid', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      order: _order(
        paymentStatus: 'paid',
        paymentProofFeedback: const PaymentProofFeedbackModel(
          status: 'rejected',
          reason: 'Nominal tidak sesuai.',
        ),
      ),
      onConfirmTransfer: ({required amount}) async {},
      onBypassRejectedTransfer: () async {},
    );

    expect(find.byType(BangSwipeActionButton), findsNothing);
    expect(find.text('Pembayaran QRIS sudah diverifikasi.'), findsOneWidget);
  });

  testWidgets('shows rejected QRIS bypass loading state', (tester) async {
    await _pumpCard(
      tester,
      order: _order(
        paymentProofFeedback: const PaymentProofFeedbackModel(
          status: 'rejected',
          reason: 'Nominal tidak sesuai.',
        ),
      ),
      isOrderBusy: true,
      isBypassingQris: true,
      onConfirmTransfer: ({required amount}) async {},
      onBypassRejectedTransfer: () async {},
    );

    expect(find.text('Memproses bypass QRIS...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows QRIS loading only on verification action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: DriverTransferPaymentCard(
              order: _order(
                proofs: [
                  DriverOrderProofModel(
                    id: 1,
                    type: 'payment_transfer',
                    label: 'Bukti QRIS',
                    photoUrl: 'https://example.com/transfer.jpg',
                    status: 'pending',
                    createdAt: DateTime.parse('2026-06-06T14:30:00Z'),
                  ),
                ],
              ),
              isOrderBusy: true,
              isConfirmingQris: true,
              isRejectingQris: false,
              onConfirmTransfer: ({required amount}) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Lihat Bukti'), findsOneWidget);
  });

  testWidgets('hides transfer card for COD order without proof', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      order: _order(paymentMethod: 'COD', proofs: const []),
      onConfirmTransfer: ({required amount}) async {},
    );

    expect(find.text('Bukti QRIS Customer'), findsNothing);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required DriverOrderModel order,
  required DriverTransferPaymentCallback onConfirmTransfer,
  DriverTransferRejectCallback? onRejectTransfer,
  DriverTransferBypassCallback? onBypassRejectedTransfer,
  bool isOrderBusy = false,
  bool isBypassingQris = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: DriverTransferPaymentCard(
            order: order,
            isOrderBusy: isOrderBusy,
            isConfirmingQris: false,
            isRejectingQris: false,
            isBypassingQris: isBypassingQris,
            onConfirmTransfer: onConfirmTransfer,
            onRejectTransfer: onRejectTransfer,
            onBypassRejectedTransfer: onBypassRejectedTransfer,
          ),
        ),
      ),
    ),
  );
}

DriverOrderModel _order({
  String serviceTypeCode = ServiceTypeCodes.ride,
  String paymentMethod = 'TRANSFER',
  String paymentStatus = 'unpaid',
  List<DriverOrderProofModel> proofs = const <DriverOrderProofModel>[],
  PaymentProofFeedbackModel? paymentProofFeedback,
}) {
  return DriverOrderModel(
    id: 'ORD-$serviceTypeCode',
    customerName: 'Customer',
    serviceTypeCode: serviceTypeCode,
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 18000,
    totalPrice: 18000,
    itemCount: 1,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    proofs: proofs,
    paymentProofFeedback: paymentProofFeedback,
  );
}
