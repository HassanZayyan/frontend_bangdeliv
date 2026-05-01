import '../utils/order_status.dart' as order_status;
import '../utils/order_formatters.dart';
import '../utils/service_type.dart' as service_type;

class OrderStatusSnapshot {
  final String code;
  final String label;
  final DateTime? changedAt;
  final int historyId;

  const OrderStatusSnapshot({
    required this.code,
    required this.label,
    required this.changedAt,
    required this.historyId,
  });
}

class _ParsedServiceType {
  final String code;
  final String label;

  const _ParsedServiceType({
    required this.code,
    required this.label,
  });
}

class _ParsedOrderStatus {
  final String code;
  final String label;
  final bool isTerminal;

  const _ParsedOrderStatus({
    required this.code,
    required this.label,
    required this.isTerminal,
  });
}

class CustomerOrderSummaryModel {
  final int id;
  final String orderNumber;
  final String serviceTypeCode;
  final String serviceTypeLabel;
  final String restaurantName;
  final String itemsSummary;
  final double totalAmount;
  final String statusCode;
  final String statusLabel;
  final bool isTerminalStatus;
  final DateTime? createdAt;
  final DateTime? estimatedDelivery;
  final String deliveryAddress;

  const CustomerOrderSummaryModel({
    required this.id,
    required this.orderNumber,
    required this.serviceTypeCode,
    required this.serviceTypeLabel,
    required this.restaurantName,
    required this.itemsSummary,
    required this.totalAmount,
    required this.statusCode,
    required this.statusLabel,
    required this.isTerminalStatus,
    required this.createdAt,
    required this.estimatedDelivery,
    required this.deliveryAddress,
  });

  bool get isCompleted =>
      order_status.normalizeOrderStatusCode(statusCode) ==
      order_status.OrderStatusCodes.completed;

  bool get isCancelled => order_status.isCancelledOrderStatus(statusCode);

  bool get canTrack => !isTerminalStatus;

  bool get canCancel {
    final normalizedStatus = order_status.normalizeOrderStatusCode(statusCode);
    return normalizedStatus == order_status.OrderStatusCodes.pending ||
        normalizedStatus == order_status.OrderStatusCodes.driverAssigned;
  }

