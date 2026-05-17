import '../utils/order_status.dart';
import '../utils/order_formatters.dart';
import '../utils/service_type.dart';

typedef DriverOrderAction = DriverOrderActionModel;

class DriverOrderModel {
  final String id;
  final String orderNumber;
  final String customerName;
  final String? customerPhone;
  final String serviceTypeCode;
  final String? serviceTypeName;
  final String pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String dropoffAddress;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final int etaMinutes;
  final int fee;
  final double totalPrice;
  final int itemCount;
  final String statusCode;
  final String? statusDisplayName;
  final String paymentStatus;
  final String paymentMethod;
  final String? acceptedAt;
  final List<DriverOrderActionModel> availableActions;
  final List<DriverOrderTimelineItemModel> statusTimeline;
  final String? packageDescription;
  final double? packageEstimatedWeightKg;
  final int? packageLengthCm;
  final int? packageWidthCm;
  final int? packageHeightCm;
  final String? packageSizeClass;
  final String? packageSafetyStatus;
  final String? packageSafetyReason;
  final String? packagePackingNote;
  final List<DriverShoppingItemModel> shoppingItems;
  final List<DriverShoppingStopModel> shoppingStops;
  final DriverShoppingPricingModel? shoppingPricing;
  final bool hasPendingShoppingPrices;

  const DriverOrderModel({
    required this.id,
    this.orderNumber = '',
    required this.customerName,
    this.customerPhone,
    this.serviceTypeCode = ServiceTypeCodes.unknown,
    this.serviceTypeName,
    required this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    required this.dropoffAddress,
    this.dropoffLatitude,
    this.dropoffLongitude,
    required this.etaMinutes,
    required this.fee,
    this.totalPrice = 0,
    required this.itemCount,
    this.statusCode = OrderStatusCodes.pending,
    this.statusDisplayName,
    this.paymentStatus = 'unpaid',
    this.paymentMethod = 'COD',
    this.acceptedAt,
    this.availableActions = const <DriverOrderActionModel>[],
    this.statusTimeline = const <DriverOrderTimelineItemModel>[],
    this.packageDescription,
    this.packageEstimatedWeightKg,
    this.packageLengthCm,
    this.packageWidthCm,
    this.packageHeightCm,
    this.packageSizeClass,
    this.packageSafetyStatus,
    this.packageSafetyReason,
    this.packagePackingNote,
    this.shoppingItems = const <DriverShoppingItemModel>[],
    this.shoppingStops = const <DriverShoppingStopModel>[],
    this.shoppingPricing,
    this.hasPendingShoppingPrices = false,
  });

  DriverOrderModel copyWith({
    String? acceptedAt,
    String? statusCode,
    String? statusDisplayName,
    String? paymentStatus,
    List<DriverOrderActionModel>? availableActions,
    List<DriverOrderTimelineItemModel>? statusTimeline,
  }) {
    return DriverOrderModel(
      id: id,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      serviceTypeCode: serviceTypeCode,
      serviceTypeName: serviceTypeName,
      pickupAddress: pickupAddress,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropoffAddress: dropoffAddress,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      etaMinutes: etaMinutes,
      fee: fee,
      totalPrice: totalPrice,
      itemCount: itemCount,
      statusCode: statusCode ?? this.statusCode,
      statusDisplayName: statusDisplayName ?? this.statusDisplayName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      availableActions: availableActions ?? this.availableActions,
      statusTimeline: statusTimeline ?? this.statusTimeline,
      packageDescription: packageDescription,
      packageEstimatedWeightKg: packageEstimatedWeightKg,
      packageLengthCm: packageLengthCm,
      packageWidthCm: packageWidthCm,
      packageHeightCm: packageHeightCm,
      packageSizeClass: packageSizeClass,
      packageSafetyStatus: packageSafetyStatus,
      packageSafetyReason: packageSafetyReason,
      packagePackingNote: packagePackingNote,
      shoppingItems: shoppingItems,
      shoppingStops: shoppingStops,
      shoppingPricing: shoppingPricing,
      hasPendingShoppingPrices: hasPendingShoppingPrices,
    );
  }

