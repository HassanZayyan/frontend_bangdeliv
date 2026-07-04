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
  testWidgets('driver action card disables actions while processing', (
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
            isProcessing: true,
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    final actionButtons = tester.widgetList<FilledButton>(
      find.byType(FilledButton),
    );
    expect(actionButtons, hasLength(2));
    expect(actionButtons.every((button) => button.onPressed == null), isTrue);
    expect(find.byIcon(Icons.touch_app_rounded), findsNothing);

    final actionTitle = tester.widget<Text>(find.text('Aksi Driver'));
    expect(actionTitle.style?.fontSize, 16);
    expect(actionTitle.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('shopping item request title is text only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverShoppingItemChangeRequestCard(
            request: const ShoppingItemChangeRequestModel(
              status: 'PENDING_DRIVER',
              triggerType: 'CUSTOMER_ITEM_CHANGE_REQUESTED',
              action: 'ADD',
              canDriverRespond: true,
              items: [
                ShoppingItemChangeRequestItemModel(name: 'Es teh', quantity: 1),
              ],
            ),
            isOrderBusy: false,
            isApproving: false,
            isRejecting: false,
            onRespond: (_) async => null,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.pending_actions_outlined), findsNothing);

    final requestTitle = tester.widget<Text>(
      find.text('Request Item Customer'),
    );
    expect(requestTitle.style?.fontSize, 16);
    expect(requestTitle.style?.fontWeight, FontWeight.w800);
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

  testWidgets('shopping checkout card keeps receipt upload separate', (
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
      canEditAvailability: false,
      canUploadReceipt: true,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Upload Foto Struk Opsional'), findsOneWidget);
    expect(find.text('Simpan Checkout Nitip'), findsNothing);

    final checkoutTitle = tester.widget<Text>(find.text('Checkout Belanja'));
    expect(checkoutTitle.style?.fontSize, 16);
    expect(checkoutTitle.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('saved shopping checkout is not rendered inside checkout card', (
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
        shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
          canDriverUploadReceipt: true,
          hasCheckoutSaved: true,
        ),
      ),
      canUploadReceipt: true,
    );

    expect(find.text('Checkout Nitip Tersimpan'), findsNothing);
    expect(find.text('Simpan Checkout Nitip'), findsNothing);
    expect(find.text('Upload Foto Struk Opsional'), findsOneWidget);
  });

  testWidgets('shopping sticky bar saves checkout before finish action', (
    tester,
  ) async {
    var saveTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              statusCode: OrderStatusCodes.arrivedMerchant,
              availableActions: const [
                DriverOrderActionModel(
                  actionCode: 'CONFIRM_PICKED_UP',
                  label: 'Belanja Selesai',
                  targetStatusCode: OrderStatusCodes.pickedUp,
                  blocked: true,
                  blockedReason: 'Checkout Nitip belum disimpan.',
                ),
              ],
              shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
                canDriverUploadReceipt: true,
              ),
            ),
            isProcessing: false,
            onSaveShoppingCheckout: () async {
              saveTapped = true;
            },
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Simpan Checkout Nitip'), findsOneWidget);
    expect(find.text('Belanja Selesai'), findsNothing);

    await tester.tap(find.text('Simpan Checkout Nitip'));
    await tester.pump();

    expect(saveTapped, isTrue);
  });

  testWidgets('shopping sticky bar shows finish after checkout saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              statusCode: OrderStatusCodes.arrivedMerchant,
              availableActions: const [
                DriverOrderActionModel(
                  actionCode: 'CONFIRM_PICKED_UP',
                  label: 'Belanja Selesai',
                  targetStatusCode: OrderStatusCodes.pickedUp,
                ),
              ],
              shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
                canDriverUploadReceipt: true,
                hasCheckoutSaved: true,
              ),
            ),
            isProcessing: false,
            onSaveShoppingCheckout: () async {},
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Simpan Checkout Nitip'), findsNothing);
    expect(find.text('Belanja Selesai'), findsOneWidget);
  });

  testWidgets('shopping closure fee hint only appears for three stops', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              shoppingStops: [_shoppingStop(1), _shoppingStop(2)],
              shoppingPricing: _shoppingPricing(),
            ),
            isProcessing: false,
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Tempat tutup/order batal'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              shoppingStops: [
                _shoppingStop(1),
                _shoppingStop(2),
                _shoppingStop(3),
              ],
              shoppingPricing: _shoppingPricing(),
            ),
            isProcessing: false,
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Tempat tutup/order batal 0/3'), findsOneWidget);
  });

  test('shopping sticky visibility follows actual visible content', () {
    final singleStopOrder = _order(
      serviceTypeCode: ServiceTypeCodes.shopping,
      shoppingStops: [_shoppingStop(1)],
      shoppingPricing: _shoppingPricing(),
      shoppingNegotiation: _shoppingCheckoutBlocked(),
    );
    final threeStopOrder = _order(
      serviceTypeCode: ServiceTypeCodes.shopping,
      shoppingStops: [_shoppingStop(1), _shoppingStop(2), _shoppingStop(3)],
      shoppingPricing: _shoppingPricing(),
      shoppingNegotiation: _shoppingCheckoutBlocked(),
    );

    expect(hasDriverOrderStickyActionBarContent(singleStopOrder), isFalse);
    expect(hasDriverOrderStickyActionBarContent(threeStopOrder), isTrue);
  });

  testWidgets('shopping merchant closed spinner is scoped to selected stop', (
    tester,
  ) async {
    const firstStop = DriverShoppingStopModel(
      pickupLocationId: 7,
      sequenceNo: 1,
      fulfillmentStatus: 'PENDING',
      merchant: DriverShoppingMerchantModel(
        id: 1,
        name: 'Kedai Tinari',
        merchantType: 'restaurant',
        address: 'Jl. Merchant 1',
      ),
      items: <DriverShoppingItemModel>[],
    );
    const secondStop = DriverShoppingStopModel(
      pickupLocationId: 8,
      sequenceNo: 2,
      fulfillmentStatus: 'PENDING',
      merchant: DriverShoppingMerchantModel(
        id: 2,
        name: 'Burjo SS',
        merchantType: 'restaurant',
        address: 'Jl. Merchant 2',
      ),
      items: <DriverShoppingItemModel>[],
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingStops: const [firstStop, secondStop],
      ),
      isOrderBusy: true,
      closingMerchantIds: const {8},
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tempat tutup'), findsOneWidget);
  });

  testWidgets('shopping merchant action buttons fit narrow card width', (
    tester,
  ) async {
    const stop = DriverShoppingStopModel(
      pickupLocationId: 7,
      sequenceNo: 1,
      fulfillmentStatus: 'PENDING',
      merchant: DriverShoppingMerchantModel(
        id: 1,
        name: 'Kedai Tinari',
        merchantType: 'restaurant',
        address: 'Jl. Merchant',
      ),
      items: <DriverShoppingItemModel>[],
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingStops: const [stop],
      ),
      cardWidth: 328,
    );

    expect(find.text('Tempat tutup'), findsOneWidget);
    expect(find.text('Tempat buka'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending delivery fee revision disables merchant actions', (
    tester,
  ) async {
    const stop = DriverShoppingStopModel(
      pickupLocationId: 7,
      sequenceNo: 1,
      fulfillmentStatus: 'PENDING',
      merchant: DriverShoppingMerchantModel(
        id: 1,
        name: 'Kedai Tinari',
        merchantType: 'restaurant',
        address: 'Jl. Merchant',
      ),
      items: <DriverShoppingItemModel>[],
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingStops: const [stop],
      ),
      isDeliveryFeeRevisionPending: true,
    );

    expect(
      find.text('Revisi ongkir belum disetujui customer.'),
      findsOneWidget,
    );

    final closeButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Tempat tutup'),
    );
    final openButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tempat buka'),
    );

    expect(closeButton.onPressed, isNull);
    expect(openButton.onPressed, isNull);
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
  bool canEditAvailability = false,
  bool canUploadReceipt = false,
  bool isDeliveryFeeRevisionPending = false,
  Set<int> closingMerchantIds = const <int>{},
  double? cardWidth,
}) async {
  final card = DriverShoppingItemsCard(
    order: order,
    isOrderBusy: isOrderBusy,
    isSavingItems: (_) => false,
    canEditAvailability: canEditAvailability,
    canUploadReceipt: canUploadReceipt,
    isSubmittingQuote: (_) => false,
    isBypassingPrice: (_) => false,
    isMarkingMerchantOpen: (_) => false,
    isClosingMerchant: (pickupLocationId) =>
        closingMerchantIds.contains(pickupLocationId),
    isDeliveryFeeRevisionPending: isDeliveryFeeRevisionPending,
    onUploadReceipt: (_) async => null,
    onSubmitQuote: ({required amount, pickupLocationId}) async => null,
    onBypassPrice: ({required pickupLocationId}) async => null,
    onMarkMerchantOpen: ({required pickupLocationId}) async => null,
    onMarkMerchantClosed:
        ({required pickupLocationId, required reason}) async => null,
    onSaveItems: (_, _) async => null,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: cardWidth == null
            ? card
            : Center(
                child: SizedBox(width: cardWidth, child: card),
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

ShoppingNegotiationModel _shoppingCheckoutBlocked() {
  return const ShoppingNegotiationModel(
    amount: AmountNegotiationModel(status: 'APPROVED'),
    checkoutAllowed: false,
  );
}

DriverOrderModel _order({
  String serviceTypeCode = ServiceTypeCodes.ride,
  String statusCode = OrderStatusCodes.driverAssigned,
  List<DriverOrderActionModel> availableActions =
      const <DriverOrderActionModel>[],
  List<DriverShoppingItemModel> shoppingItems =
      const <DriverShoppingItemModel>[],
  List<DriverShoppingStopModel> shoppingStops =
      const <DriverShoppingStopModel>[],
  DriverShoppingPricingModel? shoppingPricing,
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
    statusCode: statusCode,
    paymentMethod: 'COD',
    paymentStatus: 'unpaid',
    availableActions: availableActions,
    shoppingItems: shoppingItems,
    shoppingStops: shoppingStops,
    shoppingPricing: shoppingPricing,
    shoppingCapabilities: shoppingCapabilities,
    shoppingNegotiation:
        shoppingNegotiation ??
        const ShoppingNegotiationModel(
          amount: AmountNegotiationModel(status: 'APPROVED'),
          checkoutAllowed: true,
        ),
  );
}

DriverShoppingStopModel _shoppingStop(int sequenceNo) {
  return DriverShoppingStopModel(
    pickupLocationId: sequenceNo,
    sequenceNo: sequenceNo,
    fulfillmentStatus: 'PENDING',
    merchant: DriverShoppingMerchantModel(
      id: sequenceNo,
      name: 'Merchant',
      merchantType: 'restaurant',
      address: 'Jl. Merchant',
    ),
    items: <DriverShoppingItemModel>[],
  );
}

DriverShoppingPricingModel _shoppingPricing() {
  return const DriverShoppingPricingModel(
    subtotal: 0,
    deliveryFee: 5000,
    serviceFee: 0,
    totalPrice: 5000,
    cancellationPenalty: 0,
    recalculationVersion: 0,
    hasPendingManualPrices: false,
    failedAttemptCount: 0,
    failedAttemptThreshold: 3,
  );
}
