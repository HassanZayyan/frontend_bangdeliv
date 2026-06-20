import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_action_widgets.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_proof_widgets.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_shopping_widgets.dart';
import 'package:frontend_bangdeliv/models/amount_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/shopping_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/shopping_order_capability_model.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  testWidgets('driver action card only shows spinner on selected action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderActionCard(
            order: _order(
              availableActions: const [
                DriverOrderActionModel(
                  actionCode: 'COLLECT_COD',
                  label: 'Catat COD',
                ),
                DriverOrderActionModel(
                  actionCode: 'COMPLETE',
                  label: 'Selesaikan Order',
                  targetStatusCode: OrderStatusCodes.completed,
                ),
              ],
            ),
            isOrderBusy: true,
            isReportPickupFailedProcessing: false,
            isActionProcessing: (action) => action.actionCode == 'COMPLETE',
            onReportPickupFailed: null,
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Catat COD'), findsOneWidget);
    final codButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Catat COD'),
    );
    expect(codButton.onPressed, isNull);
  });

  testWidgets('proof checklist only shows spinner for selected proof type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderProofChecklistCard(
            order: _order(serviceTypeCode: ServiceTypeCodes.courier),
            isOrderBusy: true,
            isProofUploading: (type) => type == 'pickup',
            onUploadProof:
                ({
                  required String type,
                  required XFile photo,
                  String? note,
                  int? pickupLocationId,
                }) async => null,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Diterima'), findsOneWidget);
  });

  testWidgets('shopping checkout loading does not spin receipt upload button', (
    tester,
  ) async {
    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [
          DriverShoppingItemModel(
            id: 1,
            itemSource: 'MANUAL',
            name: 'Mie ayam',
            quantity: 1,
            unitPrice: 12000,
            subtotal: 12000,
            isAvailable: true,
          ),
        ],
      ),
      isOrderBusy: true,
      isSavingCheckout: true,
      canEditAvailability: false,
      canUploadReceipt: true,
      canCheckout: true,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Upload Foto Struk Opsional'), findsOneWidget);
  });

  testWidgets(
    'shopping merchant quote card is hidden while item decision is pending',
    (tester) async {
      const unavailableItem = DriverShoppingItemModel(
        id: 10,
        pickupLocationId: 7,
        itemSource: 'MANUAL',
        name: 'es jeruk',
        quantity: 1,
        unitPrice: 0,
        subtotal: 0,
        isAvailable: false,
      );

      await _pumpShoppingItemsCard(
        tester,
        order: _order(
          serviceTypeCode: ServiceTypeCodes.shopping,
          shoppingItems: const [unavailableItem],
          shoppingStops: const [
            DriverShoppingStopModel(
              pickupLocationId: 7,
              sequenceNo: 1,
              fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
              availabilityConfirmed: true,
              merchant: DriverShoppingMerchantModel(
                id: 1,
                name: 'Kedai Tinari',
                merchantType: 'restaurant',
                address: 'Jl. Merchant',
              ),
              items: [unavailableItem],
            ),
          ],
          shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
            canDriverUpdateItemAvailability: true,
            hasPendingItemChangeRequest: true,
          ),
          shoppingNegotiation: _merchantRequote(pickupLocationId: 7),
        ),
        canEditAvailability: true,
      );

      expect(find.text('Menunggu keputusan item'), findsOneWidget);
      expect(find.text('Harga Nitip'), findsNothing);
      expect(find.text('Perubahan item perlu harga baru.'), findsNothing);
    },
  );

  testWidgets(
    'shopping merchant quote card is shown after all items are available',
    (tester) async {
      const availableItem = DriverShoppingItemModel(
        id: 10,
        pickupLocationId: 7,
        itemSource: 'MANUAL',
        name: 'es jeruk',
        quantity: 1,
        unitPrice: 0,
        subtotal: 0,
        isAvailable: true,
      );

      await _pumpShoppingItemsCard(
        tester,
        order: _order(
          serviceTypeCode: ServiceTypeCodes.shopping,
          shoppingItems: const [availableItem],
          shoppingStops: const [
            DriverShoppingStopModel(
              pickupLocationId: 7,
              sequenceNo: 1,
              fulfillmentStatus: 'ITEMS_CONFIRMED',
              availabilityConfirmed: true,
              merchant: DriverShoppingMerchantModel(
                id: 1,
                name: 'Kedai Tinari',
                merchantType: 'restaurant',
                address: 'Jl. Merchant',
              ),
              items: [availableItem],
            ),
          ],
          shoppingNegotiation: _merchantRequote(pickupLocationId: 7),
        ),
      );

      expect(find.text('Harga Nitip'), findsOneWidget);
      expect(find.text('Perubahan item perlu harga baru.'), findsOneWidget);
    },
  );

  testWidgets('approved shopping merchant locks item availability controls', (
    tester,
  ) async {
    const approvedItem = DriverShoppingItemModel(
      id: 10,
      pickupLocationId: 7,
      itemSource: 'MANUAL',
      name: 'ramen mala',
      quantity: 1,
      unitPrice: 0,
      subtotal: 0,
      isAvailable: true,
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [approvedItem],
        shoppingStops: const [
          DriverShoppingStopModel(
            pickupLocationId: 7,
            sequenceNo: 1,
            fulfillmentStatus: 'PRICE_APPROVED',
            availabilityConfirmed: true,
            merchant: DriverShoppingMerchantModel(
              id: 1,
              name: 'Kedai Tinari',
              merchantType: 'restaurant',
              address: 'Jl. Merchant',
            ),
            items: [approvedItem],
          ),
        ],
        shoppingNegotiation: _merchantApprovedQuote(pickupLocationId: 7),
      ),
      canEditAvailability: true,
    );

    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);

    final itemCheckbox = tester.widget<Checkbox>(checkboxFinder);
    expect(itemCheckbox.value, isTrue);
    expect(itemCheckbox.onChanged, isNull);
    expect(find.text('Simpan Ketersediaan Item'), findsNothing);
  });
}

