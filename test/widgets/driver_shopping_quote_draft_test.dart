import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_shopping_widgets.dart';
import 'package:frontend_bangdeliv/models/amount_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/shopping_negotiation_model.dart';

void main() {
  testWidgets('merchant quote panel restores its pickup-specific draft', (
    tester,
  ) async {
    final drafts = <int, String>{1: '12000', 2: '23000'};

    Widget buildPanel(int pickupLocationId) {
      return MaterialApp(
        home: Scaffold(
          body: DriverShoppingMerchantQuotePanel(
            key: ValueKey('quote-$pickupLocationId'),
            pickupLocationId: pickupLocationId,
            quote: const ShoppingMerchantQuoteModel(
              amount: AmountNegotiationModel(
                status: 'NEEDS_REQUOTE',
                canDriverSubmitQuote: true,
              ),
            ),
            isOrderBusy: false,
            isSubmittingQuote: false,
            isBypassingPrice: false,
            initialDraft: drafts[pickupLocationId] ?? '',
            onDraftChanged: (value) => drafts[pickupLocationId] = value,
            onSubmitQuote: ({required amount, pickupLocationId}) async => null,
            onBypassApproval: ({required pickupLocationId}) async => null,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildPanel(1));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '12.000',
    );

    await tester.enterText(find.byType(TextField), '15000');
    expect(drafts[1], '15.000');

    await tester.pumpWidget(buildPanel(2));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '23.000',
    );

    await tester.pumpWidget(buildPanel(1));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '15.000',
    );
  });
}
