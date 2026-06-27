import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    await tester.tap(find.text('Catat Pembayaran QRIS Manual'));
    await tester.pumpAndSettle();

    expect(find.text('Catat Pembayaran QRIS'), findsOneWidget);
    expect(find.text('Catatan'), findsNothing);

    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();

    expect(recordedAmount, 18000);
  });

  testWidgets('shows rejected QRIS feedback without verification action', (
    tester,
  ) async {
    bool called = false;

    await _pumpCard(
      tester,
      order: _order(
        proofs: const [],
        paymentProofFeedback: const PaymentProofFeedbackModel(
          status: 'rejected',
          reason: 'Nominal tidak sesuai.',
        ),
      ),
      onConfirmTransfer: ({required amount}) async {
        called = true;
      },
    );

    expect(find.text('Ditolak'), findsOneWidget);
    expect(
      find.text('Bukti QRIS ditolak. Menunggu customer mengirim bukti baru.'),
      findsOneWidget,
    );
    expect(find.text('Menunggu customer mengirim bukti baru.'), findsOneWidget);
    expect(find.text('Nominal tidak sesuai.'), findsOneWidget);
    expect(find.text('Verifikasi QRIS'), findsNothing);
    expect(find.text('Catat Pembayaran QRIS Manual'), findsNothing);
    expect(called, isFalse);
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
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: DriverTransferPaymentCard(
            order: order,
            isOrderBusy: false,
            isConfirmingQris: false,
            isRejectingQris: false,
            onConfirmTransfer: onConfirmTransfer,
            onRejectTransfer: onRejectTransfer,
          ),
        ),
      ),
    ),
  );
}

DriverOrderModel _order({
  String serviceTypeCode = ServiceTypeCodes.ride,
  String paymentMethod = 'TRANSFER',
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
    paymentStatus: 'unpaid',
    proofs: proofs,
    paymentProofFeedback: paymentProofFeedback,
  );
}