Future<void> _pumpShoppingItemsCard(
  WidgetTester tester, {
  required DriverOrderModel order,
  bool isOrderBusy = false,
  bool isSavingCheckout = false,
  bool canEditAvailability = false,
  bool canUploadReceipt = false,
  bool canCheckout = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DriverShoppingItemsCard(
          order: order,
          isOrderBusy: isOrderBusy,
          isSavingCheckout: isSavingCheckout,
          isSavingItems: (_) => false,
          canEditAvailability: canEditAvailability,
          canUploadReceipt: canUploadReceipt,
          canCheckout: canCheckout,
          isSubmittingQuote: (_) => false,
          isBypassingPrice: (_) => false,
          isMarkingMerchantOpen: (_) => false,
          isClosingMerchant: (_) => false,
          onUploadReceipt: (_) async => null,
          onSubmitQuote: ({required amount, pickupLocationId}) async => null,
          onBypassPrice: ({required pickupLocationId}) async => null,
          onMarkMerchantOpen: ({required pickupLocationId}) async => null,
          onMarkMerchantClosed:
              ({required pickupLocationId, required reason}) async => null,
          onSaveItems: (_, _) async => null,
          onSave: (_, _) async => null,
        ),
      ),
    ),
  );
}

ShoppingNegotiationModel _merchantRequote({required int pickupLocationId}) {
  return ShoppingNegotiationModel(
    amount: const AmountNegotiationModel(status: 'NEEDS_REQUOTE'),
    merchantQuotes: [
      ShoppingMerchantQuoteModel(
        pickupLocationId: pickupLocationId,
        merchantName: 'Kedai Tinari',
        amount: const AmountNegotiationModel(
          status: 'NEEDS_REQUOTE',
          canDriverSubmitQuote: true,
        ),
      ),
    ],
  );
}

ShoppingNegotiationModel _merchantApprovedQuote({
  required int pickupLocationId,
}) {
  return ShoppingNegotiationModel(
    amount: const AmountNegotiationModel(status: 'APPROVED'),
    merchantQuotes: [
      ShoppingMerchantQuoteModel(
        pickupLocationId: pickupLocationId,
        merchantName: 'Kedai Tinari',
        amount: const AmountNegotiationModel(
          status: 'APPROVED',
          approvedAmount: 30000,
        ),
      ),
    ],
    checkoutAllowed: true,
  );
}

DriverOrderModel _order({
  String serviceTypeCode = ServiceTypeCodes.ride,
  List<DriverOrderActionModel> availableActions =
      const <DriverOrderActionModel>[],
  List<DriverShoppingItemModel> shoppingItems =
      const <DriverShoppingItemModel>[],
  List<DriverShoppingStopModel> shoppingStops =
      const <DriverShoppingStopModel>[],
  ShoppingOrderCapabilitiesModel shoppingCapabilities =
      const ShoppingOrderCapabilitiesModel(canDriverUploadReceipt: true),
  ShoppingNegotiationModel? shoppingNegotiation,
}) {
  return DriverOrderModel(
    id: '99',
    customerName: 'Customer',
    serviceTypeCode: serviceTypeCode,
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 9000,
    totalPrice: 9000,
    itemCount: 1,
    statusCode: OrderStatusCodes.driverAssigned,
    paymentMethod: 'COD',
    paymentStatus: 'unpaid',
    availableActions: availableActions,
    shoppingItems: shoppingItems,
    shoppingStops: shoppingStops,
    shoppingCapabilities: shoppingCapabilities,
    shoppingNegotiation:
        shoppingNegotiation ??
        const ShoppingNegotiationModel(
          amount: AmountNegotiationModel(status: 'APPROVED'),
          checkoutAllowed: true,
        ),
  );
}
