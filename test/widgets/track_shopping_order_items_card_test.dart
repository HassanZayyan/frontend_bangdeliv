import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/data/repositories/customer_order_repository.dart';
import 'package:frontend_bangdeliv/features/tracking/presentation/widgets/track_order_widgets.dart';
import 'package:frontend_bangdeliv/models/amount_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/models/delivery_fee_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/shopping_order_capability_model.dart';
import 'package:frontend_bangdeliv/models/shopping_negotiation_model.dart';
import 'package:frontend_bangdeliv/services/customer_order_api_service.dart';

void main() {
  testWidgets('unavailable item actions request remove or cancel tempat', (
    tester,
  ) async {
    final repository = _FakeCustomerOrderRepository();

    await _pumpCard(tester, repository);

    expect(find.text('Lanjut tanpa ini'), findsOneWidget);
    expect(find.text('Batal tempat'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Lanjut tanpa ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lanjut tanpa ini'));
    await tester.pumpAndSettle();

    expect(repository.changeCalls, 1);
    expect(repository.lastAction, 'REMOVE');
    expect(repository.lastItemId, isNull);
    expect(repository.lastItemIds, [12]);
    expect(repository.lastTargetPickupLocationId, 77);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Batal tempat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Batal tempat'));
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

    expect(find.text('Edit'), findsNothing);
    expect(find.text('Ganti item'), findsOneWidget);
    expect(find.text('Lanjut tanpa ini'), findsNothing);
    expect(find.text('Batal tempat'), findsOneWidget);
  });

  testWidgets('failed merchant tab keeps replace action before checkout', (
    tester,
  ) async {
    // Aksi ganti toko/resto kini hidup di TAB stop yang gagal (bukan Ringkasan),
    // maka dirender dalam mode per-tab (selectedPickupLocationId di-set).
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        shoppingStops: [_failedShoppingStop(77, 'Kedai Tinari')],
      ),
      selectedPickupLocationId: 77,
      showGlobalActions: false,
      showPricing: false,
    );

    expect(find.text('Kedai Tinari'), findsWidgets);
    expect(find.text('Tempat tutup/order batal'), findsWidgets);
    expect(find.text('Ganti toko/resto'), findsOneWidget);
  });

  testWidgets('closed stop tab shows only replace action, not item decisions', (
    tester,
  ) async {
    // Stop tutup (FAILED) yang itemnya juga tak tersedia: hanya boleh "Ganti
    // toko/resto" (satu kali) -- tanpa "Ganti item"/"Batal tempat", tanpa dobel.
    const failedWithUnavailable = CustomerShoppingStopModel(
      pickupLocationId: 90,
      sequenceNo: 2,
      fulfillmentStatus: 'FAILED',
      chainFailedAttemptCount: 1,
      orderFailedTripCount: 1,
      canReplaceMerchant: true,
      canEditUnavailableItems: true,
      canCancelUnavailableMerchant: true,
      hasExplicitUnavailableItemActions: true,
      merchant: CustomerShoppingMerchantModel(
        id: 90,
        name: 'Sate Ayam Cak Sabari',
        merchantType: 'restaurant',
        address: 'Jl. Sabari',
      ),
      items: [
        CustomerShoppingItemModel(
          id: 22,
          pickupLocationId: 90,
          itemSource: 'MANUAL',
          name: 'Sate Ayam + Lontong',
          quantity: 1,
          unitPrice: 0,
          subtotal: 0,
          isAvailable: false,
        ),
      ],
    );

    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        shoppingStops: const [failedWithUnavailable],
        canReplaceMerchant: true,
      ),
      selectedPickupLocationId: 90,
      showGlobalActions: false,
      showPricing: false,
    );

    expect(find.text('Ganti toko/resto'), findsOneWidget);
    expect(find.text('Ganti item'), findsNothing);
    expect(find.text('Batal tempat'), findsNothing);
  });

  testWidgets('failed merchant tab is not shown in the summary notice actions', (
    tester,
  ) async {
    // Di Ringkasan (summary) hanya ada notice ringkas -- tanpa tombol.
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        shoppingStops: [_failedShoppingStop(77, 'Kedai Tinari')],
      ),
    );

    expect(
      find.textContaining('Kedai Tinari - Tempat tutup/order batal'),
      findsOneWidget,
    );
    expect(find.text('Ganti toko/resto'), findsNothing);
  });

  testWidgets('checkout hides all failed merchant cards and keeps order info', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
          isExplicit: true,
          hasCheckoutSaved: true,
        ),
        shoppingStops: [
          _failedShoppingStop(77, 'Kedai Tinari'),
          _failedShoppingStop(78, 'Warung Sejahtera'),
        ],
      ),
    );

    expect(
      find.textContaining('Kedai Tinari - Tempat tutup/order batal'),
      findsNothing,
    );
    expect(
      find.textContaining('Warung Sejahtera - Tempat tutup/order batal'),
      findsNothing,
    );
    expect(find.text('Ganti toko/resto'), findsNothing);
    expect(find.textContaining('Item tidak tersedia:'), findsOneWidget);
    expect(find.text('Subtotal barang'), findsOneWidget);
    expect(find.text('Ongkir aktif'), findsOneWidget);
    expect(find.text('Total pembayaran customer'), findsOneWidget);
  });

  testWidgets('cancelled with fee hides failed merchant replacement cards', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        statusCode: 'CANCELLED_WITH_FEE',
        shoppingStops: [
          _failedShoppingStop(77, 'Kedai Tinari'),
          _failedShoppingStop(78, 'Warung Sejahtera'),
        ],
        shoppingPricing: const CustomerShoppingPricingModel(
          subtotal: 0,
          deliveryFee: 0,
          serviceFee: 50000,
          totalPrice: 50000,
          cancellationPenalty: 50000,
        ),
      ),
    );

    expect(find.textContaining('Tempat tutup/order batal'), findsNothing);
    expect(find.text('Ganti toko/resto'), findsNothing);
    expect(find.text('Fee pembatalan'), findsOneWidget);
    expect(find.text('Total pembayaran customer'), findsOneWidget);
  });

  testWidgets('completed order hides stale failed merchant replacement cards', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        statusCode: 'COMPLETED',
        shoppingStops: [
          _failedShoppingStop(77, 'Kedai Tinari'),
          _failedShoppingStop(78, 'Warung Sejahtera'),
        ],
      ),
    );

    expect(find.textContaining('Tempat tutup/order batal'), findsNothing);
    expect(find.text('Ganti toko/resto'), findsNothing);
    expect(find.textContaining('Item tidak tersedia:'), findsOneWidget);
    expect(find.text('Total pembayaran customer'), findsOneWidget);
  });

  testWidgets('legacy completed cancellation uses cancellation fee outcome', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        statusCode: 'COMPLETED',
        wasCancelledWithFee: true,
        shoppingPricing: const CustomerShoppingPricingModel(
          subtotal: 0,
          deliveryFee: 0,
          serviceFee: 65000,
          totalPrice: 65000,
          cancellationPenalty: 65000,
        ),
      ),
    );

    expect(find.text('Fee pembatalan'), findsOneWidget);
    expect(find.text('Biaya layanan'), findsNothing);
  });

  testWidgets('multiple unavailable items can be selected in one decision', (
    tester,
  ) async {
    final repository = _FakeCustomerOrderRepository();
    await _pumpCard(
      tester,
      repository,
      detail: _shoppingDetail(includeSecondUnavailableItem: true),
    );

    await tester.tap(find.text('Pilih item'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(
      const ValueKey('confirm-unavailable-item-selection'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('unavailable-item-choice-12')));
    await tester.tap(find.byKey(const ValueKey('unavailable-item-choice-14')));
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(repository.changeCalls, 1);
    expect(repository.lastAction, 'REMOVE');
    expect(repository.lastItemIds, [12, 14]);
  });

  testWidgets('four item decisions use a symmetric tonal grid', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(canReplaceMerchant: true),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('Edit'), findsNothing);
    expect(find.text('Ganti item'), findsOneWidget);
    expect(find.text('Ganti toko/resto'), findsOneWidget);
    expect(find.text('Lanjut tanpa ini'), findsOneWidget);
    expect(find.text('Batal tempat'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Ganti item'), findsWidgets);
    expect(find.bySemanticsLabel('Ganti toko/resto'), findsWidgets);
    expect(find.bySemanticsLabel('Lanjut tanpa ini'), findsWidgets);
    expect(find.bySemanticsLabel('Batal tempat'), findsWidgets);

    final replaceItems = find.byKey(
      const ValueKey('shopping-action-replace-items-77'),
    );
    final replaceMerchant = find.byKey(
      const ValueKey('shopping-action-replace-merchant-77'),
    );
    final continueAction = find.byKey(
      const ValueKey('shopping-action-continue-77'),
    );
    final cancelAction = find.byKey(
      const ValueKey('shopping-action-cancel-77'),
    );

    for (final finder in [
      replaceItems,
      replaceMerchant,
      continueAction,
      cancelAction,
    ]) {
      expect(finder, findsOneWidget);
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(52));
    }

    expect(
      tester.getTopLeft(replaceItems).dy,
      tester.getTopLeft(replaceMerchant).dy,
    );
    expect(
      tester.getTopLeft(continueAction).dy,
      tester.getTopLeft(cancelAction).dy,
    );
    expect(tester.getSize(replaceItems), tester.getSize(replaceMerchant));
    expect(tester.getSize(continueAction), tester.getSize(cancelAction));

    Color? backgroundColor(Finder finder) => tester
        .widget<OutlinedButton>(finder)
        .style
        ?.backgroundColor
        ?.resolve(const <WidgetState>{});
    Color? foregroundColor(Finder finder) => tester
        .widget<OutlinedButton>(finder)
        .style
        ?.foregroundColor
        ?.resolve(const <WidgetState>{});
    Color? borderColor(Finder finder) => tester
        .widget<OutlinedButton>(finder)
        .style
        ?.side
        ?.resolve(const <WidgetState>{})
        ?.color;

    expect(backgroundColor(replaceItems), AppColors.white);
    expect(backgroundColor(replaceMerchant), AppColors.white);
    expect(backgroundColor(continueAction), AppColors.white);
    expect(backgroundColor(cancelAction), AppColors.white);
    expect(foregroundColor(replaceItems), AppColors.primaryDark);
    expect(foregroundColor(replaceMerchant), AppColors.primaryDark);
    expect(foregroundColor(continueAction), AppColors.warningDark);
    expect(foregroundColor(cancelAction), AppColors.error);
    expect(borderColor(replaceItems), AppColors.primary);
    expect(borderColor(continueAction), AppColors.warning);
    expect(borderColor(cancelAction), AppColors.error);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('decision grid adapts to one and three available actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        includeAvailableItem: false,
        hasExplicitUnavailableItemActions: true,
        canContinueWithoutUnavailableItem: false,
        canCancelUnavailableMerchant: false,
      ),
    );

    expect(find.text('Ganti item'), findsOneWidget);
    expect(find.text('Ganti toko/resto'), findsNothing);
    expect(find.text('Lanjut tanpa ini'), findsNothing);
    expect(find.text('Batal tempat'), findsNothing);

    await _pumpCard(tester, _FakeCustomerOrderRepository());

    final replaceItems = find.byKey(
      const ValueKey('shopping-action-replace-items-77'),
    );
    final continueAction = find.byKey(
      const ValueKey('shopping-action-continue-77'),
    );
    final cancelAction = find.byKey(
      const ValueKey('shopping-action-cancel-77'),
    );

    expect(replaceItems, findsOneWidget);
    expect(continueAction, findsOneWidget);
    expect(cancelAction, findsOneWidget);
    expect(
      tester.getTopLeft(replaceItems).dy,
      tester.getTopLeft(continueAction).dy,
    );
    expect(
      tester.getSize(cancelAction).width,
      greaterThan(tester.getSize(replaceItems).width * 1.8),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('decision grid stacks when content width is under 280', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(260, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(canReplaceMerchant: true),
    );

    final actions = [
      find.byKey(const ValueKey('shopping-action-replace-items-77')),
      find.byKey(const ValueKey('shopping-action-replace-merchant-77')),
      find.byKey(const ValueKey('shopping-action-continue-77')),
      find.byKey(const ValueKey('shopping-action-cancel-77')),
    ];
    final leftPositions = actions
        .map((finder) => tester.getTopLeft(finder).dx)
        .toSet();
    final topPositions = actions
        .map((finder) => tester.getTopLeft(finder).dy)
        .toSet();

    expect(leftPositions, hasLength(1));
    expect(topPositions, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled with fee pricing uses cancellation fee label', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        statusCode: 'CANCELLED_WITH_FEE',
        shoppingPricing: const CustomerShoppingPricingModel(
          subtotal: 0,
          deliveryFee: 0,
          serviceFee: 9000,
          totalPrice: 9000,
          cancellationPenalty: 9000,
        ),
      ),
    );

    expect(find.text('Fee pembatalan'), findsOneWidget);
    expect(find.text('Biaya layanan'), findsNothing);
  });

  testWidgets('active pricing hides zero service fee', (tester) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        shoppingPricing: const CustomerShoppingPricingModel(
          subtotal: 75000,
          deliveryFee: 155000,
          serviceFee: 0,
          totalPrice: 230000,
          cancellationPenalty: 0,
        ),
      ),
    );

    expect(find.text('Biaya layanan'), findsNothing);
    // F = P: tidak ada lagi baris kompensasi terpisah.
    expect(find.text('Kompensasi perjalanan gagal (50%)'), findsNothing);
    expect(find.text('Total pembayaran customer'), findsOneWidget);
  });

  testWidgets('active pricing shows the single service fee', (tester) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        shoppingPricing: const CustomerShoppingPricingModel(
          subtotal: 75000,
          deliveryFee: 155000,
          serviceFee: 25000,
          totalPrice: 255000,
          cancellationPenalty: 0,
        ),
      ),
    );

    expect(find.text('Biaya layanan'), findsOneWidget);
    expect(find.text('Kompensasi perjalanan gagal (50%)'), findsNothing);
  });

  testWidgets('approved shopping all-in pricing renders one transport line', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
          amount: AmountNegotiationModel(status: 'APPROVED'),
          pricingScope: 'SHOPPING_TOTAL_TRANSPORT',
          activePricingScope: 'SHOPPING_TOTAL_TRANSPORT',
        ),
        shoppingPricing: const CustomerShoppingPricingModel(
          subtotal: 99000,
          deliveryFee: 26000,
          serviceFee: 0,
          totalPrice: 125000,
          cancellationPenalty: 0,
        ),
      ),
    );

    expect(find.text('Total ongkir Nitip'), findsOneWidget);
    expect(find.text('Ongkir aktif'), findsNothing);
    expect(find.text('Kompensasi perjalanan gagal (50%)'), findsNothing);
    expect(find.text('Total pembayaran customer'), findsOneWidget);
  });

  testWidgets('add merchant action is hidden after three active stops', (
    tester,
  ) async {
    const capabilities = ShoppingOrderCapabilitiesModel(
      isExplicit: true,
      canCustomerDirectEditItems: true,
      canCustomerAddShoppingMerchant: true,
    );

    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        statusCode: 'PENDING',
        shoppingCapabilities: capabilities,
        shoppingStops: _shoppingStops(2),
      ),
    );
    expect(find.text('Tambah'), findsOneWidget);

    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        statusCode: 'PENDING',
        shoppingCapabilities: capabilities,
        shoppingStops: _shoppingStops(3),
      ),
    );
    expect(find.text('Tambah'), findsNothing);
  });

  testWidgets('shopping price quote uses explicit decision labels', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(
        shoppingStops: _shoppingStops(1),
        shoppingNegotiation: _pendingShoppingQuote(pickupLocationId: 70),
      ),
    );

    expect(find.text('Konfirmasi harga barang'), findsOneWidget);
    expect(find.text('Harga dari driver'), findsOneWidget);
    expect(find.text('Rp 18.000'), findsOneWidget);
    expect(find.text('Setujui harga'), findsOneWidget);
    expect(find.text('Batalkan tempat'), findsOneWidget);
    expect(find.text('Iya'), findsNothing);
  });

  testWidgets('selected tempat renders only its own items', (tester) async {
    final stops = _shoppingStops(3);
    await _pumpCard(
      tester,
      _FakeCustomerOrderRepository(),
      detail: _shoppingDetail(shoppingStops: stops),
      selectedPickupLocationId: stops[1].pickupLocationId,
      showPricing: false,
      showGlobalActions: false,
    );

    expect(find.text('Merchant 2'), findsOneWidget);
    expect(find.textContaining('Item 2'), findsOneWidget);
    expect(find.text('Merchant 1'), findsNothing);
    expect(find.text('Item 3'), findsNothing);
    expect(find.text('Ongkir aktif'), findsNothing);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  _FakeCustomerOrderRepository repository, {
  CustomerOrderDetailModel? detail,
  int? selectedPickupLocationId,
  bool showPricing = true,
  bool showGlobalActions = true,
  TextScaler? textScaler,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        customerOrderRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TrackShoppingOrderItemsCard(
              detail: detail ?? _shoppingDetail(),
              selectedPickupLocationId: selectedPickupLocationId,
              showPricing: showPricing,
              showGlobalActions: showGlobalActions,
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
  List<int> lastItemIds = const <int>[];
  int? lastTargetPickupLocationId;

  @override
  Future<ShoppingMerchantReplacementPreview> previewShoppingMerchantReplacement(
    int orderId, {
    required int pickupLocationId,
    required int expectedVersion,
    int? merchantId,
    ShoppingMerchantPlacePayload? merchantPlace,
    required List<ShoppingItemDraftPayload> items,
  }) => throw UnimplementedError();

  @override
  Future<ShoppingMerchantReplacementOutcome> replaceShoppingMerchant(
    int orderId, {
    required int pickupLocationId,
    required int expectedVersion,
    required String idempotencyKey,
    int? merchantId,
    ShoppingMerchantPlacePayload? merchantPlace,
    required List<ShoppingItemDraftPayload> items,
  }) => throw UnimplementedError();

  @override
  Future<CustomerOrderDetailModel> requestShoppingItemChange(
    int orderId, {
    required String action,
    String? requestKind,
    List<ShoppingItemDraftPayload> items = const <ShoppingItemDraftPayload>[],
    int? itemId,
    List<int> itemIds = const <int>[],
    int? targetPickupLocationId,
    String? note,
  }) async {
    changeCalls += 1;
    lastAction = action;
    lastItemId = itemId;
    lastItemIds = itemIds;
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
    int perPage = 20,
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
  bool canReplaceMerchant = false,
  bool canCancelUnavailableMerchant = true,
  bool includeSecondUnavailableItem = false,
  String statusCode = 'ARRIVED_MERCHANT',
  bool wasCancelledWithFee = false,
  CustomerShoppingPricingModel? shoppingPricing,
  ShoppingOrderCapabilitiesModel? shoppingCapabilities,
  List<CustomerShoppingStopModel>? shoppingStops,
  ShoppingNegotiationModel? shoppingNegotiation,
  DeliveryFeeNegotiationModel? deliveryFeeNegotiation,
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
  const secondUnavailableItem = CustomerShoppingItemModel(
    id: 14,
    pickupLocationId: 77,
    itemSource: 'MANUAL',
    name: 'lemon tea',
    quantity: 1,
    unitPrice: 0,
    subtotal: 0,
    isAvailable: false,
  );
  final stopItems = includeAvailableItem
      ? [
          availableItem,
          unavailableItem,
          if (includeSecondUnavailableItem) secondUnavailableItem,
        ]
      : [
          unavailableItem,
          if (includeSecondUnavailableItem) secondUnavailableItem,
        ];
  final shoppingItems = includeAvailableItem
      ? [
          unavailableItem,
          if (includeSecondUnavailableItem) secondUnavailableItem,
          availableItem,
        ]
      : [
          unavailableItem,
          if (includeSecondUnavailableItem) secondUnavailableItem,
        ];

  return CustomerOrderDetailModel(
    summary: CustomerOrderSummaryModel(
      id: 1,
      orderNumber: 'BD-TRACK-1',
      serviceTypeCode: 'SHOPPING',
      serviceTypeLabel: 'Nitip',
      restaurantName: 'Kedai Tinari',
      itemsSummary: '1x ramen mala, 1x es jeruk',
      totalAmount: 9000,
      statusCode: statusCode,
      statusLabel: 'Driver di tempat',
      isTerminalStatus: const {
        'COMPLETED',
        'CANCELLED',
        'CANCELLED_WITH_FEE',
      }.contains(statusCode),
      createdAt: DateTime(2026, 6, 18),
      estimatedDelivery: null,
      deliveryAddress: 'Jl. Customer',
      paymentStatus: 'unpaid',
      paymentMethod: 'COD',
      wasCancelledWithFee: wasCancelledWithFee,
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
    shoppingStops:
        shoppingStops ??
        [
          CustomerShoppingStopModel(
            pickupLocationId: 77,
            sequenceNo: 1,
            fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
            hasExplicitUnavailableItemActions:
                hasExplicitUnavailableItemActions,
            canEditUnavailableItems: true,
            canContinueWithoutUnavailableItem:
                canContinueWithoutUnavailableItem,
            canCancelUnavailableMerchant: canCancelUnavailableMerchant,
            canReplaceMerchant: canReplaceMerchant,
            merchant: CustomerShoppingMerchantModel(
              id: 10,
              name: 'Kedai Tinari',
              merchantType: 'restaurant',
              address: 'Jl. Sawunggaling III',
            ),
            items: stopItems,
          ),
        ],
    shoppingPricing:
        shoppingPricing ??
        const CustomerShoppingPricingModel(
          subtotal: 0,
          deliveryFee: 9000,
          serviceFee: 0,
          totalPrice: 9000,
          cancellationPenalty: 0,
        ),
    shoppingCapabilities:
        shoppingCapabilities ??
        const ShoppingOrderCapabilitiesModel(
          isExplicit: true,
          canCustomerEditUnavailableItems: true,
        ),
    shoppingNegotiation: shoppingNegotiation,
    deliveryFeeNegotiation: deliveryFeeNegotiation,
  );
}

List<CustomerShoppingStopModel> _shoppingStops(int count) {
  return List<CustomerShoppingStopModel>.generate(count, (index) {
    final id = 70 + index;
    return CustomerShoppingStopModel(
      pickupLocationId: id,
      sequenceNo: index + 1,
      fulfillmentStatus: 'PENDING',
      merchant: CustomerShoppingMerchantModel(
        id: id,
        name: 'Merchant ${index + 1}',
        merchantType: 'warung',
        address: 'Jl. Merchant ${index + 1}',
      ),
      items: [
        CustomerShoppingItemModel(
          id: id,
          pickupLocationId: id,
          itemSource: 'MANUAL',
          name: 'Item ${index + 1}',
          quantity: 1,
          unitPrice: 0,
          subtotal: 0,
          isAvailable: true,
        ),
      ],
    );
  }, growable: false);
}

CustomerShoppingStopModel _failedShoppingStop(int id, String merchantName) {
  return CustomerShoppingStopModel(
    pickupLocationId: id,
    sequenceNo: id,
    fulfillmentStatus: 'FAILED',
    chainFailedAttemptCount: 1,
    orderFailedTripCount: 1,
    canReplaceMerchant: true,
    merchant: CustomerShoppingMerchantModel(
      id: id,
      name: merchantName,
      merchantType: 'restaurant',
      address: 'Jl. Merchant $id',
    ),
    items: const [],
  );
}

ShoppingNegotiationModel _pendingShoppingQuote({
  required int pickupLocationId,
}) {
  return ShoppingNegotiationModel(
    amount: const AmountNegotiationModel(status: 'PENDING_CUSTOMER'),
    merchantQuotes: [
      ShoppingMerchantQuoteModel(
        pickupLocationId: pickupLocationId,
        merchantName: 'Merchant 1',
        amount: const AmountNegotiationModel(
          status: 'PENDING_CUSTOMER',
          quotedAmount: 18000,
          canCustomerRespond: true,
        ),
      ),
    ],
  );
}
