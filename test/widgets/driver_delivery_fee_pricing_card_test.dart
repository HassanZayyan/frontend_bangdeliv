import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/core/widgets/bang_swipe_action_button.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_fee_widgets.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_meta_widgets.dart';
import 'package:frontend_bangdeliv/models/amount_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/delivery_fee_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  test('shopping pricing parses cancellation base and percent', () {
    final pricing = DriverShoppingPricingModel.fromJson({
      'subtotal': 0,
      'delivery_fee': 0,
      'service_fee': 50000,
      'total_price': 50000,
      'cancellation_penalty': 50000,
      'cancellation_penalty_base_delivery_fee': 100000,
      'cancellation_penalty_percent': 50,
    });

    expect(pricing.cancellationPenaltyBaseDeliveryFee, 100000);
    expect(pricing.cancellationPenaltyPercent, 50);
  });

  testWidgets('shopping cancellation dialog previews half fee and validates', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    DriverShoppingCancellationInput? result;
    final order = _order(
      serviceTypeCode: ServiceTypeCodes.shopping,
      deliveryFee: 80000,
      shoppingPricing: const DriverShoppingPricingModel(
        subtotal: 0,
        deliveryFee: 80000,
        serviceFee: 0,
        totalPrice: 80000,
        cancellationPenalty: 40000,
        cancellationPenaltyBaseDeliveryFee: 100000,
        cancellationPenaltyPercent: 50,
        recalculationVersion: 1,
        hasPendingManualPrices: false,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDriverShoppingCancelWithFeeDialog(
                  context,
                  order: order,
                );
              },
              child: const Text('Buka dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka dialog'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Batalkan Order dengan Fee 50%'), findsOneWidget);
    expect(find.text('Fee pembatalan (50%)'), findsOneWidget);
    expect(find.text('Rp 50.000'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '100.000',
    );

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '120000');
    await tester.pump();
    expect(find.text('Rp 60.000'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('confirm-shopping-cancellation-fee')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alasan koreksi ongkir wajib diisi.'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(
      find.byType(TextField).last,
      'Rute aktual lebih jauh dari estimasi.',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-shopping-cancellation-fee')),
    );
    await tester.pumpAndSettle();

    expect(result?.baseDeliveryFee, 120000);
    expect(result?.reason, 'Rute aktual lebih jauh dari estimasi.');
    expect(find.text('Batalkan Order dengan Fee 50%'), findsNothing);
  });

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

  testWidgets('manual delivery fee dialog remains usable above keyboard', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(deliveryFee: 15000),
            onEditDeliveryFee: ({required amount, required reason}) async =>
                null,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Ongkir Manual'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
  });

  testWidgets('shopping fee edit uses all-in total and explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              deliveryFee: 15000,
              shoppingPricing: const DriverShoppingPricingModel(
                subtotal: 50000,
                deliveryFee: 15000,
                serviceFee: 10000,
                totalPrice: 75000,
                cancellationPenalty: 0,
                failedTripCompensation: 10000,
                recalculationVersion: 1,
                hasPendingManualPrices: false,
              ),
            ),
            onEditDeliveryFee: ({required amount, required reason}) async =>
                null,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Total Ongkir Nitip'), findsOneWidget);
    expect(find.text('Total ongkir Nitip'), findsOneWidget);
    expect(
      find.text(
        'Nominal ini mencakup ongkir aktif dan kompensasi perjalanan gagal.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '25.000',
    );
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

  testWidgets('shopping counter uses all-in total transport labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              deliveryFee: 15000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                amount: AmountNegotiationModel(
                  status: 'PENDING_DRIVER',
                  quotedAmount: 26000,
                  counterAmount: 24000,
                  canDriverAcceptCounter: true,
                ),
                pricingScope: 'SHOPPING_TOTAL_TRANSPORT',
                previousTotalTransport: 30000,
              ),
            ),
            onAcceptDeliveryFeeCounter: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Tawaran total ongkir customer'), findsOneWidget);
    expect(find.text('Total usulan driver'), findsOneWidget);
    expect(find.text('Total transport sebelumnya'), findsOneWidget);
    expect(find.text('Tawaran ongkir customer'), findsNothing);
    expect(find.text('Ongkir saat ini'), findsNothing);
  });

  testWidgets('pricing card shows delivery fee bypass when waiting customer', (
    tester,
  ) async {
    var bypassCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              deliveryFee: 15000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                amount: AmountNegotiationModel(
                  status: 'PENDING_CUSTOMER',
                  quotedAmount: 22000,
                ),
              ),
            ),
            onBypassDeliveryFee: () async {
              bypassCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('Menunggu persetujuan ongkir customer'), findsOneWidget);
    expect(find.text('Geser untuk bypass ongkir'), findsOneWidget);
    expect(find.text('Rp22.000'), findsOneWidget);

    await tester.drag(
      find.byIcon(Icons.keyboard_double_arrow_right_rounded),
      const Offset(800, 0),
    );
    await tester.pumpAndSettle();

    expect(bypassCount, 1);
  });

  testWidgets('delivery fee bypass button shows loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              deliveryFee: 15000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                amount: AmountNegotiationModel(
                  status: 'PENDING_CUSTOMER',
                  quotedAmount: 22000,
                ),
              ),
            ),
            isBypassingDeliveryFee: true,
            onBypassDeliveryFee: () async {},
          ),
        ),
      ),
    );

    final button = tester.widget<BangSwipeActionButton>(
      find.byType(BangSwipeActionButton),
    );
    expect(button.isLoading, isTrue);
    expect(find.text('Memproses bypass...'), findsOneWidget);
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

  testWidgets('shopping pricing does not duplicate equal transport income', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              deliveryFee: 19000,
              fee: 19000,
              shoppingPricing: const DriverShoppingPricingModel(
                subtotal: 14000,
                deliveryFee: 19000,
                serviceFee: 0,
                totalPrice: 33000,
                cancellationPenalty: 0,
                recalculationVersion: 1,
                hasPendingManualPrices: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ongkir aktif'), findsOneWidget);
    expect(find.text('Pendapatan transport'), findsNothing);
    expect(find.text('Fee Driver'), findsNothing);
    expect(find.text('Total pembayaran customer'), findsOneWidget);
  });

  testWidgets('approved shopping all-in pricing renders one transport line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderPricingCard(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              deliveryFee: 26000,
              fee: 26000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                amount: AmountNegotiationModel(status: 'APPROVED'),
                pricingScope: 'SHOPPING_TOTAL_TRANSPORT',
                activePricingScope: 'SHOPPING_TOTAL_TRANSPORT',
              ),
              shoppingPricing: const DriverShoppingPricingModel(
                subtotal: 50000,
                deliveryFee: 26000,
                serviceFee: 0,
                totalPrice: 76000,
                cancellationPenalty: 0,
                failedTripCompensation: 10000,
                recalculationVersion: 2,
                hasPendingManualPrices: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Total ongkir Nitip'), findsOneWidget);
    expect(find.text('Ongkir aktif'), findsNothing);
    expect(find.text('Kompensasi perjalanan gagal (50%)'), findsNothing);
    expect(find.text('Pendapatan transport'), findsNothing);
  });
}

DriverOrderModel _order({
  double? deliveryFee,
  int fee = 9000,
  String serviceTypeCode = ServiceTypeCodes.ride,
  DriverShoppingPricingModel? shoppingPricing,
  DeliveryFeeNegotiationModel? deliveryFeeNegotiation,
}) {
  return DriverOrderModel(
    id: '99',
    customerName: 'Customer',
    serviceTypeCode: serviceTypeCode,
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: fee,
    deliveryFee: deliveryFee,
    totalPrice: 9000,
    itemCount: 1,
    statusCode: OrderStatusCodes.driverAssigned,
    paymentMethod: 'COD',
    paymentStatus: 'unpaid',
    deliveryFeeNegotiation: deliveryFeeNegotiation,
    shoppingPricing: shoppingPricing,
  );
}
