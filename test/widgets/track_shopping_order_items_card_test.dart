import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/data/repositories/customer_order_repository.dart';
import 'package:frontend_bangdeliv/features/tracking/presentation/widgets/track_order_widgets.dart';
import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/models/shopping_order_capability_model.dart';
import 'package:frontend_bangdeliv/services/customer_order_api_service.dart';

void main() {
  testWidgets('unavailable item actions request remove or cancel merchant', (
    tester,
  ) async {
    final repository = _FakeCustomerOrderRepository();

    await _pumpCard(tester, repository);

    expect(find.text('Lanjut tanpa ini'), findsOneWidget);
    expect(find.text('Batal merchant'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Lanjut tanpa ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut tanpa ini'));
    await tester.pumpAndSettle();

    expect(repository.changeCalls, 1);
    expect(repository.lastAction, 'REMOVE');
    expect(repository.lastItemId, 12);
    expect(repository.lastTargetPickupLocationId, 77);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Batal merchant'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Batal merchant'));
    await tester.pumpAndSettle();

    expect(repository.changeCalls, 2);
    expect(repository.lastAction, 'CANCEL_MERCHANT');
    expect(repository.lastItemId, isNull);
    expect(repository.lastTargetPickupLocationId, 77);
  });

  testWidgets('only unavailable item hides continue without action', (
    tester,
  ) async {
    final repository = _FakeCustomerOrderRepository();

    await _pumpCard(
      tester,
      repository,
      detail: _shoppingDetail(
        includeAvailableItem: false,
        hasExplicitUnavailableItemActions: true,
        canContinueWithoutUnavailableItem: false,
      ),
    );

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Lanjut tanpa ini'), findsNothing);
    expect(find.text('Batal merchant'), findsOneWidget);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  _FakeCustomerOrderRepository repository, {
  CustomerOrderDetailModel? detail,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerOrderRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrackShoppingOrderItemsCard(
              detail: detail ?? _shoppingDetail(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeCustomerOrderRepository implements CustomerOrderRepository {
  int changeCalls = 0;
  String? lastAction;
  int? lastItemId;
  int? lastTargetPickupLocationId;

  @override
  Future<CustomerOrderDetailModel> requestShoppingItemChange(
    int orderId, {
    required String action,
    String? requestKind,
    List<ShoppingItemDraftPayload> items = const <ShoppingItemDraftPayload>[],
    int? itemId,
    int? targetPickupLocationId,
    String? note,
  }) async {
    changeCalls += 1;
    lastAction = action;
    lastItemId = itemId;
    lastTargetPickupLocationId = targetPickupLocationId;
    return _shoppingDetail();
  }

  @override
  Future<CustomerOrderDetailModel> addShoppingItems(
    int orderId,
    List<ShoppingItemDraftPayload> items,
  ) => throw UnimplementedError();

  @override
  Future<void> cancelOrder(int orderId, {required String reason}) =>
      throw UnimplementedError();

  @override
  Future<CustomerOrderDetailModel> fetchOrderDetail(int orderId) =>
      throw UnimplementedError();

  @override
  Future<List<CustomerOrderSummaryModel>> fetchOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) => throw UnimplementedError();

  @override
  Future<CustomerOrderDetailModel> removeShoppingItem(
    int orderId,
    int itemId,
  ) => throw UnimplementedError();

  @override
  Future<CustomerOrderDetailModel> respondDeliveryFeeOverride(
    int orderId, {
    required String action,
    double? counterAmount,
  }) => throw UnimplementedError();

  @override
  Future<CustomerOrderDetailModel> respondShoppingPriceQuote(
    int orderId, {
    required String action,
    int? pickupLocationId,
  }) => throw UnimplementedError();

  @override
  Future<List<ShoppingMenuOption>> searchMerchantMenus(
    int merchantId,
    String query,
  ) => throw UnimplementedError();

  @override
  Future<List<ShoppingMerchantOption>> searchShoppingMerchants(
    String query, {
    String? merchantType,
  }) => throw UnimplementedError();

  @override
  Future<CustomerOrderDetailModel> updateShoppingItem(
    int orderId,
    int itemId, {
    required String name,
    required int quantity,
    String? notes,
  }) => throw UnimplementedError();

  @override
  Future<CustomerOrderDetailModel> uploadTransferEvidence(
    int orderId, {
    required XFile photo,
    String? note,
  }) => throw UnimplementedError();
}

CustomerOrderDetailModel _shoppingDetail({
  bool includeAvailableItem = true,
  bool hasExplicitUnavailableItemActions = false,
  bool canContinueWithoutUnavailableItem = true,
}) {
  const unavailableItem = CustomerShoppingItemModel(
    id: 12,
    pickupLocationId: 77,
    itemSource: 'MANUAL',
    name: 'es jeruk',
    quantity: 1,
    unitPrice: 0,
    subtotal: 0,
    isAvailable: false,
  );
  const availableItem = CustomerShoppingItemModel(
    id: 13,
    pickupLocationId: 77,
    itemSource: 'MANUAL',
    name: 'ramen mala',
    quantity: 1,
    unitPrice: 0,
    subtotal: 0,
    isAvailable: true,
  );
  final stopItems = includeAvailableItem
      ? const [availableItem, unavailableItem]
      : const [unavailableItem];
  final shoppingItems = includeAvailableItem
      ? const [unavailableItem, availableItem]
      : const [unavailableItem];

  return CustomerOrderDetailModel(
    summary: CustomerOrderSummaryModel(
      id: 1,
      orderNumber: 'BD-TRACK-1',
      serviceTypeCode: 'SHOPPING',
      serviceTypeLabel: 'Nitip',
      restaurantName: 'Kedai Tinari',
      itemsSummary: '1x ramen mala, 1x es jeruk',
      totalAmount: 9000,
      statusCode: 'ARRIVED_MERCHANT',
      statusLabel: 'Driver di merchant',
      isTerminalStatus: false,
      createdAt: DateTime(2026, 6, 18),
      estimatedDelivery: null,
      deliveryAddress: 'Jl. Customer',
      paymentStatus: 'unpaid',
      paymentMethod: 'COD',
    ),
    paymentStatus: 'PENDING',
    paymentMethod: 'COD',
    driverName: 'Driver',
    driverVehicleType: null,
    driverVehicleBrand: null,
    driverVehicleModel: null,
    driverVehiclePlate: null,
    pickupLatitude: -7.001,
    pickupLongitude: 110.401,
    dropoffLatitude: -7.003,
    dropoffLongitude: 110.403,
    driverLatitude: null,
    driverLongitude: null,
    driverLocationUpdatedAt: null,
    deliveryDistanceText: '2 km',
    timeline: const <OrderStatusSnapshot>[],
    shoppingItems: shoppingItems,
    shoppingStops: [
      CustomerShoppingStopModel(
        pickupLocationId: 77,
        sequenceNo: 1,
        fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
        hasExplicitUnavailableItemActions: hasExplicitUnavailableItemActions,
        canEditUnavailableItems: true,
        canContinueWithoutUnavailableItem: canContinueWithoutUnavailableItem,
        canCancelUnavailableMerchant: true,
        merchant: CustomerShoppingMerchantModel(
          id: 10,
          name: 'Kedai Tinari',
          merchantType: 'restaurant',
          address: 'Jl. Sawunggaling III',
        ),
        items: stopItems,
      ),
    ],
    shoppingPricing: const CustomerShoppingPricingModel(
      subtotal: 0,
      deliveryFee: 9000,
      serviceFee: 0,
      totalPrice: 9000,
      cancellationPenalty: 0,
    ),
    shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
      isExplicit: true,
      canCustomerEditUnavailableItems: true,
    ),
  );
}
