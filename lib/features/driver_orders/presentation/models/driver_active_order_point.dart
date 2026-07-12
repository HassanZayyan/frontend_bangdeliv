import '../../../../models/driver_order_model.dart';
import '../../../../utils/order_status.dart';
import '../../../../utils/service_type.dart';

enum DriverActiveOrderPointKind { summary, pickup, merchant, dropoff }

class DriverActiveOrderPoint {
  const DriverActiveOrderPoint({
    required this.id,
    required this.kind,
    required this.label,
    required this.title,
    required this.subtitle,
    this.latitude,
    this.longitude,
    this.pickupLocationId,
    this.sequenceNo,
    this.isTerminal = false,
    this.isFailed = false,
  });

  static const summaryId = 'summary';
  static const pickupId = 'pickup';
  static const dropoffId = 'dropoff';

  final String id;
  final DriverActiveOrderPointKind kind;
  final String label;
  final String title;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final int? pickupLocationId;
  final int? sequenceNo;
  final bool isTerminal;
  final bool isFailed;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isSummary => kind == DriverActiveOrderPointKind.summary;
  bool get isMerchant => kind == DriverActiveOrderPointKind.merchant;
  bool get isDropoff => kind == DriverActiveOrderPointKind.dropoff;

  static String merchantId(int pickupLocationId) =>
      'merchant:$pickupLocationId';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DriverActiveOrderPoint &&
            other.id == id &&
            other.kind == kind &&
            other.label == label &&
            other.title == title &&
            other.subtitle == subtitle &&
            other.latitude == latitude &&
            other.longitude == longitude &&
            other.pickupLocationId == pickupLocationId &&
            other.sequenceNo == sequenceNo &&
            other.isTerminal == isTerminal &&
            other.isFailed == isFailed;
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    label,
    title,
    subtitle,
    latitude,
    longitude,
    pickupLocationId,
    sequenceNo,
    isTerminal,
    isFailed,
  );
}

class DriverActiveOrderPointPresenter {
  const DriverActiveOrderPointPresenter._();

  static List<DriverActiveOrderPoint> build(DriverOrderModel order) {
    final serviceType = normalizeServiceTypeCode(order.serviceTypeCode);
    final points = <DriverActiveOrderPoint>[
      DriverActiveOrderPoint(
        id: DriverActiveOrderPoint.summaryId,
        kind: DriverActiveOrderPointKind.summary,
        label: 'Ringkasan',
        title: 'Ringkasan order',
        subtitle: _progressLabel(order),
      ),
    ];

    if (serviceType == ServiceTypeCodes.shopping) {
      final stops = _orderedOperationalStops(order);
      for (var index = 0; index < stops.length; index++) {
        final stop = stops[index];
        final sequence = stop.sequenceNo > 0 ? stop.sequenceNo : index + 1;
        points.add(
          DriverActiveOrderPoint(
            id: DriverActiveOrderPoint.merchantId(stop.pickupLocationId),
            kind: DriverActiveOrderPointKind.merchant,
            label: 'Tempat $sequence',
            title: stop.merchant.name,
            subtitle: _merchantStatusLabel(stop),
            latitude: stop.merchant.latitude,
            longitude: stop.merchant.longitude,
            pickupLocationId: stop.pickupLocationId,
            sequenceNo: sequence,
            isTerminal: stop.isTerminal,
            isFailed: stop.isFailed || stop.isAbandoned,
          ),
        );
      }
    } else {
      final pickupFinished = _isPickupFinished(order.statusCode);
      points.add(
        DriverActiveOrderPoint(
          id: DriverActiveOrderPoint.pickupId,
          kind: DriverActiveOrderPointKind.pickup,
          label: 'Jemput',
          title: serviceType == ServiceTypeCodes.ride
              ? 'Jemput penumpang'
              : 'Ambil paket',
          subtitle: order.pickupAddress,
          latitude: order.pickupLatitude,
          longitude: order.pickupLongitude,
          isTerminal: pickupFinished,
        ),
      );
    }

    points.add(
      DriverActiveOrderPoint(
        id: DriverActiveOrderPoint.dropoffId,
        kind: DriverActiveOrderPointKind.dropoff,
        label: 'Antar',
        title: 'Antar ke tujuan',
        subtitle: order.dropoffAddress,
        latitude: order.dropoffLatitude,
        longitude: order.dropoffLongitude,
        isTerminal: isTerminalOrderStatus(order.statusCode),
      ),
    );

    return points;
  }

