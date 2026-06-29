import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/core/di/app_providers.dart';
import 'package:frontend_bangdeliv/features/shopping/presentation/screens/shopping_add_item_screen.dart';
import 'package:frontend_bangdeliv/models/shopping_order_capability_model.dart';
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
      'latitude': -7.001,
      'longitude': 110.401,
    });

    expect(merchant.id, 12);
    expect(merchant.slug, 'resto-satu');
    expect(merchant.merchantType, 'restaurant');
    expect(merchant.address, 'Jl. Resto');
    expect(merchant.latitude, -7.001);
    expect(merchant.longitude, 110.401);
  });

  test('ShoppingItemDraftPayload serializes manual item contract', () {
    final payload = const ShoppingItemDraftPayload(
      merchantId: 10,
      name: 'Gula 1 kg',
      quantity: 2,
      notes: 'Putih',
    ).toJson();

    expect(payload['merchant_id'], 10);
    expect(payload['item_source'], 'MANUAL');
    expect(payload['menu_name'], 'Gula 1 kg');
    expect(payload['quantity'], 2);
    expect(payload['notes'], 'Putih');
    expect(payload.containsKey('menu_id'), isFalse);
  });

  test(
    'ShoppingItemDraftPayload serializes Google place merchant contract',
    () {
      final payload = const ShoppingItemDraftPayload(
        merchantId: null,
        merchantPlace: ShoppingMerchantPlacePayload(
          placeId: 'google-place-1',
          name: 'Warung Google',
          address: 'Jl. Google',
          latitude: -7.0061,
          longitude: 110.4061,
          types: ['food', 'store'],
        ),
        name: 'Es teh',
        quantity: 1,
        notes: null,
      ).toJson();

      expect(payload.containsKey('merchant_id'), isFalse);
      expect(payload['item_source'], 'MANUAL');
      expect(payload['menu_name'], 'Es teh');
      expect(payload['merchant_place'], isA<Map<String, dynamic>>());
      expect(payload['merchant_place']['place_id'], 'google-place-1');
      expect(payload['merchant_place']['name'], 'Warung Google');
      expect(payload['merchant_place']['latitude'], -7.0061);
      expect(payload['merchant_place']['types'], ['food', 'store']);
    },
  );

  test('ShoppingItemDraftPayload serializes menu database item contract', () {
    final payload = const ShoppingItemDraftPayload(
      merchantId: 10,
      menuId: 99,
      itemSource: 'MENU_DB',
      name: 'Soto Ayam',
      quantity: 3,
      notes: null,
      unitPrice: 18000,
    ).toJson();

    expect(payload['merchant_id'], 10);
    expect(payload['item_source'], 'MENU_DB');
    expect(payload['menu_id'], 99);
    expect(payload['menu_name'], 'Soto Ayam');
    expect(payload['quantity'], 3);
  });

  test(
    'shopping merchant search requests name sort accepted by backend',
    () async {
      Uri? capturedUri;
      final service = CustomerOrderApiService(
        ApiClient(
          httpClient: MockClient((request) async {
            capturedUri = request.url;

            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 20,
                    'name': 'Alfamart Bang Deliv Point',
                    'slug': 'alfamart-bangdeliv-point',
                    'merchant_type': 'convenience_store',
                    'address': 'Jl. Alfa',
                  },
                ],
              }),
              200,
            );
          }),
        ),
      );

      final merchants = await service.searchShoppingMerchants('alfa');

      expect(merchants.single.name, 'Alfamart Bang Deliv Point');
      expect(capturedUri?.path, endsWith('/api/v1/restaurants'));
      expect(capturedUri?.queryParameters['sort'], 'name');
      expect(capturedUri?.queryParameters['search'], 'alfa');
      expect(capturedUri?.queryParameters['per_page'], '20');
    },
  );

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

  testWidgets(
    'restaurant merchant queues menu catalog draft as manual pending-price item',
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
        menus: const [
          ShoppingMenuOption(id: 99, name: 'Soto Ayam', price: 18000),
        ],
      );

      await _pumpScreen(tester, service);

      await tester.tap(find.text('Resto Satu'));
      await tester.pumpAndSettle();

      expect(service.menuSearchCalls, 1);
      expect(find.text('Soto Ayam'), findsOneWidget);
      expect(find.text('Rp 18.000'), findsOneWidget);

      await tester.tap(find.text('Soto Ayam'));
      await tester.pumpAndSettle();

      expect(find.text('Daftar Item'), findsOneWidget);
      expect(find.text('Referensi Rp 18.000'), findsOneWidget);

      await _tapSubmitDrafts(tester);

      expect(service.addCalls, 1);
      expect(service.lastItems, hasLength(1));
      expect(service.lastItems.first.merchantId, 10);
      expect(service.lastItems.first.menuId, isNull);
      expect(service.lastItems.first.itemSource, 'MANUAL');
      expect(service.lastItems.first.name, 'Soto Ayam');
      expect(service.lastItems.first.unitPrice, 18000);
      expect(service.lastItems.first.toJson(), isNot(contains('menu_id')));
      expect(
        service.lastItems.first.toJson(),
        containsPair('menu_name', 'Soto Ayam'),
      );
    },
  );

  testWidgets(
    'official warung merchant loads menu list and keeps zero price pending',
    (tester) async {
      final service = _FakeCustomerOrderApiService(
        merchants: const [
          ShoppingMerchantOption(
            id: 11,
            name: 'Warung Bunda Dhia',
            slug: 'warung-bunda-dhia',
            merchantType: 'warung',
            address: 'Lokasi Bang Deliv',
          ),
        ],
        menus: const [ShoppingMenuOption(id: 88, name: 'Lotek', price: 0)],
      );

      await _pumpScreen(tester, service);

      await tester.tap(find.text('Warung Bunda Dhia'));
      await tester.pumpAndSettle();

      expect(service.menuSearchCalls, 1);
      expect(find.text('Lotek'), findsOneWidget);
      expect(find.text('Harga sesuai nota'), findsOneWidget);

      await tester.tap(find.text('Lotek'));
      await tester.pumpAndSettle();

      expect(find.text('Daftar Item'), findsOneWidget);
      expect(find.text('Harga sesuai nota'), findsWidgets);

      await _tapSubmitDrafts(tester);

      expect(service.addCalls, 1);
      expect(service.lastItems.single.merchantId, 11);
      expect(service.lastItems.single.menuId, isNull);
      expect(service.lastItems.single.itemSource, 'MANUAL');
      expect(service.lastItems.single.toJson(), isNot(contains('menu_id')));
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
    expect(service.menuSearchCalls, 1);

    await tester.enterText(find.byType(TextField).at(1), 'Telur 1 kg');
    await tester.pumpAndSettle();
    await _tapAddToDraft(tester);

    await tester.enterText(find.byType(TextField).at(1), 'Gula 1 kg');
    await tester.pumpAndSettle();
    await _tapAddToDraft(tester);

    expect(service.addCalls, 0);
    expect(find.text('Telur 1 kg'), findsOneWidget);
    expect(find.text('Gula 1 kg'), findsOneWidget);

    await tester.tap(find.byTooltip('Kurangi item').first);
    await tester.pumpAndSettle();

    expect(find.text('Telur 1 kg'), findsNothing);
    expect(find.text('Gula 1 kg'), findsOneWidget);

    await _tapSubmitDrafts(tester);

    expect(service.addCalls, 1);
    expect(service.lastItems, hasLength(1));
    expect(service.lastItems.first.merchantId, 11);
    expect(service.lastItems.first.name, 'Gula 1 kg');
  });

  testWidgets(
    'edit unavailable mode adds item to fixed merchant without picker',
    (tester) async {
      final service = _FakeCustomerOrderApiService(merchants: const []);
      final fixedStop = CustomerShoppingStopModel(
        pickupLocationId: 77,
        sequenceNo: 1,
        fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
        merchant: const CustomerShoppingMerchantModel(
          id: null,
          name: 'Kedai Tinari',
          merchantType: 'restaurant',
          address: 'Jl. Sawunggaling III',
        ),
        items: const <CustomerShoppingItemModel>[
          CustomerShoppingItemModel(
            id: 12,
            pickupLocationId: 77,
            itemSource: 'MANUAL',
            name: 'es jeruk',
            quantity: 1,
            unitPrice: 0,
            subtotal: 0,
            isAvailable: false,
          ),
        ],
      );

      await _pumpScreen(
        tester,
        service,
        targetPickupLocationId: 77,
        initialDetail: _shoppingDetail(
          statusCode: 'DRIVER_ASSIGNED',
          shoppingItems: fixedStop.items,
          shoppingStops: [fixedStop],
          shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
            isExplicit: true,
            canCustomerEditUnavailableItems: true,
          ),
        ),
      );

      expect(find.text('Kedai Tinari'), findsOneWidget);
      expect(service.menuSearchCalls, 0);

      await tester.enterText(find.byType(TextField).first, 'es teh');
      await tester.pumpAndSettle();
      await _tapAddToDraft(tester);

      expect(find.text('Pilih toko/resto terlebih dahulu.'), findsNothing);
      expect(find.text('es teh'), findsOneWidget);

      await _tapSubmitDrafts(tester);

      expect(service.changeCalls, 1);
      expect(service.lastAction, 'ADD');
      expect(service.lastRequestKind, 'EDIT_UNAVAILABLE');
      expect(service.lastTargetPickupLocationId, 77);
      expect(service.lastItems, hasLength(1));
      expect(service.lastItems.first.merchantId, isNull);
      expect(service.lastItems.first.toJson(), isNot(contains('merchant_id')));
      expect(
        service.lastItems.first.toJson(),
        isNot(contains('merchant_place')),
      );
    },
  );
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
  _FakeCustomerOrderApiService service, {
  CustomerOrderDetailModel? initialDetail,
  int? targetPickupLocationId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [customerOrderApiServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: ShoppingAddItemScreen(
          orderId: 1,
          initialDetail: initialDetail ?? _shoppingDetail(),
          targetPickupLocationId: targetPickupLocationId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeCustomerOrderApiService extends CustomerOrderApiService {
  _FakeCustomerOrderApiService({
    required this.merchants,
    this.menus = const <ShoppingMenuOption>[],
  }) : super(ApiClient());

  final List<ShoppingMerchantOption> merchants;
  final List<ShoppingMenuOption> menus;
  int addCalls = 0;
  int changeCalls = 0;
  int menuSearchCalls = 0;
  String? lastAction;
  String? lastRequestKind;
  int? lastTargetPickupLocationId;
  List<ShoppingItemDraftPayload> lastItems = const <ShoppingItemDraftPayload>[];

  @override
  Future<List<ShoppingMerchantOption>> searchShoppingMerchants(
    String query, {
    String? merchantType,
    int perPage = 20,
  }) async {
    return merchants;
  }

  @override
  Future<List<ShoppingMenuOption>> searchMerchantMenus(
    int merchantId,
    String query,
  ) async {
    menuSearchCalls += 1;
    return menus;
  }

  @override
  Future<CustomerOrderDetailModel> addShoppingItems(
    int orderId,
    List<ShoppingItemDraftPayload> items,
  ) async {
    addCalls += 1;
    lastItems = items;
    final hasNewMerchant = items.any((item) => item.merchantId == 10);
    return _shoppingDetail(
      deliveryFee: hasNewMerchant ? 15000 : 5000,
      totalPrice: hasNewMerchant ? 35000 : 25000,
      stopCount: hasNewMerchant ? 2 : 1,
    );
  }

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
    lastRequestKind = requestKind;
    lastTargetPickupLocationId = targetPickupLocationId;
    lastItems = items;
    return _shoppingDetail();
  }
}

CustomerOrderDetailModel _shoppingDetail({
  double deliveryFee = 5000,
  double totalPrice = 25000,
  int stopCount = 1,
  String statusCode = 'PENDING',
  List<CustomerShoppingItemModel> shoppingItems =
      const <CustomerShoppingItemModel>[],
  List<CustomerShoppingStopModel>? shoppingStops,
  ShoppingOrderCapabilitiesModel shoppingCapabilities =
      const ShoppingOrderCapabilitiesModel(),
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
      statusCode: statusCode,
      statusLabel: 'Menunggu Driver',
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
    shoppingItems: shoppingItems,
    shoppingStops:
        shoppingStops ??
        List<CustomerShoppingStopModel>.generate(
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
      cancellationPenalty: 0,
    ),
    shoppingCapabilities: shoppingCapabilities,
  );
}