  factory DriverOrderModel.fromJson(Map<String, dynamic> json) {
    final actions = (json['available_actions'] is List)
        ? (json['available_actions'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(DriverOrderActionModel.fromJson)
              .toList(growable: false)
        : const <DriverOrderActionModel>[];

    final timeline = (json['status_timeline'] is List)
        ? (json['status_timeline'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(DriverOrderTimelineItemModel.fromJson)
              .toList(growable: false)
        : const <DriverOrderTimelineItemModel>[];

    final shoppingItems = (json['shopping_items'] is List)
        ? (json['shopping_items'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(DriverShoppingItemModel.fromJson)
              .toList(growable: false)
        : const <DriverShoppingItemModel>[];
    final shoppingStops = (json['shopping_stops'] is List)
        ? (json['shopping_stops'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .map(DriverShoppingStopModel.fromJson)
              .toList(growable: false)
        : const <DriverShoppingStopModel>[];
    final pricingRaw = (json['pricing'] is Map<String, dynamic>)
        ? json['pricing'] as Map<String, dynamic>
        : null;

    return DriverOrderModel(
      id: (json['id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? json['orderNumber'] ?? '')
          .toString(),
      customerName: (json['customer_name'] ?? json['customerName'] ?? '-')
          .toString(),
      customerPhone: (json['customer_phone'] ?? json['customerPhone'])
          ?.toString(),
      serviceTypeCode: normalizeServiceTypeCode(
        (json['service_type_code'] ?? json['serviceTypeCode'] ?? '').toString(),
      ),
      serviceTypeName: (json['service_type_name'] ?? json['serviceTypeName'])
          ?.toString(),
      pickupAddress: (json['pickup_address'] ?? json['pickupAddress'] ?? '-')
          .toString(),
      pickupLatitude: _asDoubleOrNull(
        json['pickup_latitude'] ?? json['pickupLatitude'],
      ),
      pickupLongitude: _asDoubleOrNull(
        json['pickup_longitude'] ?? json['pickupLongitude'],
      ),
      dropoffAddress: (json['dropoff_address'] ?? json['dropoffAddress'] ?? '-')
          .toString(),
      dropoffLatitude: _asDoubleOrNull(
        json['dropoff_latitude'] ?? json['dropoffLatitude'],
      ),
      dropoffLongitude: _asDoubleOrNull(
        json['dropoff_longitude'] ?? json['dropoffLongitude'],
      ),
      etaMinutes: _asInt(
        json['eta_minutes'] ?? json['etaMinutes'],
        fallback: 0,
      ),
      fee: _asInt(json['fee'], fallback: 0),
      totalPrice: _asDouble(json['total_price'] ?? json['totalPrice']),
      itemCount: _asInt(json['item_count'] ?? json['itemCount'], fallback: 0),
      statusCode: normalizeOrderStatusCode(
        (json['status_code'] ?? json['statusCode'] ?? json['status'] ?? '')
            .toString(),
      ),
      statusDisplayName:
          (json['status_display_name'] ?? json['statusDisplayName'])
              ?.toString(),
      paymentStatus:
          (json['payment_status'] ?? json['paymentStatus'] ?? 'unpaid')
              .toString(),
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? 'COD')
          .toString(),
      acceptedAt:
          json['accepted_at']?.toString() ?? json['acceptedAt']?.toString(),
      availableActions: actions,
      statusTimeline: timeline,
      packageDescription:
          (json['package_description'] ?? json['packageDescription'])
              ?.toString(),
      packageEstimatedWeightKg: _asDoubleOrNull(
        json['package_estimated_weight_kg'] ?? json['packageEstimatedWeightKg'],
      ),
      packageLengthCm: _asIntOrNull(
        json['package_length_cm'] ?? json['packageLengthCm'],
      ),
      packageWidthCm: _asIntOrNull(
        json['package_width_cm'] ?? json['packageWidthCm'],
      ),
      packageHeightCm: _asIntOrNull(
        json['package_height_cm'] ?? json['packageHeightCm'],
      ),
      packageSizeClass: (json['package_size_class'] ?? json['packageSizeClass'])
          ?.toString(),
      packageSafetyStatus:
          (json['package_safety_status'] ?? json['packageSafetyStatus'])
              ?.toString(),
      packageSafetyReason:
          (json['package_safety_reason'] ?? json['packageSafetyReason'])
              ?.toString(),
      packagePackingNote:
          (json['package_packing_note'] ?? json['packagePackingNote'])
              ?.toString(),
      shoppingItems: shoppingItems,
      shoppingStops: shoppingStops.isEmpty && shoppingItems.isNotEmpty
          ? DriverShoppingStopModel.fallbackFromItems(
              (json['merchant'] is Map<String, dynamic>)
                  ? json['merchant'] as Map<String, dynamic>
                  : const <String, dynamic>{},
              shoppingItems,
            )
          : shoppingStops,
      shoppingPricing: pricingRaw == null
          ? null
          : DriverShoppingPricingModel.fromJson(pricingRaw),
      hasPendingShoppingPrices:
          json['has_pending_shopping_prices'] == true ||
          pricingRaw?['has_pending_manual_prices'] == true,
    );
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class DriverShoppingItemModel {
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

  const DriverShoppingItemModel({
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
  bool get isPricePending => isManual && isAvailable && unitPrice <= 0;

  factory DriverShoppingItemModel.fromJson(Map<String, dynamic> json) {
    return DriverShoppingItemModel(
      id: DriverOrderModel._asInt(json['id'], fallback: 0),
      pickupLocationId: DriverOrderModel._asIntOrNull(
        json['pickup_location_id'],
      ),
      menuId: DriverOrderModel._asIntOrNull(json['menu_id']),
      itemSource: (json['item_source'] ?? 'MANUAL').toString(),
      name: (json['name'] ?? json['menu_name'] ?? '-').toString(),
      quantity: DriverOrderModel._asInt(json['quantity'], fallback: 1),
      unitPrice: DriverOrderModel._asDouble(json['unit_price']),
      subtotal: DriverOrderModel._asDouble(json['subtotal']),
      isAvailable: json['is_available'] != false,
      isHeavy: json['is_heavy'] == true,
      notes: json['notes']?.toString(),
      priceStatus: json['price_status']?.toString(),
    );
  }
}

class DriverShoppingStopModel {
  final int pickupLocationId;
  final int sequenceNo;
  final DriverShoppingMerchantModel merchant;
  final List<DriverShoppingItemModel> items;

  const DriverShoppingStopModel({
    required this.pickupLocationId,
    required this.sequenceNo,
    required this.merchant,
    required this.items,
  });

  factory DriverShoppingStopModel.fromJson(Map<String, dynamic> json) {
    final merchantJson = (json['merchant'] is Map<String, dynamic>)
        ? json['merchant'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawItems = (json['items'] is List)
        ? (json['items'] as List<dynamic>)
              .whereType<Map<String, dynamic>>()
              .toList(growable: false)
        : const <Map<String, dynamic>>[];

    return DriverShoppingStopModel(
      pickupLocationId: DriverOrderModel._asInt(
        json['pickup_location_id'],
        fallback: 0,
      ),
      sequenceNo: DriverOrderModel._asInt(json['sequence_no'], fallback: 0),
      merchant: DriverShoppingMerchantModel.fromJson(merchantJson),
      items: rawItems
          .map(DriverShoppingItemModel.fromJson)
          .toList(growable: false),
    );
  }

  static List<DriverShoppingStopModel> fallbackFromItems(
    Map<String, dynamic> merchantJson,
    List<DriverShoppingItemModel> items,
  ) {
    return [
      DriverShoppingStopModel(
        pickupLocationId: items.first.pickupLocationId ?? 0,
        sequenceNo: 1,
        merchant: DriverShoppingMerchantModel.fromJson(merchantJson),
        items: items,
      ),
    ];
  }
}

class DriverShoppingMerchantModel {
  final int? id;
  final String name;
  final String? merchantType;
  final String? address;

  const DriverShoppingMerchantModel({
    required this.id,
    required this.name,
    required this.merchantType,
    required this.address,
  });

  factory DriverShoppingMerchantModel.fromJson(Map<String, dynamic> json) {
    return DriverShoppingMerchantModel(
      id: DriverOrderModel._asIntOrNull(json['id']),
      name: (json['name'] ?? '-').toString(),
      merchantType: json['merchant_type']?.toString(),
      address: json['address']?.toString(),
    );
  }
}

class DriverShoppingPricingModel {
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double totalPrice;
  final double itemSurcharge;
  final double overweightSurcharge;
  final double cancellationPenalty;
  final int recalculationVersion;
  final bool hasPendingManualPrices;

  const DriverShoppingPricingModel({
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.totalPrice,
    required this.itemSurcharge,
    required this.overweightSurcharge,
    required this.cancellationPenalty,
    required this.recalculationVersion,
    required this.hasPendingManualPrices,
  });

  factory DriverShoppingPricingModel.fromJson(Map<String, dynamic> json) {
    return DriverShoppingPricingModel(
      subtotal: DriverOrderModel._asDouble(json['subtotal']),
      deliveryFee: DriverOrderModel._asDouble(json['delivery_fee']),
      serviceFee: DriverOrderModel._asDouble(json['service_fee']),
      totalPrice: DriverOrderModel._asDouble(json['total_price']),
      itemSurcharge: DriverOrderModel._asDouble(json['item_surcharge']),
      overweightSurcharge: DriverOrderModel._asDouble(
        json['overweight_surcharge'],
      ),
      cancellationPenalty: DriverOrderModel._asDouble(
        json['cancellation_penalty'],
      ),
      recalculationVersion: DriverOrderModel._asInt(
        json['recalculation_version'],
        fallback: 0,
      ),
      hasPendingManualPrices: json['has_pending_manual_prices'] == true,
    );
  }
}

class DriverOrderActionModel {
  final String actionCode;
  final String label;
  final String? targetStatusCode;
  final bool blocked;
  final String? blockedReason;

  const DriverOrderActionModel({
    required this.actionCode,
    required this.label,
    this.targetStatusCode,
    this.blocked = false,
    this.blockedReason,
  });

  bool get isCodCollection => actionCode.toUpperCase() == 'COLLECT_COD';

  factory DriverOrderActionModel.fromJson(Map<String, dynamic> json) {
    return DriverOrderActionModel(
      actionCode: (json['action_code'] ?? json['actionCode'] ?? '').toString(),
      label: (json['label'] ?? json['action_code'] ?? 'Aksi').toString(),
      targetStatusCode: (json['target_status_code'] ?? json['targetStatusCode'])
          ?.toString(),
      blocked: json['blocked'] == true,
      blockedReason: (json['blocked_reason'] ?? json['blockedReason'])
          ?.toString(),
    );
  }
}

class DriverOrderTimelineItemModel {
  final String statusCode;
  final String? statusDisplayName;
  final String eventType;
  final String? note;
  final DateTime? createdAt;

  const DriverOrderTimelineItemModel({
    required this.statusCode,
    required this.statusDisplayName,
    required this.eventType,
    required this.note,
    required this.createdAt,
  });

  factory DriverOrderTimelineItemModel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = (json['created_at'] ?? json['createdAt'])?.toString();

    return DriverOrderTimelineItemModel(
      statusCode: normalizeOrderStatusCode(
        (json['status_code'] ?? json['statusCode'] ?? '').toString(),
      ),
      statusDisplayName:
          (json['status_display_name'] ?? json['statusDisplayName'])
              ?.toString(),
      eventType: (json['event_type'] ?? json['eventType'] ?? 'STATUS_CHANGE')
          .toString(),
      note: json['note']?.toString(),
      createdAt: parseBackendDateTime(createdAtRaw),
    );
  }
}

class DriverHistoryOrderModel {
  final String id;
  final String customerName;
  final DateTime date;
  final int fee;
  final String status;

  const DriverHistoryOrderModel({
    required this.id,
    required this.customerName,
    required this.date,
    required this.fee,
    required this.status,
  });

  factory DriverHistoryOrderModel.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] ?? json['created_at'] ?? '').toString();

    return DriverHistoryOrderModel(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customer_name'] ?? json['customerName'] ?? '-')
          .toString(),
      date: parseBackendDateTime(rawDate) ?? DateTime.now().toUtc(),
      fee: DriverOrderModel._asInt(json['fee'], fallback: 0),
      status: (json['status'] ?? 'Selesai').toString(),
    );
  }
}

class DriverOrdersPayload {
  final List<DriverOrderModel> incoming;
  final List<DriverOrderModel> running;

  const DriverOrdersPayload({required this.incoming, required this.running});
}
