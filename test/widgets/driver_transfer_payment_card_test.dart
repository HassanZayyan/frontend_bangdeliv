import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
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
        String? verifiedNote;

        await _pumpCard(
          tester,
          order: _order(
            serviceTypeCode: serviceType,
            proofs: [
              DriverOrderProofModel(
                id: 1,
                type: 'payment_transfer',
                label: 'Bukti transfer',
                photoUrl: 'https://example.com/transfer.jpg',
                status: 'pending',
                note: 'Transfer BCA',
                createdAt: DateTime.parse('2026-06-06T14:30:00Z'),
              ),
            ],
          ),
          onConfirmTransfer: ({required amount, required note}) async {
            verifiedAmount = amount;
            verifiedNote = note;
          },
        );

        expect(find.text('Bukti Transfer Customer'), findsOneWidget);
        expect(find.text('Lihat Bukti'), findsOneWidget);
        expect(find.text('Verifikasi Transfer'), findsOneWidget);

        await tester.tap(find.text('Lihat Bukti'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);

        Navigator.of(tester.element(find.byType(Dialog))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Verifikasi Transfer'));
        await tester.pumpAndSettle();

        expect(verifiedAmount, 18000);
        expect(verifiedNote, contains('Verifikasi bukti transfer customer'));
      }
    },
  );

  testWidgets('shows waiting state and manual fallback without proof', (
    tester,
  ) async {
    double? recordedAmount;
    String? recordedNote;

    await _pumpCard(
      tester,
      order: _order(proofs: const []),
      onConfirmTransfer: ({required amount, required note}) async {
        recordedAmount = amount;
        recordedNote = note;
      },
    );

    expect(find.text('Menunggu bukti transfer dari customer.'), findsOneWidget);
    expect(find.text('Catat Transfer Manual'), findsOneWidget);
    expect(find.text('Verifikasi Transfer'), findsNothing);

    await tester.tap(find.text('Catat Transfer Manual'));
    await tester.pumpAndSettle();

    expect(find.text('Catat Pembayaran Transfer'), findsOneWidget);

    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();

    expect(recordedAmount, 18000);
    expect(recordedNote, 'Pembayaran transfer dicatat dari app driver.');
  });

  testWidgets('hides transfer card for COD order without proof', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      order: _order(paymentMethod: 'COD', proofs: const []),
      onConfirmTransfer: ({required amount, required note}) async {},
    );

    expect(find.text('Bukti Transfer Customer'), findsNothing);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required DriverOrderModel order,
  required DriverTransferPaymentCallback onConfirmTransfer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: DriverTransferPaymentCard(
            order: order,
            isProcessing: false,
            onConfirmTransfer: onConfirmTransfer,
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
  );
}