  CustomerOrderSummaryModel copyWith({
    int? id,
    String? orderNumber,
    String? serviceTypeCode,
    String? serviceTypeLabel,
    String? restaurantName,
    String? itemsSummary,
    double? totalAmount,
    String? statusCode,
    String? statusLabel,
    bool? isTerminalStatus,
    DateTime? createdAt,
    DateTime? estimatedDelivery,
    String? deliveryAddress,
  }) {
    return CustomerOrderSummaryModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      serviceTypeCode: serviceTypeCode ?? this.serviceTypeCode,
      serviceTypeLabel: serviceTypeLabel ?? this.serviceTypeLabel,
      restaurantName: restaurantName ?? this.restaurantName,
      itemsSummary: itemsSummary ?? this.itemsSummary,
      totalAmount: totalAmount ?? this.totalAmount,
      statusCode: statusCode ?? this.statusCode,
      statusLabel: statusLabel ?? this.statusLabel,
      isTerminalStatus: isTerminalStatus ?? this.isTerminalStatus,
      createdAt: createdAt ?? this.createdAt,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    );
  }

  factory CustomerOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    final status = _extractStatus(json);
    final serviceType = _extractServiceType(json);

    return CustomerOrderSummaryModel(
      id: _asInt(json['id']),
      orderNumber: (json['order_number'] ?? '-').toString(),
      serviceTypeCode: serviceType.code,
      serviceTypeLabel: serviceType.label,
      restaurantName: _extractRestaurantName(json, serviceType.label),
      itemsSummary: _extractItemsSummary(json),
      totalAmount: _asDouble(json['total_amount'] ?? json['total_price']),
      statusCode: status.code,
      statusLabel: status.label,
      isTerminalStatus: status.isTerminal,
      createdAt: _asDateTime(json['created_at']),
      estimatedDelivery: _asDateTime(json['estimated_delivery']),
      deliveryAddress: (json['delivery_address'] ?? '-').toString(),
    );
  }

  static _ParsedServiceType _extractServiceType(Map<String, dynamic> json) {
    final dynamic rawServiceType = json['service_type'] ?? json['serviceType'];

    final rawMap = (rawServiceType is Map<String, dynamic>)
        ? rawServiceType
        : const <String, dynamic>{};

    final codeFromObject = (rawMap['code'] ?? '').toString().trim();
    final labelFromObject = (rawMap['display_name'] ?? rawMap['name'] ?? '')
        .toString()
        .trim();

    final codeFromPayload = (json['service_type_code'] ?? '').toString().trim();
    final labelFromPayload = (json['service_type_label'] ?? '')
        .toString()
        .trim();

    final rawString = rawServiceType is String ? rawServiceType.trim() : '';

    final normalizedCode = service_type.normalizeServiceTypeCode(
      codeFromObject.isNotEmpty
          ? codeFromObject
          : (codeFromPayload.isNotEmpty ? codeFromPayload : rawString),
    );

    final preferredLabel = labelFromObject.isNotEmpty
        ? labelFromObject
        : (labelFromPayload.isNotEmpty ? labelFromPayload : rawString);

    final fallbackLabel = service_type.serviceTypeLabel(normalizedCode);

    return _ParsedServiceType(
      code: normalizedCode,
      label: preferredLabel.isNotEmpty
          ? service_type.serviceTypeLabel(
              service_type.normalizeServiceTypeCode(preferredLabel),
            )
          : fallbackLabel,
    );
  }

  static _ParsedOrderStatus _extractStatus(Map<String, dynamic> json) {
    final rawStatus = (json['status_ref'] is Map<String, dynamic>)
        ? json['status_ref'] as Map<String, dynamic>
        : (json['statusRef'] is Map<String, dynamic>)
        ? json['statusRef'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final code = (rawStatus['code'] ?? '').toString().trim().toUpperCase();
    final displayName = (rawStatus['display_name'] ?? '').toString().trim();
    final isTerminal = rawStatus['is_terminal'] == true;

    final fallbackCode = code.isEmpty
        ? (json['status'] ?? 'PENDING').toString().trim().toUpperCase()
        : code;

    return _ParsedOrderStatus(
      code: fallbackCode,
      label: displayName.isNotEmpty
          ? displayName
          : order_status.orderStatusLabel(fallbackCode),
      isTerminal:
          isTerminal || order_status.isTerminalOrderStatus(fallbackCode),
    );
  }

  static String _extractRestaurantName(
    Map<String, dynamic> json,
    String serviceTypeLabel,
  ) {
    final restaurant = (json['restaurant'] is Map<String, dynamic>)
        ? json['restaurant'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final value = (restaurant['name'] ?? '').toString().trim();
    if (value.isNotEmpty) {
      return value;
    }

    return serviceTypeLabel.trim().isNotEmpty
        ? serviceTypeLabel
        : 'Layanan Bangdeliv';
  }

  static String _extractItemsSummary(Map<String, dynamic> json) {
    final items = (json['items'] is List)
        ? (json['items'] as List).whereType<Map<String, dynamic>>().toList(
            growable: false,
          )
        : const <Map<String, dynamic>>[];

    if (items.isEmpty) {
      return 'Tanpa item';
    }

    final first = items.first;
    final firstName = (first['menu_name'] ?? first['name'] ?? '-').toString();
    final firstQty = _asInt(first['quantity']);

    if (items.length == 1) {
      return '${firstQty <= 0 ? 1 : firstQty}x $firstName';
    }

    return '${firstQty <= 0 ? 1 : firstQty}x $firstName +${items.length - 1} item';
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.trim().isEmpty) {
      return null;
    }

    return parseBackendDateTime(raw);
  }
}

class CustomerOrderDetailModel {
  final CustomerOrderSummaryModel summary;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? notes;
  final String? driverName;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? driverLocationUpdatedAt;
  final String? deliveryDistanceText;
  final List<OrderStatusSnapshot> timeline;

  const CustomerOrderDetailModel({
    required this.summary,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.notes,
    required this.driverName,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.driverLatitude,
    required this.driverLongitude,
    required this.driverLocationUpdatedAt,
    required this.deliveryDistanceText,
    required this.timeline,
  });

  CustomerOrderDetailModel copyWith({
    CustomerOrderSummaryModel? summary,
    String? paymentStatus,
    String? paymentMethod,
    String? notes,
    String? driverName,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    double? driverLatitude,
    double? driverLongitude,
    DateTime? driverLocationUpdatedAt,
    String? deliveryDistanceText,
    List<OrderStatusSnapshot>? timeline,
  }) {
    return CustomerOrderDetailModel(
      summary: summary ?? this.summary,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      driverName: driverName ?? this.driverName,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      dropoffLatitude: dropoffLatitude ?? this.dropoffLatitude,
      dropoffLongitude: dropoffLongitude ?? this.dropoffLongitude,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      driverLocationUpdatedAt:
          driverLocationUpdatedAt ?? this.driverLocationUpdatedAt,
      deliveryDistanceText: deliveryDistanceText ?? this.deliveryDistanceText,
      timeline: timeline ?? this.timeline,
    );
  }

