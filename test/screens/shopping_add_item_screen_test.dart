import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/providers/api_providers.dart';
import 'package:frontend_bangdeliv/screens/shopping_add_item_screen.dart';
import 'package:frontend_bangdeliv/services/api_client.dart';
import 'package:frontend_bangdeliv/services/customer_order_api_service.dart';

void main() {
  test('ShoppingMerchantOption parses type slug and address', () {
    final merchant = ShoppingMerchantOption.fromJson({
      'id': 12,
      'name': 'Resto Satu',
      'slug': 'resto-satu',
      'merchant_type': 'restaurant',
      'address': 'Jl. Resto',
    });

    expect(merchant.id, 12);
    expect(merchant.slug, 'resto-satu');
    expect(merchant.merchantType, 'restaurant');
    expect(merchant.address, 'Jl. Resto');
  });

  testWidgets(
    'restaurant merchant queues manual draft and submits batch item',
    (tester) async {
      final service = _FakeCustomerOrderApiService(
        merchants: const [
          ShoppingMerchantOption(
            id: 10,
            name: 'Resto Satu',
            slug: 'resto-satu',
            merchantType: 'restaurant',
            address: 'Jl. Resto',
          ),
        ],
      );

      await _pumpScreen(tester, service);

      await tester.tap(find.text('Resto Satu'));
      await tester.pumpAndSettle();

      expect(find.text('Item'), findsOneWidget);
      expect(find.text('Menu Katalog'), findsNothing);
      expect(find.text('Item berat'), findsNothing);
      expect(service.menuSearchCalls, 1);

      await tester.enterText(find.byType(TextField).at(1), 'Soto Ayam');
      await tester.pumpAndSettle();
      await _tapAddToDraft(tester);

      expect(service.addCalls, 0);
      expect(find.text('Daftar Item'), findsOneWidget);
      expect(find.text('Soto Ayam'), findsOneWidget);

      await _tapSubmitDrafts(tester);

      expect(service.addCalls, 1);
      expect(service.lastItems, hasLength(1));
      expect(service.lastItems.first.merchantId, 10);
      expect(service.lastItems.first.name, 'Soto Ayam');
    },
  );

  testWidgets('warung merchant queues multiple manual items before submit', (
    tester,
  ) async {
    final service = _FakeCustomerOrderApiService(
      merchants: const [
        ShoppingMerchantOption(
          id: 11,
          name: 'Warung Madura',
          slug: 'warung-madura',
          merchantType: 'warung',
          address: 'Jl. Warung',
        ),
      ],
    );

    await _pumpScreen(tester, service);

    await tester.tap(find.text('Warung Madura'));
    await tester.pumpAndSettle();

    expect(find.text('Item'), findsOneWidget);
    expect(find.text('Harga dikonfirmasi driver dari nota.'), findsOneWidget);
    expect(find.text('Item berat'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), 'Telur 1 kg');
    await tester.pumpAndSettle();
    await _tapAddToDraft(tester);

    await tester.enterText(find.byType(TextField).at(1), 'Gula 1 kg');
    await tester.pumpAndSettle();
    await _tapAddToDraft(tester);

    expect(service.addCalls, 0);
    expect(find.text('Telur 1 kg'), findsOneWidget);
    expect(find.text('Gula 1 kg'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Telur 1 kg'), findsNothing);
    expect(find.text('Gula 1 kg'), findsOneWidget);

    await _tapSubmitDrafts(tester);

    expect(service.addCalls, 1);
    expect(service.lastItems, hasLength(1));
    expect(service.lastItems.first.merchantId, 11);
    expect(service.lastItems.first.name, 'Gula 1 kg');
  });
}

Future<void> _tapAddToDraft(WidgetTester tester) async {
  final finder = find.text('Tambah');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapSubmitDrafts(WidgetTester tester) async {
  final finder = find.text('Simpan Item');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeCustomerOrderApiService service,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [customerOrderApiServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: ShoppingAddItemScreen(
          orderId: 1,
          initialDetail: _shoppingDetail(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeCustomerOrderApiService extends CustomerOrderApiService {
  _FakeCustomerOrderApiService({required this.merchants}) : super(ApiClient());

  final List<ShoppingMerchantOption> merchants;
  int addCalls = 0;
  int menuSearchCalls = 0;
  List<ShoppingItemDraftPayload> lastItems = const <ShoppingItemDraftPayload>[];

  @override
  Future<List<ShoppingMerchantOption>> searchShoppingMerchants(
    String query, {
    String? merchantType,
  }) async {
    return merchants;
  }

  @override
  Future<List<ShoppingMenuOption>> searchMerchantMenus(
    int merchantId,
    String query,
  ) async {
    menuSearchCalls += 1;
    return const <ShoppingMenuOption>[];
  }

  @override
  Future<CustomerOrderDetailModel> addShoppingItems(
    int orderId,
    List<ShoppingItemDraftPayload> items, {
    int? replacementForPickupLocationId,
  }) async {
    addCalls += 1;
    lastItems = items;
    final hasNewMerchant = items.any((item) => item.merchantId == 10);
    return _shoppingDetail(
      deliveryFee: hasNewMerchant ? 15000 : 5000,
      totalPrice: hasNewMerchant ? 35000 : 25000,
      stopCount: hasNewMerchant ? 2 : 1,
    );
  }
}

CustomerOrderDetailModel _shoppingDetail({
  double deliveryFee = 5000,
  double totalPrice = 25000,
  int stopCount = 1,
}) {
  return CustomerOrderDetailModel(
    summary: CustomerOrderSummaryModel(
      id: 1,
      orderNumber: 'BD-TEST-1',
      serviceTypeCode: 'SHOPPING',
      serviceTypeLabel: 'Nitip',
      restaurantName: 'Resto Awal',
      itemsSummary: '1x Telur',
      totalAmount: totalPrice,
      statusCode: 'DRIVER_ASSIGNED',
      statusLabel: 'Driver Ditugaskan',
      isTerminalStatus: false,
      createdAt: DateTime(2026, 5, 16),
      estimatedDelivery: null,
      deliveryAddress: 'Jl. Customer',
      paymentStatus: 'unpaid',
      paymentMethod: 'COD',
    ),
    paymentStatus: 'PENDING',
    paymentMethod: 'COD',
    driverName: null,
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
    shoppingItems: const <CustomerShoppingItemModel>[],
    shoppingStops: List<CustomerShoppingStopModel>.generate(
      stopCount,
      (index) => CustomerShoppingStopModel(
        pickupLocationId: index + 1,
        sequenceNo: index + 1,
        merchant: CustomerShoppingMerchantModel(
          id: index + 1,
          name: index == 0 ? 'Resto Awal' : 'Resto Satu',
          merchantType: 'restaurant',
          address: 'Jl. Merchant',
        ),
        items: const <CustomerShoppingItemModel>[],
      ),
    ),
    shoppingPricing: CustomerShoppingPricingModel(
      subtotal: totalPrice - deliveryFee,
      deliveryFee: deliveryFee,
      serviceFee: 0,
      totalPrice: totalPrice,
      itemSurcharge: 0,
      overweightSurcharge: 0,
      cancellationPenalty: 0,
    ),
  );
}
