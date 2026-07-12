import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/models/driver_active_order_point.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/order_route_model.dart';

void main() {
  group('DriverActiveOrderPointPresenter', () {
    test('orders shopping merchants by route and excludes replaced stops', () {
      final order = _order(
        serviceTypeCode: 'SHOPPING',
        statusCode: 'ARRIVED_MERCHANT',
        route: const OrderRouteModel(orderedPickupLocationIds: [20, 10]),
        shoppingStops: [
          _stop(10, sequence: 1, name: 'Resto A'),
          _stop(20, sequence: 2, name: 'Resto B'),
          _stop(30, sequence: 3, name: 'Resto lama', status: 'REPLACED'),
        ],
      );

      final points = DriverActiveOrderPointPresenter.build(order);

      expect(points.map((point) => point.id), [
        DriverActiveOrderPoint.summaryId,
        DriverActiveOrderPoint.merchantId(20),
        DriverActiveOrderPoint.merchantId(10),
        DriverActiveOrderPoint.dropoffId,
      ]);
      expect(
        DriverActiveOrderPointPresenter.activePoint(order, points).id,
        DriverActiveOrderPoint.merchantId(20),
      );
    });

    test('moves shopping active point to dropoff during delivery', () {
      final order = _order(
        serviceTypeCode: 'SHOPPING',
        statusCode: 'ON_THE_WAY',
        shoppingStops: [
          _stop(10, sequence: 1, name: 'Resto A', status: 'COMPLETED'),
        ],
      );
      final points = DriverActiveOrderPointPresenter.build(order);

      expect(
        DriverActiveOrderPointPresenter.activePoint(order, points).id,
        DriverActiveOrderPoint.dropoffId,
      );
    });

    test(
      'prioritizes merchant already being processed over route suggestion',
      () {
        final order = _order(
          serviceTypeCode: 'SHOPPING',
          statusCode: 'ARRIVED_MERCHANT',
          route: const OrderRouteModel(orderedPickupLocationIds: [30, 10, 20]),
          shoppingStops: [
            _stop(10, sequence: 1, name: 'Resto A', status: 'OPEN_CONFIRMED'),
            _stop(20, sequence: 2, name: 'Resto B'),
            _stop(30, sequence: 3, name: 'Resto C'),
          ],
        );
        final points = DriverActiveOrderPointPresenter.build(order);

        expect(
          DriverActiveOrderPointPresenter.activePoint(order, points).id,
          DriverActiveOrderPoint.merchantId(10),
        );
        expect(
          DriverActiveOrderPointPresenter.canStartPendingMerchant(
            order,
            order.shoppingStops[1],
          ),
          isFalse,
        );
      },
    );

    test('allows any pending merchant before processing starts', () {
      final order = _order(
        serviceTypeCode: 'SHOPPING',
        statusCode: 'DRIVER_ASSIGNED',
        route: const OrderRouteModel(orderedPickupLocationIds: [30, 10, 20]),
        shoppingStops: [
          _stop(10, sequence: 1, name: 'Resto A'),
          _stop(20, sequence: 2, name: 'Resto B'),
          _stop(30, sequence: 3, name: 'Resto C'),
        ],
      );

      for (final stop in order.shoppingStops) {
        expect(
          DriverActiveOrderPointPresenter.canStartPendingMerchant(order, stop),
          isTrue,
        );
      }
    });

    test('moves to next pending merchant after previous price is approved', () {
      final order = _order(
        serviceTypeCode: 'SHOPPING',
        statusCode: 'ARRIVED_MERCHANT',
        route: const OrderRouteModel(orderedPickupLocationIds: [10, 20]),
        shoppingStops: [
          _stop(10, sequence: 1, name: 'Resto A', status: 'PRICE_APPROVED'),
          _stop(20, sequence: 2, name: 'Resto B'),
        ],
      );
      final points = DriverActiveOrderPointPresenter.build(order);

      expect(
        DriverActiveOrderPointPresenter.activePoint(order, points).id,
        DriverActiveOrderPoint.merchantId(20),
      );
      expect(
        DriverActiveOrderPointPresenter.canStartPendingMerchant(
          order,
          order.shoppingStops[1],
        ),
        isTrue,
      );
    });

    test('builds summary pickup and dropoff for ride and courier', () {
      for (final serviceType in ['RIDE', 'COURIER']) {
        final order = _order(
          serviceTypeCode: serviceType,
          statusCode: 'DRIVER_ASSIGNED',
        );
        final points = DriverActiveOrderPointPresenter.build(order);

        expect(points.map((point) => point.id), [
          DriverActiveOrderPoint.summaryId,
          DriverActiveOrderPoint.pickupId,
          DriverActiveOrderPoint.dropoffId,
        ]);
        expect(
          DriverActiveOrderPointPresenter.activePoint(order, points).id,
          DriverActiveOrderPoint.pickupId,
        );
      }
    });

    test('keeps coordinate-less point selectable but not navigable', () {
      final order = _order(
        serviceTypeCode: 'RIDE',
        statusCode: 'DRIVER_ASSIGNED',
        pickupLatitude: null,
        pickupLongitude: null,
      );

      final pickup = DriverActiveOrderPointPresenter.build(
        order,
      ).firstWhere((point) => point.id == DriverActiveOrderPoint.pickupId);

      expect(pickup.hasCoordinates, isFalse);
    });
  });
}

DriverOrderModel _order({
  required String serviceTypeCode,
  required String statusCode,
  double? pickupLatitude = -7.31,
  double? pickupLongitude = 110.49,
  OrderRouteModel? route,
  List<DriverShoppingStopModel> shoppingStops = const [],
}) {
  return DriverOrderModel(
    id: '42',
    customerName: 'Customer',
    serviceTypeCode: serviceTypeCode,
    pickupAddress: 'Pickup',
    pickupLatitude: pickupLatitude,
    pickupLongitude: pickupLongitude,
    dropoffAddress: 'Dropoff',
    dropoffLatitude: -7.32,
    dropoffLongitude: 110.50,
    etaMinutes: 10,
    fee: 10000,
    itemCount: shoppingStops.length,
    statusCode: statusCode,
    route: route,
    shoppingStops: shoppingStops,
  );
}

DriverShoppingStopModel _stop(
  int id, {
  required int sequence,
  required String name,
  String status = 'PENDING',
}) {
  return DriverShoppingStopModel(
    pickupLocationId: id,
    sequenceNo: sequence,
    fulfillmentStatus: status,
    merchant: DriverShoppingMerchantModel(
      id: id,
      name: name,
      merchantType: 'restaurant',
      address: 'Alamat $name',
      latitude: -7.30 - (id / 10000),
      longitude: 110.48 + (id / 10000),
    ),
    items: const [],
  );
}
