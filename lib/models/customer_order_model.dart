import '../config/app_env.dart';
import '../utils/order_status.dart' as order_status;
import '../utils/order_formatters.dart';
import '../utils/service_type.dart' as service_type;
import 'order_route_model.dart';

class OrderStatusSnapshot {
  final String code;
  final String label;
  final String eventType;
  final DateTime? changedAt;
  final int historyId;

  const OrderStatusSnapshot({
    required this.code,
    required this.label,
    this.eventType = 'STATUS_CHANGE',
    required this.changedAt,
    required this.historyId,
  });
}

class _ParsedServiceType {
  final String code;
  final String label;

  const _ParsedServiceType({required this.code, required this.label});
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
  final double? deliveryDistanceKm;
  final String? deliveryDistanceText;
  final double? deliveryFee;
  final String? deliveryFeeSource;
  final double? manualDeliveryFee;
  final String? manualDeliveryFeeReason;
  final bool carefulCarryRequired;
  final String? paymentStatus;
  final String? paymentMethod;

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
    this.deliveryDistanceKm,
    this.deliveryDistanceText,
    this.deliveryFee,
    this.deliveryFeeSource,
    this.manualDeliveryFee,
    this.manualDeliveryFeeReason,
    this.carefulCarryRequired = false,
    required this.paymentStatus,
    required this.paymentMethod,
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
    double? deliveryDistanceKm,
    String? deliveryDistanceText,
    double? deliveryFee,
    String? deliveryFeeSource,
    double? manualDeliveryFee,
    String? manualDeliveryFeeReason,
    bool? carefulCarryRequired,
    String? paymentStatus,
    String? paymentMethod,
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
      deliveryDistanceKm: deliveryDistanceKm ?? this.deliveryDistanceKm,
      deliveryDistanceText: deliveryDistanceText ?? this.deliveryDistanceText,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      deliveryFeeSource: deliveryFeeSource ?? this.deliveryFeeSource,
      manualDeliveryFee: manualDeliveryFee ?? this.manualDeliveryFee,
      manualDeliveryFeeReason:
          manualDeliveryFeeReason ?? this.manualDeliveryFeeReason,
      carefulCarryRequired: carefulCarryRequired ?? this.carefulCarryRequired,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
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
      deliveryDistanceKm: _asNullableDouble(
        json['delivery_distance_km'] ?? json['deliveryDistanceKm'],
      ),
      deliveryDistanceText:
          (json['delivery_distance_text'] ?? json['deliveryDistanceText'])
              ?.toString(),
      deliveryFee: _asNullableDouble(
        json['delivery_fee'] ?? json['deliveryFee'],
      ),
      deliveryFeeSource:
          (json['delivery_fee_source'] ?? json['deliveryFeeSource'])
              ?.toString(),
      manualDeliveryFee: _asNullableDouble(
        json['manual_delivery_fee'] ?? json['manualDeliveryFee'],
      ),
      manualDeliveryFeeReason:
          (json['manual_delivery_fee_reason'] ??
                  json['manualDeliveryFeeReason'])
              ?.toString(),
      carefulCarryRequired: _asBool(
        json['careful_carry_required'] ?? json['carefulCarryRequired'],
      ),
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
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
    final courierPackage = _extractCourierPackageSummary(json);
    if (courierPackage.isNotEmpty) {
      return courierPackage;
    }

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

