import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/features/tracking/application/track_order_presenter.dart';
import 'package:frontend_bangdeliv/models/customer_order_model.dart';

void main() {
  test('extractRouteArgs accepts legacy route extras', () {
    expect(TrackOrderPresenter.extractRouteArgs(12).orderId, 12);
    expect(TrackOrderPresenter.extractRouteArgs('13').orderId, 13);

    final args = TrackOrderPresenter.extractRouteArgs({
      'order_id': '14',
      'fromHistory': true,
    });

    expect(args.orderId, 14);
    expect(args.fromHistory, isTrue);
  });

  test('appBarTitle switches between tracking and history detail', () {
    expect(
      TrackOrderPresenter.appBarTitle(
        forceHistoryTitle: false,
        isTerminalStatus: false,
      ),
      'Lacak Pesanan',
    );
    expect(
      TrackOrderPresenter.appBarTitle(
        forceHistoryTitle: true,
        isTerminalStatus: false,
      ),
      'Detail Pesanan',
    );
    expect(
      TrackOrderPresenter.appBarTitle(
        forceHistoryTitle: false,
        isTerminalStatus: true,
      ),
      'Detail Pesanan',
    );
  });

  test('normalizedPaymentMethod prefers detail then summary then COD', () {
    final summary = _summary(paymentMethod: 'cod');

    expect(
      TrackOrderPresenter.normalizedPaymentMethod(
        summary,
        _detail(summary, paymentMethod: ' transfer '),
      ),
      'TRANSFER',
    );
    expect(
      TrackOrderPresenter.normalizedPaymentMethod(
        summary,
        _detail(summary, paymentMethod: ''),
      ),
      'COD',
    );
    expect(
      TrackOrderPresenter.normalizedPaymentMethod(
        _summary(paymentMethod: null),
        _detail(_summary(paymentMethod: null), paymentMethod: null),
      ),
      'COD',
    );
  });

  test('driverEtaMessage describes pickup and dropoff targets', () {
    final summary = _summary();

    expect(
      TrackOrderPresenter.driverEtaMessage(
        _detail(
          summary,
          driverEta: const DriverEtaModel(
            target: 'PICKUP',
            targetLabel: 'Titik jemput',
            durationSeconds: 480,
            durationText: '8 menit',
            locationFresh: true,
          ),
        ),
      ),
      'Driver tiba di titik jemput sekitar 8 menit lagi',
    );

    expect(
      TrackOrderPresenter.driverEtaMessage(
        _detail(
          summary,
          driverEta: const DriverEtaModel(
            target: 'DROPOFF',
            targetLabel: 'Alamat customer',
            durationSeconds: 720,
            durationText: '12 menit',
            locationFresh: true,
          ),
        ),
      ),
      'Driver sampai ke alamatmu sekitar 12 menit lagi',
    );

    expect(TrackOrderPresenter.driverEtaMessage(_detail(summary)), isNull);
  });

  test(
    'detail copyWith can clear stale driver ETA after realtime status change',
    () {
      final detail = _detail(
        _summary(),
        driverEta: const DriverEtaModel(
          target: 'PICKUP',
          targetLabel: 'Titik jemput',
          durationSeconds: 480,
          durationText: '8 menit',
          locationFresh: true,
        ),
      );

      expect(detail.driverEta, isNotNull);
      expect(detail.copyWith(clearDriverEta: true).driverEta, isNull);
    },
  );

  test('status helpers protect fixed tracking layout', () {
    final waiting = _summary(statusCode: 'PENDING', statusLabel: 'Menunggu');
    final arrived = _summary(
      statusCode: 'ARRIVED_DESTINATION',
      statusLabel: 'Driver tiba di tujuan',
    );
    final completed = _summary(
      statusCode: 'COMPLETED',
      statusLabel: 'Selesai',
      isTerminalStatus: true,
    );

    expect(TrackOrderPresenter.isWaitingDriverStatus(waiting), isTrue);
    expect(
      TrackOrderPresenter.isDriverArrivedDestinationStatus(arrived),
      isTrue,
    );
    expect(TrackOrderPresenter.shouldShowTrackingMap(completed), isFalse);
  });
}

CustomerOrderSummaryModel _summary({
  String statusCode = 'DRIVER_ASSIGNED',
  String statusLabel = 'Driver ditugaskan',
  bool isTerminalStatus = false,
  String serviceTypeCode = 'RIDE',
  String? paymentMethod = 'COD',
}) {
  return CustomerOrderSummaryModel(
    id: 1,
    orderNumber: 'BD-1',
    serviceTypeCode: serviceTypeCode,
    serviceTypeLabel: serviceTypeCode,
    restaurantName: 'BangDeliv',
    itemsSummary: 'Order',
    totalAmount: 10000,
    statusCode: statusCode,
    statusLabel: statusLabel,
    isTerminalStatus: isTerminalStatus,
    createdAt: DateTime(2026, 1, 1),
    estimatedDelivery: DateTime(2026, 1, 1, 10),
    deliveryAddress: 'Jl. Tujuan',
    paymentStatus: 'UNPAID',
    paymentMethod: paymentMethod,
  );
}

CustomerOrderDetailModel _detail(
  CustomerOrderSummaryModel summary, {
  String? paymentMethod = 'COD',
  DriverEtaModel? driverEta,
}) {
  return CustomerOrderDetailModel(
    summary: summary,
    paymentStatus: 'UNPAID',
    paymentMethod: paymentMethod,
    driverName: null,
    driverVehicleType: null,
    driverVehicleBrand: null,
    driverVehicleModel: null,
    driverVehiclePlate: null,
    pickupLatitude: null,
    pickupLongitude: null,
    dropoffLatitude: null,
    dropoffLongitude: null,
    driverLatitude: null,
    driverLongitude: null,
    driverLocationUpdatedAt: null,
    deliveryDistanceText: null,
    timeline: const <OrderStatusSnapshot>[],
    driverEta: driverEta,
  );
}