  static DriverActiveOrderPoint activePoint(
    DriverOrderModel order,
    List<DriverActiveOrderPoint> points,
  ) {
    final status = normalizeOrderStatusCode(order.statusCode);
    final isShopping =
        normalizeServiceTypeCode(order.serviceTypeCode) ==
        ServiceTypeCodes.shopping;
    if (status == OrderStatusCodes.onTheWay ||
        status == OrderStatusCodes.arrivedDropoff ||
        status == OrderStatusCodes.delivered ||
        isTerminalOrderStatus(status)) {
      return points.firstWhere(
        (point) => point.isDropoff,
        orElse: () => points.first,
      );
    }

    if (isShopping) {
      final processingStop = processingShoppingStop(order);
      if (processingStop != null) {
        return points.firstWhere(
          (point) => point.pickupLocationId == processingStop.pickupLocationId,
          orElse: () => points.first,
        );
      }

      final pendingStops = _orderedOperationalStops(
        order,
      ).where(_isPendingStop);
      final nextPendingStop = pendingStops.isEmpty ? null : pendingStops.first;
      if (nextPendingStop != null) {
        return points.firstWhere(
          (point) => point.pickupLocationId == nextPendingStop.pickupLocationId,
          orElse: () => points.first,
        );
      }

      return points.firstWhere(
        (point) => point.isMerchant && !point.isTerminal,
        orElse: () => points.firstWhere(
          (point) => point.isDropoff,
          orElse: () => points.first,
        ),
      );
    }

    return points.firstWhere(
      (point) => point.kind == DriverActiveOrderPointKind.pickup,
      orElse: () => points.first,
    );
  }

  /// Merchant yang sudah mulai diproses dan harus diselesaikan sebelum driver
  /// memulai merchant pending lain. PRICE_APPROVED tidak termasuk karena kerja
  /// operasional driver pada merchant tersebut sudah selesai.
  static DriverShoppingStopModel? processingShoppingStop(
    DriverOrderModel order,
  ) {
    for (final stop in _orderedOperationalStops(order)) {
      if (_processingShoppingStatuses.contains(
        stop.fulfillmentStatus.toUpperCase(),
      )) {
        return stop;
      }
    }
    return null;
  }

  static bool canStartPendingMerchant(
    DriverOrderModel order,
    DriverShoppingStopModel stop,
  ) {
    return _isPendingStop(stop) && processingShoppingStop(order) == null;
  }

  static DriverShoppingStopModel? stopForPoint(
    DriverOrderModel order,
    DriverActiveOrderPoint point,
  ) {
    final pickupLocationId = point.pickupLocationId;
    if (pickupLocationId == null) {
      return null;
    }
    for (final stop in order.shoppingStops) {
      if (stop.pickupLocationId == pickupLocationId) {
        return stop;
      }
    }
    return null;
  }

  static List<DriverShoppingStopModel> _orderedOperationalStops(
    DriverOrderModel order,
  ) {
    final orderedIds = order.route?.orderedPickupLocationIds ?? const <int>[];
    final stops = order.shoppingStops
        .where((stop) => !stop.isReplaced && !stop.isSkipped)
        .toList(growable: false);
    stops.sort((a, b) {
      final aIndex = orderedIds.indexOf(a.pickupLocationId);
      final bIndex = orderedIds.indexOf(b.pickupLocationId);
      if (aIndex >= 0 || bIndex >= 0) {
        return (aIndex < 0 ? 1 << 20 : aIndex).compareTo(
          bIndex < 0 ? 1 << 20 : bIndex,
        );
      }
      return a.sequenceNo.compareTo(b.sequenceNo);
    });
    return stops;
  }

  static const Set<String> _processingShoppingStatuses = {
    'OPEN_CONFIRMED',
    'ITEMS_PENDING_CUSTOMER',
    'ITEMS_CONFIRMED',
    'PRICE_PENDING_CUSTOMER',
  };

  static bool _isPendingStop(DriverShoppingStopModel stop) =>
      stop.fulfillmentStatus.toUpperCase() == 'PENDING';

  static bool _isPickupFinished(String statusCode) {
    switch (normalizeOrderStatusCode(statusCode)) {
      case OrderStatusCodes.pickedUp:
      case OrderStatusCodes.onTheWay:
      case OrderStatusCodes.arrivedDropoff:
      case OrderStatusCodes.delivered:
      case OrderStatusCodes.completed:
        return true;
      default:
        return false;
    }
  }

  static String _merchantStatusLabel(DriverShoppingStopModel stop) {
    if (stop.isCompleted) return 'Selesai';
    if (stop.isFailed) return 'Gagal dikunjungi';
    if (stop.isAbandoned) return 'Batas percobaan tercapai';
    if (stop.isItemsPendingCustomer) return 'Menunggu keputusan item';
    if (stop.isPricePendingCustomer) return 'Menunggu persetujuan harga';
    if (stop.isPriceApproved) return 'Harga disetujui';
    if (stop.isItemsConfirmed) return 'Item dikonfirmasi';
    if (stop.isOpenConfirmed) return 'Tempat buka';
    return 'Tujuan berikutnya';
  }

  static String _progressLabel(DriverOrderModel order) {
    final serviceType = normalizeServiceTypeCode(order.serviceTypeCode);
    if (serviceType != ServiceTypeCodes.shopping) {
      return order.statusDisplayName ?? orderStatusLabel(order.statusCode);
    }
    final operational = order.shoppingStops
        .where((stop) => !stop.isReplaced && !stop.isSkipped)
        .toList(growable: false);
    final completed = operational.where((stop) => stop.isCompleted).length;
    return '$completed dari ${operational.length} tempat selesai';
  }
}