  factory CustomerOrderDetailModel.fromJson(Map<String, dynamic> json) {
    final summary = CustomerOrderSummaryModel.fromJson(json);

    final driver = (json['driver'] is Map<String, dynamic>)
        ? json['driver'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final driverUser = (driver['user'] is Map<String, dynamic>)
        ? driver['user'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final driverLocation = (json['driver_location'] is Map<String, dynamic>)
        ? json['driver_location'] as Map<String, dynamic>
        : (driver['location'] is Map<String, dynamic>)
        ? driver['location'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final locations = _extractOrderLocations(json);
    final pickupLocation = _findLocationByRole(locations, 'PICKUP');
    final dropoffLocation = _findLocationByRole(locations, 'DROPOFF');

    final dropoffLatitude = _asNullableDouble(
      json['delivery_latitude'] ?? dropoffLocation?['latitude'],
    );
    final dropoffLongitude = _asNullableDouble(
      json['delivery_longitude'] ?? dropoffLocation?['longitude'],
    );

    final pickupSource = (json['address'] is Map<String, dynamic>)
        ? json['address'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final pickupLatitude = _asNullableDouble(
      pickupLocation?['latitude'] ?? pickupSource['latitude'],
    );
    final pickupLongitude = _asNullableDouble(
      pickupLocation?['longitude'] ?? pickupSource['longitude'],
    );

    final parsedDriverLatitude = _asNullableDouble(
      driver['current_latitude'] ??
          driver['latitude'] ??
          driverLocation['latitude'] ??
          json['driver_latitude'],
    );
    final parsedDriverLongitude = _asNullableDouble(
      driver['current_longitude'] ??
          driver['longitude'] ??
          driverLocation['longitude'] ??
          json['driver_longitude'],
    );

    final histories = (json['status_histories'] is List)
        ? (json['status_histories'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : (json['statusHistories'] is List)
        ? (json['statusHistories'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    final timeline =
        histories
            .map((history) {
              final status = (history['status_ref'] is Map<String, dynamic>)
                  ? history['status_ref'] as Map<String, dynamic>
                  : (history['statusRef'] is Map<String, dynamic>)
                  ? history['statusRef'] as Map<String, dynamic>
                  : const <String, dynamic>{};

              final code = (status['code'] ?? '')
                  .toString()
                  .trim()
                  .toUpperCase();
              final label = (status['display_name'] ?? '').toString().trim();

              return OrderStatusSnapshot(
                code: code,
                label: label.isNotEmpty
                    ? label
                    : order_status.orderStatusLabel(code),
                changedAt: CustomerOrderSummaryModel._asDateTime(
                  history['created_at'] ?? history['updated_at'],
                ),
                historyId: CustomerOrderSummaryModel._asInt(history['id']),
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final aTime = a.changedAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.changedAt?.millisecondsSinceEpoch ?? 0;
            final compareByTime = aTime.compareTo(bTime);
            if (compareByTime != 0) {
              return compareByTime;
            }

            return a.historyId.compareTo(b.historyId);
          });

    return CustomerOrderDetailModel(
      summary: summary,
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      notes: json['notes']?.toString(),
      driverName: driverUser['name']?.toString(),
      pickupLatitude: pickupLatitude != null && _isValidLatitude(pickupLatitude)
          ? pickupLatitude
          : null,
      pickupLongitude:
          pickupLongitude != null && _isValidLongitude(pickupLongitude)
          ? pickupLongitude
          : null,
      dropoffLatitude:
          dropoffLatitude != null && _isValidLatitude(dropoffLatitude)
          ? dropoffLatitude
          : null,
      dropoffLongitude:
          dropoffLongitude != null && _isValidLongitude(dropoffLongitude)
          ? dropoffLongitude
          : null,
      driverLatitude:
          parsedDriverLatitude != null && _isValidLatitude(parsedDriverLatitude)
          ? parsedDriverLatitude
          : null,
      driverLongitude:
          parsedDriverLongitude != null &&
              _isValidLongitude(parsedDriverLongitude)
          ? parsedDriverLongitude
          : null,
      driverLocationUpdatedAt: CustomerOrderSummaryModel._asDateTime(
        driver['location_updated_at'] ??
            driverLocation['updated_at'] ??
            driver['updated_at'],
      ),
      deliveryDistanceText: json['delivery_distance_text']?.toString(),
      timeline: timeline,
    );
  }

  static List<Map<String, dynamic>> _extractOrderLocations(
    Map<String, dynamic> json,
  ) {
    if (json['order_locations'] is List) {
      return (json['order_locations'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }

    if (json['orderLocations'] is List) {
      return (json['orderLocations'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic>? _findLocationByRole(
    List<Map<String, dynamic>> locations,
    String role,
  ) {
    for (final location in locations) {
      final code = (location['location_role'] ?? location['role'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      if (code == role) {
        return location;
      }
    }

    return null;
  }

  static bool _isValidLatitude(double value) {
    return value >= -90 && value <= 90;
  }

  static bool _isValidLongitude(double value) {
    return value >= -180 && value <= 180;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    return double.tryParse(raw);
  }
}
