import '../config/app_env.dart';
import '../utils/order_status.dart';
import '../utils/order_formatters.dart';
import '../utils/service_type.dart';
import 'order_route_model.dart';

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
  final double? deliveryDistanceKm;
  final String? deliveryDistanceText;
  final double? deliveryFee;
  final String? deliveryFeeSource;
  final double? manualDeliveryFee;
  final String? manualDeliveryFeeReason;
  final bool carefulCarryRequired;
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
  final OrderRouteModel? route;
  final DriverShoppingPricingModel? shoppingPricing;
  final List<DriverShoppingFeeBreakdownModel> feeBreakdown;
  final List<DriverOrderProofModel> proofs;
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
    this.deliveryDistanceKm,
    this.deliveryDistanceText,
    this.deliveryFee,
    this.deliveryFeeSource,
    this.manualDeliveryFee,
    this.manualDeliveryFeeReason,
    this.carefulCarryRequired = false,
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
    OrderRouteModel? route,
    OrderRouteModel? shoppingRoute,
    this.shoppingPricing,
    this.feeBreakdown = const <DriverShoppingFeeBreakdownModel>[],
    this.proofs = const <DriverOrderProofModel>[],
    this.hasPendingShoppingPrices = false,
  }) : route = route ?? shoppingRoute;

  OrderRouteModel? get shoppingRoute => route;

  String get deliveryDistanceLabel {
    final explicit = deliveryDistanceText?.trim() ?? '';
    if (explicit.isNotEmpty) {
      return explicit;
    }

    final distance = deliveryDistanceKm;
    if (distance == null || distance <= 0) {
      return '';
    }

    return '${distance.toStringAsFixed(1)} km';
  }

  bool hasProof(String type) {
    final normalizedType = type.trim().toLowerCase();
    if (normalizedType.isEmpty) {
      return false;
    }

    return proofs.any((proof) => proof.type == normalizedType);
  }

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
      deliveryDistanceKm: deliveryDistanceKm,
      deliveryDistanceText: deliveryDistanceText,
      deliveryFee: deliveryFee,
      deliveryFeeSource: deliveryFeeSource,
      manualDeliveryFee: manualDeliveryFee,
      manualDeliveryFeeReason: manualDeliveryFeeReason,
      carefulCarryRequired: carefulCarryRequired,
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
      route: route,
      shoppingPricing: shoppingPricing,
      feeBreakdown: feeBreakdown,
      proofs: proofs,
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
    final pricingSnapshot = (json['pricing_snapshot'] is Map<String, dynamic>)
        ? json['pricing_snapshot'] as Map<String, dynamic>
        : const <String, dynamic>{};

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
      serviceTypeName: serviceTypeLabel(
        normalizeServiceTypeCode(
          (json['service_type_name'] ??
                  json['serviceTypeName'] ??
                  json['service_type_code'] ??
                  json['serviceTypeCode'] ??
                  '')
              .toString(),
        ),
      ),
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
      deliveryDistanceKm: _asDoubleOrNull(
        json['delivery_distance_km'] ??
            json['deliveryDistanceKm'] ??
            pricingRaw?['delivery_distance_km'] ??
            pricingSnapshot['delivery_distance_km'],
      ),
      deliveryDistanceText:
          (json['delivery_distance_text'] ??
                  json['deliveryDistanceText'] ??
                  pricingRaw?['delivery_distance_text'] ??
                  pricingSnapshot['delivery_distance_text'])
              ?.toString(),
      deliveryFee: _asDoubleOrNull(
        json['delivery_fee'] ??
            json['deliveryFee'] ??
            pricingRaw?['delivery_fee'] ??
            pricingSnapshot['delivery_fee'],
      ),
      deliveryFeeSource:
          (json['delivery_fee_source'] ??
                  json['deliveryFeeSource'] ??
                  pricingRaw?['delivery_fee_source'] ??
                  pricingSnapshot['delivery_fee_source'])
              ?.toString(),
      manualDeliveryFee: _asDoubleOrNull(
        json['manual_delivery_fee'] ??
            json['manualDeliveryFee'] ??
            pricingRaw?['manual_delivery_fee'] ??
            pricingSnapshot['manual_delivery_fee'],
      ),
      manualDeliveryFeeReason:
          (json['manual_delivery_fee_reason'] ??
                  json['manualDeliveryFeeReason'] ??
                  pricingRaw?['manual_delivery_fee_reason'] ??
                  pricingSnapshot['manual_delivery_fee_reason'])
              ?.toString(),
      carefulCarryRequired: _asBool(
        json['careful_carry_required'] ??
            json['carefulCarryRequired'] ??
            pricingRaw?['careful_carry_required'] ??
            pricingSnapshot['careful_carry_required'],
      ),
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
      route: OrderRouteModel.fromRaw(json['route'] ?? json['shopping_route']),
      shoppingPricing: pricingRaw == null
          ? null
          : DriverShoppingPricingModel.fromJson(pricingRaw),
      feeBreakdown: _parseTopLevelFeeBreakdown(
        json['fee_breakdown'] ??
            pricingRaw?['fee_breakdown'] ??
            pricingSnapshot['fee_breakdown'],
      ),
      proofs: DriverOrderProofModel.parseList(
        json['proofs'] ??
            json['order_proofs'] ??
            json['evidences'] ??
            json['order_evidences'] ??
            json['attachments'] ??
            json['payment_attachments'],
      ),
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

  static DateTime? _asDateTime(dynamic value) {
    return parseBackendDateTime(value);
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static List<DriverShoppingFeeBreakdownModel> _parseTopLevelFeeBreakdown(
    dynamic raw,
  ) {
    if (raw is! List) {
      return const <DriverShoppingFeeBreakdownModel>[];
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(DriverShoppingFeeBreakdownModel.fromJson)
        .where((row) => row.amount > 0)
        .toList(growable: false);
  }
}

class DriverOrderProofModel {
  const DriverOrderProofModel({
    required this.id,
    required this.type,
    required this.label,
    this.photoUrl,
    this.status,
    this.note,
    this.pickupLocationId,
    this.createdAt,
  });

  final int id;
  final String type;
  final String label;
  final String? photoUrl;
  final String? status;
  final String? note;
  final int? pickupLocationId;
  final DateTime? createdAt;

  factory DriverOrderProofModel.fromJson(Map<String, dynamic> json) {
    final rawType = _normalizeType(
      json['type'] ?? json['proof_type'] ?? json['attachment_type'],
    );
    final rawEvidenceType = _normalizeEvidenceType(
      json['evidence_type'] ?? json['evidenceType'],
    );
    final type = rawType.isNotEmpty
        ? rawType
        : _typeFromEvidenceType(rawEvidenceType);
    final rawUrl =
        (json['photo_url'] ??
                json['file_url'] ??
                json['url'] ??
                json['path'] ??
                '')
            .toString()
            .trim();

    return DriverOrderProofModel(
      id: DriverOrderModel._asInt(json['id'], fallback: 0),
      type: type,
      label: _labelFor(type),
      photoUrl: rawUrl.isEmpty ? null : AppEnv.resolveBackendAssetUrl(rawUrl),
      status: (json['status'] ?? json['verification_status'])?.toString(),
      note: (json['note'] ?? json['notes'])?.toString(),
      pickupLocationId: DriverOrderModel._asIntOrNull(
        json['pickup_location_id'] ?? json['pickupLocationId'],
      ),
      createdAt: DriverOrderModel._asDateTime(
        json['uploaded_at'] ??
            json['uploadedAt'] ??
            json['created_at'] ??
            json['createdAt'],
      ),
    );
  }

  static String _normalizeType(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _normalizeEvidenceType(dynamic value) {
    return (value ?? '')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _typeFromEvidenceType(String evidenceType) {
    switch (evidenceType) {
      case 'PICKUP_PHOTO':
        return 'pickup';
      case 'DELIVERY_PHOTO':
      case 'COURIER_DELIVERY_PHOTO':
      case 'COURIER_RECEIVER_PHOTO':
        return 'delivery';
      case 'SHOPPING_RECEIPT':
        return 'receipt';
      case 'STORE_CLOSED_PHOTO':
        return 'store_closed';
      case 'PAYMENT_TRANSFER_PHOTO':
        return 'payment_transfer';
      default:
        return _normalizeType(evidenceType);
    }
  }

  static List<DriverOrderProofModel> parseList(dynamic raw) {
    if (raw is! List) {
      return const <DriverOrderProofModel>[];
    }

    return raw
        .whereType<Map<String, dynamic>>()
        .map(DriverOrderProofModel.fromJson)
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
  bool get isPricePending {
    final status = (priceStatus ?? '').trim().toUpperCase();
    if (status.isNotEmpty) {
      return status.contains('PENDING');
    }

    return isManual && isAvailable && unitPrice <= 0;
  }

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
  final String fulfillmentStatus;
  final int failedAttemptCount;
  final String? failureReason;
  final DateTime? failedAt;
  final DateTime? resolvedAt;
  final DriverShoppingMerchantModel merchant;
  final List<DriverShoppingItemModel> items;

  const DriverShoppingStopModel({
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
      fulfillmentStatus: (json['fulfillment_status'] ?? 'PENDING')
          .toString()
          .toUpperCase(),
      failedAttemptCount: DriverOrderModel._asInt(
        json['failed_attempt_count'],
        fallback: 0,
      ),
      failureReason: json['failure_reason']?.toString(),
      failedAt: DriverOrderModel._asDateTime(json['failed_at']),
      resolvedAt: DriverOrderModel._asDateTime(json['resolved_at']),
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
        fulfillmentStatus: 'PENDING',
        merchant: DriverShoppingMerchantModel.fromJson(merchantJson),
        items: items,
      ),
    ];
  }
}

typedef DriverShoppingRouteModel = OrderRouteModel;

class DriverShoppingMerchantModel {
  final int? id;
  final String name;
  final String? merchantType;
  final String? address;
  final double? latitude;
  final double? longitude;

  const DriverShoppingMerchantModel({
    required this.id,
    required this.name,
    required this.merchantType,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory DriverShoppingMerchantModel.fromJson(Map<String, dynamic> json) {
    return DriverShoppingMerchantModel(
      id: DriverOrderModel._asIntOrNull(json['id']),
      name: (json['name'] ?? '-').toString(),
      merchantType: json['merchant_type']?.toString(),
      address: json['address']?.toString(),
      latitude: DriverOrderModel._asDoubleOrNull(json['latitude']),
      longitude: DriverOrderModel._asDoubleOrNull(json['longitude']),
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
  final int failedAttemptCount;
  final int failedAttemptThreshold;
  final bool canCancelWithFee;
  final List<DriverShoppingFeeBreakdownModel> feeBreakdown;

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
    this.failedAttemptCount = 0,
    this.failedAttemptThreshold = 3,
    this.canCancelWithFee = false,
    this.feeBreakdown = const <DriverShoppingFeeBreakdownModel>[],
  });

  factory DriverShoppingPricingModel.fromJson(Map<String, dynamic> json) {
    final itemSurcharge = DriverOrderModel._asDouble(json['item_surcharge']);
    final overweightSurcharge = DriverOrderModel._asDouble(
      json['overweight_surcharge'],
    );
    final cancellationPenalty = DriverOrderModel._asDouble(
      json['cancellation_penalty'],
    );
    return DriverShoppingPricingModel(
      subtotal: DriverOrderModel._asDouble(json['subtotal']),
      deliveryFee: DriverOrderModel._asDouble(json['delivery_fee']),
      serviceFee: DriverOrderModel._asDouble(json['service_fee']),
      totalPrice: DriverOrderModel._asDouble(json['total_price']),
      itemSurcharge: itemSurcharge,
      overweightSurcharge: overweightSurcharge,
      cancellationPenalty: cancellationPenalty,
      recalculationVersion: DriverOrderModel._asInt(
        json['recalculation_version'],
        fallback: 0,
      ),
      hasPendingManualPrices: json['has_pending_manual_prices'] == true,
      failedAttemptCount: DriverOrderModel._asInt(
        json['failed_attempt_count'],
        fallback: 0,
      ),
      failedAttemptThreshold: DriverOrderModel._asInt(
        json['failed_attempt_threshold'],
        fallback: 3,
      ),
      canCancelWithFee: json['can_cancel_with_fee'] == true,
      feeBreakdown: DriverShoppingFeeBreakdownModel.parse(
        json['fee_breakdown'],
        itemSurcharge: itemSurcharge,
        overweightSurcharge: overweightSurcharge,
        cancellationPenalty: cancellationPenalty,
      ),
    );
  }
}

class DriverShoppingFeeBreakdownModel {
  final String code;
  final String label;
  final String description;
  final double amount;

  const DriverShoppingFeeBreakdownModel({
    required this.code,
    required this.label,
    required this.description,
    required this.amount,
  });

  factory DriverShoppingFeeBreakdownModel.fromJson(Map<String, dynamic> json) {
    return DriverShoppingFeeBreakdownModel(
      code: (json['code'] ?? '').toString(),
      label: (json['label'] ?? 'Service fee').toString(),
      description: (json['description'] ?? '').toString(),
      amount: DriverOrderModel._asDouble(json['amount']),
    );
  }

  static List<DriverShoppingFeeBreakdownModel> parse(
    dynamic raw, {
    required double itemSurcharge,
    required double overweightSurcharge,
    required double cancellationPenalty,
  }) {
    if (raw is List) {
      final parsed = raw
          .whereType<Map<String, dynamic>>()
          .map(DriverShoppingFeeBreakdownModel.fromJson)
          .where((row) => row.amount > 0)
          .toList(growable: false);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    return [
      if (itemSurcharge > 0)
        DriverShoppingFeeBreakdownModel(
          code: 'ITEM_BLOCK_SURCHARGE',
          label: 'Biaya banyak item',
          description: 'Tambahan saat jumlah item melewati batas gratis',
          amount: itemSurcharge,
        ),
      if (overweightSurcharge > 0)
        DriverShoppingFeeBreakdownModel(
          code: 'OVERWEIGHT_FLAT_SURCHARGE',
          label: 'Item berat',
          description: 'Dikenakan sekali per order',
          amount: overweightSurcharge,
        ),
      if (cancellationPenalty > 0)
        DriverShoppingFeeBreakdownModel(
          code: 'CANCELLATION_PENALTY_AFTER_FAILED_ATTEMPTS',
          label: 'Penalty merchant gagal',
          description: '50% ongkir setelah batas percobaan gagal',
          amount: cancellationPenalty,
        ),
    ];
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