  static String _extractCourierPackageSummary(Map<String, dynamic> json) {
    final courier = (json['courier_order'] is Map<String, dynamic>)
        ? json['courier_order'] as Map<String, dynamic>
        : (json['courierOrder'] is Map<String, dynamic>)
        ? json['courierOrder'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final packageDescription =
        (courier['package_description'] ?? courier['packageDescription'] ?? '')
            .toString()
            .trim();

    return packageDescription;
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

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
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
  final String? driverName;
  final String? driverVehicleType;
  final String? driverVehicleBrand;
  final String? driverVehicleModel;
  final String? driverVehiclePlate;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? driverLocationUpdatedAt;
  final String? deliveryDistanceText;
  final double? deliveryDistanceKm;
  final String? deliveryFeeSource;
  final double? manualDeliveryFee;
  final String? manualDeliveryFeeReason;
  final bool carefulCarryRequired;
  final List<OrderStatusSnapshot> timeline;
  final List<CustomerShoppingItemModel> shoppingItems;
  final List<CustomerShoppingStopModel> shoppingStops;
  final OrderRouteModel? route;
  final CustomerShoppingPricingModel? shoppingPricing;
  final List<CustomerOrderProofModel> proofs;

  const CustomerOrderDetailModel({
    required this.summary,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.driverName,
    required this.driverVehicleType,
    required this.driverVehicleBrand,
    required this.driverVehicleModel,
    required this.driverVehiclePlate,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.driverLatitude,
    required this.driverLongitude,
    required this.driverLocationUpdatedAt,
    required this.deliveryDistanceText,
    this.deliveryDistanceKm,
    this.deliveryFeeSource,
    this.manualDeliveryFee,
    this.manualDeliveryFeeReason,
    this.carefulCarryRequired = false,
    required this.timeline,
    this.shoppingItems = const <CustomerShoppingItemModel>[],
    this.shoppingStops = const <CustomerShoppingStopModel>[],
    OrderRouteModel? route,
    OrderRouteModel? shoppingRoute,
    this.shoppingPricing,
    this.proofs = const <CustomerOrderProofModel>[],
  }) : route = route ?? shoppingRoute;

  OrderRouteModel? get shoppingRoute => route;

  bool get isShoppingOrder =>
      service_type.normalizeServiceTypeCode(summary.serviceTypeCode) ==
      service_type.ServiceTypeCodes.shopping;

  bool get canEditShoppingItems {
    if (!isShoppingOrder) {
      return false;
    }

    final normalized = order_status.normalizeOrderStatusCode(
      summary.statusCode,
    );
    return normalized == order_status.OrderStatusCodes.pending ||
        normalized == order_status.OrderStatusCodes.driverAssigned ||
        normalized == order_status.OrderStatusCodes.arrivedMerchant;
  }

  bool get canAddShoppingMerchant {
    if (!isShoppingOrder) {
      return false;
    }

    final normalized = order_status.normalizeOrderStatusCode(
      summary.statusCode,
    );
    return normalized == order_status.OrderStatusCodes.pending ||
        normalized == order_status.OrderStatusCodes.driverAssigned;
  }

  CustomerOrderDetailModel copyWith({
    CustomerOrderSummaryModel? summary,
    String? paymentStatus,
    String? paymentMethod,
    String? driverName,
    String? driverVehicleType,
    String? driverVehicleBrand,
    String? driverVehicleModel,
    String? driverVehiclePlate,
    double? pickupLatitude,
    double? pickupLongitude,
    double? dropoffLatitude,
    double? dropoffLongitude,
    double? driverLatitude,
    double? driverLongitude,
    DateTime? driverLocationUpdatedAt,
    String? deliveryDistanceText,
    double? deliveryDistanceKm,
    String? deliveryFeeSource,
    double? manualDeliveryFee,
    String? manualDeliveryFeeReason,
    bool? carefulCarryRequired,
    List<OrderStatusSnapshot>? timeline,
    List<CustomerShoppingItemModel>? shoppingItems,
    List<CustomerShoppingStopModel>? shoppingStops,
    OrderRouteModel? route,
    OrderRouteModel? shoppingRoute,
    CustomerShoppingPricingModel? shoppingPricing,
    List<CustomerOrderProofModel>? proofs,
  }) {
    return CustomerOrderDetailModel(
      summary: summary ?? this.summary,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      driverName: driverName ?? this.driverName,
      driverVehicleType: driverVehicleType ?? this.driverVehicleType,
      driverVehicleBrand: driverVehicleBrand ?? this.driverVehicleBrand,
      driverVehicleModel: driverVehicleModel ?? this.driverVehicleModel,
      driverVehiclePlate: driverVehiclePlate ?? this.driverVehiclePlate,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      dropoffLatitude: dropoffLatitude ?? this.dropoffLatitude,
      dropoffLongitude: dropoffLongitude ?? this.dropoffLongitude,
      driverLatitude: driverLatitude ?? this.driverLatitude,
      driverLongitude: driverLongitude ?? this.driverLongitude,
      driverLocationUpdatedAt:
          driverLocationUpdatedAt ?? this.driverLocationUpdatedAt,
      deliveryDistanceText: deliveryDistanceText ?? this.deliveryDistanceText,
      deliveryDistanceKm: deliveryDistanceKm ?? this.deliveryDistanceKm,
      deliveryFeeSource: deliveryFeeSource ?? this.deliveryFeeSource,
      manualDeliveryFee: manualDeliveryFee ?? this.manualDeliveryFee,
      manualDeliveryFeeReason:
          manualDeliveryFeeReason ?? this.manualDeliveryFeeReason,
      carefulCarryRequired: carefulCarryRequired ?? this.carefulCarryRequired,
      timeline: timeline ?? this.timeline,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      shoppingStops: shoppingStops ?? this.shoppingStops,
      route: route ?? shoppingRoute ?? this.route,
      shoppingPricing: shoppingPricing ?? this.shoppingPricing,
      proofs: proofs ?? this.proofs,
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
            .where((history) {
              final eventType = (history['event_type'] ?? 'STATUS_CHANGE')
                  .toString()
                  .trim()
                  .toUpperCase();
              return eventType.isEmpty || eventType == 'STATUS_CHANGE';
            })
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
                eventType: (history['event_type'] ?? 'STATUS_CHANGE')
                    .toString()
                    .trim()
                    .toUpperCase(),
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

    final rawItems = (json['items'] is List)
        ? (json['items'] as List).whereType<Map<String, dynamic>>().toList(
            growable: false,
          )
        : const <Map<String, dynamic>>[];
    final rawStops = (json['shopping_stops'] is List)
        ? (json['shopping_stops'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final shoppingItems = rawItems
        .map(CustomerShoppingItemModel.fromJson)
        .toList(growable: false);
    final shoppingOrder = (json['shopping_order'] is Map<String, dynamic>)
        ? json['shopping_order'] as Map<String, dynamic>
        : (json['shoppingOrder'] is Map<String, dynamic>)
        ? json['shoppingOrder'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return CustomerOrderDetailModel(
      summary: summary,
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      driverName: driverUser['name']?.toString(),
      driverVehicleType: driver['vehicle_type']?.toString(),
      driverVehicleBrand: driver['vehicle_brand']?.toString(),
      driverVehicleModel: driver['vehicle_model']?.toString(),
      driverVehiclePlate: driver['vehicle_plate']?.toString(),
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
      deliveryDistanceKm: _asNullableDouble(
        json['delivery_distance_km'] ?? json['deliveryDistanceKm'],
      ),
      deliveryFeeSource:
          (json['delivery_fee_source'] ?? json['deliveryFeeSource'])
              ?.toString(),
      manualDeliveryFee: _asNullableDouble(
        json['manual_delivery_fee'] ?? json['manualDeliveryFee'],
      ),
      manualDeliveryFeeReason:
          (json['manual_delivery_fee_reason'] ??
                  json['manualDeliveryFeeReason'])
              ?.toString(),
      carefulCarryRequired: CustomerOrderSummaryModel._asBool(
        json['careful_carry_required'] ?? json['carefulCarryRequired'],
      ),
      timeline: timeline,
      shoppingItems: shoppingItems,
      shoppingStops: rawStops.isEmpty
          ? CustomerShoppingStopModel.fallbackFromItems(
              summary.restaurantName,
              shoppingItems,
            )
          : rawStops
                .map(CustomerShoppingStopModel.fromJson)
                .toList(growable: false),
      route: OrderRouteModel.fromRaw(
        json['route'] ?? json['shopping_route'],
        shoppingOrder,
      ),
      shoppingPricing: CustomerShoppingPricingModel.fromJson(
        json,
        shoppingOrder,
      ),
      proofs: CustomerOrderProofModel.parseList(
        json['proofs'] ?? json['order_proofs'] ?? json['attachments'],
      ),
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

class CustomerOrderProofModel {
  const CustomerOrderProofModel({
    required this.id,
    required this.type,
    required this.label,
    this.photoUrl,
    this.status,
    this.note,
    this.createdAt,
  });

  final int id;
  final String type;
  final String label;
  final String? photoUrl;
  final String? status;
  final String? note;
  final DateTime? createdAt;

  factory CustomerOrderProofModel.fromJson(Map<String, dynamic> json) {
    final type =
        (json['type'] ?? json['proof_type'] ?? json['attachment_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    final rawUrl =
        (json['photo_url'] ??
                json['file_url'] ??
                json['url'] ??
                json['path'] ??
                '')
            .toString()
            .trim();

    return CustomerOrderProofModel(
      id: CustomerOrderSummaryModel._asInt(json['id']),
      type: type,
      label: _labelFor(type),
      photoUrl: rawUrl.isEmpty ? null : AppEnv.resolveBackendAssetUrl(rawUrl),
      status: (json['status'] ?? json['verification_status'])?.toString(),
      note: json['note']?.toString(),
      createdAt: CustomerOrderSummaryModel._asDateTime(
        json['created_at'] ?? json['createdAt'],
      ),
    );
  }

  static List<CustomerOrderProofModel> parseList(dynamic raw) {
    if (raw is! List) {
      return const <CustomerOrderProofModel>[];
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(CustomerOrderProofModel.fromJson)
        .where((proof) => proof.type.isNotEmpty)
        .toList(growable: false);
  }

  static String _labelFor(String type) {
    switch (type) {
      case 'pickup':
        return 'Bukti pengambilan';
      case 'delivery':
        return 'Bukti diterima';
      case 'receipt':
        return 'Foto struk';
      case 'store_closed':
        return 'Foto toko tutup';
      case 'payment_transfer':
        return 'Bukti transfer';
      default:
        return 'Bukti order';
    }
  }
}

class CustomerShoppingItemModel {
  final int id;
  final int? pickupLocationId;
  final int? menuId;
  final String itemSource;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final bool isAvailable;
  final bool isHeavy;
  final String? notes;
  final String? priceStatus;

  const CustomerShoppingItemModel({
    required this.id,
    this.pickupLocationId,
    this.menuId,
    required this.itemSource,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.isAvailable,
    required this.isHeavy,
    this.notes,
    this.priceStatus,
  });

  bool get isManual => itemSource.toUpperCase() == 'MANUAL';
  bool get isPricePending {
    final status = (priceStatus ?? '').trim().toUpperCase();
    if (status.isNotEmpty) {
      return status.contains('PENDING');
    }

    return isManual && isAvailable && unitPrice <= 0;
  }

  factory CustomerShoppingItemModel.fromJson(Map<String, dynamic> json) {
    return CustomerShoppingItemModel(
      id: CustomerOrderSummaryModel._asInt(json['id']),
      pickupLocationId: int.tryParse(
        json['pickup_location_id']?.toString() ?? '',
      ),
      menuId: int.tryParse(json['menu_id']?.toString() ?? ''),
      itemSource: (json['item_source'] ?? 'MANUAL').toString(),
      name: (json['menu_name'] ?? json['name'] ?? '-').toString(),
      quantity: CustomerOrderSummaryModel._asInt(json['quantity']),
      unitPrice: CustomerOrderSummaryModel._asDouble(json['unit_price']),
      subtotal: CustomerOrderSummaryModel._asDouble(json['subtotal']),
      isAvailable: json['is_available'] != false,
      isHeavy: json['is_heavy'] == true,
      notes: json['notes']?.toString(),
      priceStatus: json['price_status']?.toString(),
    );
  }
}

class CustomerShoppingStopModel {
  final int pickupLocationId;
  final int sequenceNo;
  final String fulfillmentStatus;
  final int failedAttemptCount;
  final String? failureReason;
  final DateTime? failedAt;
  final DateTime? resolvedAt;
  final CustomerShoppingMerchantModel merchant;
  final List<CustomerShoppingItemModel> items;

  const CustomerShoppingStopModel({
    required this.pickupLocationId,
    required this.sequenceNo,
    this.fulfillmentStatus = 'PENDING',
    this.failedAttemptCount = 0,
    this.failureReason,
    this.failedAt,
    this.resolvedAt,
    required this.merchant,
    required this.items,
  });

  bool get isFailed => fulfillmentStatus.toUpperCase() == 'FAILED';
  bool get isSkipped => fulfillmentStatus.toUpperCase() == 'SKIPPED';
  bool get isReplaced => fulfillmentStatus.toUpperCase() == 'REPLACED';
  bool get isActive => !isFailed && !isSkipped && !isReplaced;

  factory CustomerShoppingStopModel.fromJson(Map<String, dynamic> json) {
    final merchantJson = (json['merchant'] is Map<String, dynamic>)
        ? json['merchant'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawItems = (json['items'] is List)
        ? (json['items'] as List).whereType<Map<String, dynamic>>().toList(
            growable: false,
          )
        : const <Map<String, dynamic>>[];

    return CustomerShoppingStopModel(
      pickupLocationId: CustomerOrderSummaryModel._asInt(
        json['pickup_location_id'],
      ),
      sequenceNo: CustomerOrderSummaryModel._asInt(json['sequence_no']),
      fulfillmentStatus: (json['fulfillment_status'] ?? 'PENDING')
          .toString()
          .toUpperCase(),
      failedAttemptCount: CustomerOrderSummaryModel._asInt(
        json['failed_attempt_count'],
      ),
      failureReason: json['failure_reason']?.toString(),
      failedAt: CustomerOrderSummaryModel._asDateTime(json['failed_at']),
      resolvedAt: CustomerOrderSummaryModel._asDateTime(json['resolved_at']),
      merchant: CustomerShoppingMerchantModel.fromJson(merchantJson),
      items: rawItems
          .map(CustomerShoppingItemModel.fromJson)
          .toList(growable: false),
    );
  }

  static List<CustomerShoppingStopModel> fallbackFromItems(
    String merchantName,
    List<CustomerShoppingItemModel> items,
  ) {
    if (items.isEmpty) {
      return const <CustomerShoppingStopModel>[];
    }

    return [
      CustomerShoppingStopModel(
        pickupLocationId: items.first.pickupLocationId ?? 0,
        sequenceNo: 1,
        fulfillmentStatus: 'PENDING',
        merchant: CustomerShoppingMerchantModel(
          id: null,
          name: merchantName,
          merchantType: null,
          address: null,
        ),
        items: items,
      ),
    ];
  }
}

typedef CustomerShoppingRouteModel = OrderRouteModel;

class CustomerShoppingMerchantModel {
  final int? id;
  final String name;
  final String? merchantType;
  final String? address;
  final double? latitude;
  final double? longitude;

  const CustomerShoppingMerchantModel({
    required this.id,
    required this.name,
    required this.merchantType,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory CustomerShoppingMerchantModel.fromJson(Map<String, dynamic> json) {
    return CustomerShoppingMerchantModel(
      id: int.tryParse(json['id']?.toString() ?? ''),
      name: (json['name'] ?? '-').toString(),
      merchantType: json['merchant_type']?.toString(),
      address: json['address']?.toString(),
      latitude: CustomerOrderDetailModel._asNullableDouble(json['latitude']),
      longitude: CustomerOrderDetailModel._asNullableDouble(json['longitude']),
    );
  }
}

class CustomerShoppingPricingModel {
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double totalPrice;
  final double itemSurcharge;
  final double overweightSurcharge;
  final double cancellationPenalty;
  final int failedAttemptCount;
  final int failedAttemptThreshold;
  final bool canCancelWithFee;
  final List<CustomerShoppingFeeBreakdownModel> feeBreakdown;

  const CustomerShoppingPricingModel({
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.totalPrice,
    required this.itemSurcharge,
    required this.overweightSurcharge,
    required this.cancellationPenalty,
    this.failedAttemptCount = 0,
    this.failedAttemptThreshold = 3,
    this.canCancelWithFee = false,
    this.feeBreakdown = const <CustomerShoppingFeeBreakdownModel>[],
  });

  factory CustomerShoppingPricingModel.fromJson(
    Map<String, dynamic> orderJson,
    Map<String, dynamic> shoppingJson,
  ) {
    final itemSurcharge = CustomerOrderSummaryModel._asDouble(
      shoppingJson['item_surcharge'],
    );
    final overweightSurcharge = CustomerOrderSummaryModel._asDouble(
      shoppingJson['overweight_surcharge'],
    );
    final cancellationPenalty = CustomerOrderSummaryModel._asDouble(
      shoppingJson['cancellation_penalty'],
    );
    final rawSnapshot = shoppingJson['pricing_snapshot'] is Map<String, dynamic>
        ? shoppingJson['pricing_snapshot'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final feeBreakdown = _parseFeeBreakdown(
      shoppingJson['fee_breakdown'] ?? rawSnapshot['fee_breakdown'],
      itemSurcharge: itemSurcharge,
      overweightSurcharge: overweightSurcharge,
      cancellationPenalty: cancellationPenalty,
    );

    return CustomerShoppingPricingModel(
      subtotal: CustomerOrderSummaryModel._asDouble(orderJson['subtotal']),
      deliveryFee: CustomerOrderSummaryModel._asDouble(
        orderJson['delivery_fee'],
      ),
      serviceFee: CustomerOrderSummaryModel._asDouble(orderJson['service_fee']),
      totalPrice: CustomerOrderSummaryModel._asDouble(orderJson['total_price']),
      itemSurcharge: itemSurcharge,
      overweightSurcharge: overweightSurcharge,
      cancellationPenalty: cancellationPenalty,
      failedAttemptCount: CustomerOrderSummaryModel._asInt(
        shoppingJson['failed_attempt_count'],
      ),
      failedAttemptThreshold:
          CustomerOrderSummaryModel._asInt(
                shoppingJson['failed_attempt_threshold'],
              ) <=
              0
          ? 3
          : CustomerOrderSummaryModel._asInt(
              shoppingJson['failed_attempt_threshold'],
            ),
      canCancelWithFee: shoppingJson['can_cancel_with_fee'] == true,
      feeBreakdown: feeBreakdown,
    );
  }

  static List<CustomerShoppingFeeBreakdownModel> _parseFeeBreakdown(
    dynamic raw, {
    required double itemSurcharge,
    required double overweightSurcharge,
    required double cancellationPenalty,
  }) {
    if (raw is List) {
      final parsed = raw
          .whereType<Map<String, dynamic>>()
          .map(CustomerShoppingFeeBreakdownModel.fromJson)
          .where((row) => row.amount > 0)
          .toList(growable: false);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    return CustomerShoppingFeeBreakdownModel.fallback(
      itemSurcharge: itemSurcharge,
      overweightSurcharge: overweightSurcharge,
      cancellationPenalty: cancellationPenalty,
    );
  }
}

class CustomerShoppingFeeBreakdownModel {
  final String code;
  final String label;
  final String description;
  final double amount;

  const CustomerShoppingFeeBreakdownModel({
    required this.code,
    required this.label,
    required this.description,
    required this.amount,
  });

  factory CustomerShoppingFeeBreakdownModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomerShoppingFeeBreakdownModel(
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? 'Service fee').toString(),
      description: (json['description'] ?? '').toString(),
      amount: CustomerOrderSummaryModel._asDouble(json['amount']),
    );
  }

  static List<CustomerShoppingFeeBreakdownModel> fallback({
    required double itemSurcharge,
    required double overweightSurcharge,
    required double cancellationPenalty,
  }) {
    return [
      if (itemSurcharge > 0)
        CustomerShoppingFeeBreakdownModel(
          code: 'ITEM_BLOCK_SURCHARGE',
          label: 'Biaya banyak item',
          description: 'Tambahan saat jumlah item melewati batas gratis',
          amount: itemSurcharge,
        ),
      if (overweightSurcharge > 0)
        CustomerShoppingFeeBreakdownModel(
          code: 'OVERWEIGHT_FLAT_SURCHARGE',
          label: 'Item berat',
          description: 'Dikenakan sekali per order',
          amount: overweightSurcharge,
        ),
      if (cancellationPenalty > 0)
        CustomerShoppingFeeBreakdownModel(
          code: 'CANCELLATION_PENALTY_AFTER_FAILED_ATTEMPTS',
          label: 'Penalty merchant gagal',
          description: '50% ongkir setelah batas percobaan gagal',
          amount: cancellationPenalty,
        ),
    ];
  }
}
