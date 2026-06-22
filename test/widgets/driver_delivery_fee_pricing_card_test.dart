import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_meta_widgets.dart';
import 'package:frontend_bangdeliv/models/amount_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/delivery_fee_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  testWidgets('manual delivery fee edit requires reason before submit', (
    tester,
  ) async {
    var submitCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(deliveryFee: 5000),
            onEditDeliveryFee: ({required amount, required reason}) async {
              submitCount += 1;
              return null;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Alasan edit ongkir wajib diisi.'), findsOneWidget);
    expect(find.text('Edit Ongkir Manual'), findsOneWidget);
    expect(submitCount, 0);
  });

  testWidgets('pricing card hides delivery fee edit when callback is omitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              deliveryFee: 5000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                amount: AmountNegotiationModel(
                  status: 'APPROVED',
                  canDriverSubmitQuote: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('pricing card shows customer delivery fee counter offer', (
    tester,
  ) async {
    var acceptCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              deliveryFee: 15000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                amount: AmountNegotiationModel(
                  status: 'PENDING_DRIVER',
                  quotedAmount: 22000,
                  counterAmount: 19000,
                  canDriverAcceptCounter: true,
                ),
                oldDeliveryFee: 15000,
              ),
            ),
            onAcceptDeliveryFeeCounter: () async {
              acceptCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('Tawaran ongkir customer'), findsOneWidget);
    expect(find.text('Rp19.000'), findsOneWidget);
    expect(find.text('Revisi driver'), findsOneWidget);
    expect(find.text('Rp22.000'), findsOneWidget);
    expect(find.text('Ongkir saat ini'), findsOneWidget);
    expect(find.text('Rp15.000'), findsNWidgets(2));

    await tester.tap(find.text('Terima Tawaran'));
    await tester.pump();

    expect(acceptCount, 1);
  });

  testWidgets('customer delivery fee counter accept button shows loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              deliveryFee: 15000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                amount: AmountNegotiationModel(
                  status: 'PENDING_DRIVER',
                  counterAmount: 19000,
                  canDriverAcceptCounter: true,
                ),
              ),
            ),
            isAcceptingDeliveryFeeCounter: true,
            onAcceptDeliveryFeeCounter: () async {},
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('pricing card hides customer counter when capability is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              deliveryFee: 15000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                amount: AmountNegotiationModel(
                  status: 'PENDING_DRIVER',
                  counterAmount: 19000,
                  canDriverAcceptCounter: false,
                ),
              ),
            ),
            onAcceptDeliveryFeeCounter: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Tawaran ongkir customer'), findsNothing);
    expect(find.text('Terima Tawaran'), findsNothing);
  });
}

DriverOrderModel _order({
  double? deliveryFee,
  DeliveryFeeNegotiationModel? deliveryFeeNegotiation,
}) {
  return DriverOrderModel(
    id: '99',
    customerName: 'Customer',
    serviceTypeCode: ServiceTypeCodes.ride,
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 9000,
    deliveryFee: deliveryFee,
    totalPrice: 9000,
    itemCount: 1,
    statusCode: OrderStatusCodes.driverAssigned,
    paymentMethod: 'COD',
    paymentStatus: 'unpaid',
    deliveryFeeNegotiation: deliveryFeeNegotiation,
  );
}
