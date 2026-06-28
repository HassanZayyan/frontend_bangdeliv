import '../config/app_env.dart';
import '../utils/order_status.dart';
import '../utils/order_formatters.dart';
import '../utils/service_type.dart';
import 'delivery_fee_negotiation_model.dart';
import 'order_route_model.dart';
import 'payment_proof_feedback_model.dart';
import 'shopping_order_capability_model.dart';
import 'shopping_negotiation_model.dart';

typedef DriverOrderAction = DriverOrderActionModel;

class DriverOrderModel {
  final String id;
  final String orderNumber;
  final String customerName;
  final String? customerPhone;
  final String? customerAvatarUrl;
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
  final double driverIncomeGross;
  final double driverAdminFeePercent;
  final double driverAdminFee;
  final double driverIncomeNet;
  final double? deliveryDistanceKm;
  final String? deliveryDistanceText;
  final double? deliveryFee;
  final String? deliveryFeeSource;
  final double? manualDeliveryFee;
  final String? manualDeliveryFeeReason;
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
  final List<DriverShoppingItemModel> shoppingItems;
  final List<DriverShoppingStopModel> shoppingStops;
  final OrderRouteModel? route;
  final DriverShoppingPricingModel? shoppingPricing;
  final DeliveryFeeNegotiationModel? deliveryFeeNegotiation;
  final ShoppingNegotiationModel? shoppingNegotiation;
  final ShoppingOrderCapabilitiesModel shoppingCapabilities;
  final ShoppingItemChangeRequestModel? shoppingItemChangeRequest;
  final List<DriverOrderProofModel> proofs;
  final PaymentProofFeedbackModel? paymentProofFeedback;
  final bool hasPendingShoppingPrices;
  final DriverDispatchModel? dispatch;

  const DriverOrderModel({
    required this.id,
    this.orderNumber = '',
    required this.customerName,
    this.customerPhone,
    this.customerAvatarUrl,
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
    this.driverIncomeGross = 0,
    this.driverAdminFeePercent = 0,
    this.driverAdminFee = 0,
    this.driverIncomeNet = 0,
    this.deliveryDistanceKm,
    this.deliveryDistanceText,
    this.deliveryFee,
    this.deliveryFeeSource,
    this.manualDeliveryFee,
    this.manualDeliveryFeeReason,
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
    this.shoppingItems = const <DriverShoppingItemModel>[],
    this.shoppingStops = const <DriverShoppingStopModel>[],
    OrderRouteModel? route,
    OrderRouteModel? shoppingRoute,
    this.shoppingPricing,
    this.deliveryFeeNegotiation,
    this.shoppingNegotiation,
    this.shoppingCapabilities = const ShoppingOrderCapabilitiesModel(),
    this.shoppingItemChangeRequest,
    this.proofs = const <DriverOrderProofModel>[],
    this.paymentProofFeedback,
    this.hasPendingShoppingPrices = false,
    this.dispatch,
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
    List<DriverOrderProofModel>? proofs,
    PaymentProofFeedbackModel? paymentProofFeedback,
    List<DriverOrderActionModel>? availableActions,
    List<DriverOrderTimelineItemModel>? statusTimeline,
  }) {
    return DriverOrderModel(
      id: id,
      orderNumber: orderNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAvatarUrl: customerAvatarUrl,
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
      driverIncomeGross: driverIncomeGross,
      driverAdminFeePercent: driverAdminFeePercent,
      driverAdminFee: driverAdminFee,
      driverIncomeNet: driverIncomeNet,
      deliveryDistanceKm: deliveryDistanceKm,
      deliveryDistanceText: deliveryDistanceText,
      deliveryFee: deliveryFee,
      deliveryFeeSource: deliveryFeeSource,
      manualDeliveryFee: manualDeliveryFee,
      manualDeliveryFeeReason: manualDeliveryFeeReason,
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
      shoppingItems: shoppingItems,
      shoppingStops: shoppingStops,
      route: route,
      shoppingPricing: shoppingPricing,
      deliveryFeeNegotiation: deliveryFeeNegotiation,
      shoppingNegotiation: shoppingNegotiation,
      shoppingCapabilities: shoppingCapabilities,
      shoppingItemChangeRequest: shoppingItemChangeRequest,
      proofs: proofs ?? this.proofs,
      paymentProofFeedback: paymentProofFeedback ?? this.paymentProofFeedback,
      hasPendingShoppingPrices: hasPendingShoppingPrices,
      dispatch: dispatch,
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
    final route = OrderRouteModel.fromRaw(
      json['route'] ?? json['shopping_route'],
    );
    final deliveryDistanceKm =
        _asDoubleOrNull(
          json['delivery_distance_km'] ??
              json['deliveryDistanceKm'] ??
              pricingRaw?['delivery_distance_km'] ??
              pricingSnapshot['delivery_distance_km'],
        ) ??
        route?.distanceKm;
    final deliveryDistanceText =
        (json['delivery_distance_text'] ??
                json['deliveryDistanceText'] ??
                pricingRaw?['delivery_distance_text'] ??
                pricingSnapshot['delivery_distance_text'])
            ?.toString()
            .trim();

    final fee = _asInt(json['fee'], fallback: 0);
    final driverIncomeGross = _asDouble(
      json['driver_income_gross'] ??
          json['driverIncomeGross'] ??
          json['driver_income'] ??
          json['driverIncome'] ??
          fee,
    );
    final driverAdminFee = _asDouble(
      json['driver_admin_fee'] ?? json['driverAdminFee'],
    );
    final driverIncomeNetRaw =
        json['driver_income_net'] ?? json['driverIncomeNet'];
    final driverIncomeNet = driverIncomeNetRaw == null
        ? (driverIncomeGross - driverAdminFee)
              .clamp(0, double.infinity)
              .toDouble()
        : _asDouble(driverIncomeNetRaw);
    final customer = (json['customer'] is Map<String, dynamic>)
        ? json['customer'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final customerUser = (customer['user'] is Map<String, dynamic>)
        ? customer['user'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final customerAvatar = _firstNonEmptyString([
      json['customer_avatar_url'],
      json['customerAvatarUrl'],
      customer['avatar_url'],
      customer['avatarUrl'],
      customer['avatar'],
      customerUser['avatar_url'],
      customerUser['avatarUrl'],
      customerUser['avatar'],
    ]);

    return DriverOrderModel(
      id: (json['id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? json['orderNumber'] ?? '')
          .toString(),
      customerName: (json['customer_name'] ?? json['customerName'] ?? '-')
          .toString(),
      customerPhone: (json['customer_phone'] ?? json['customerPhone'])
          ?.toString(),
      customerAvatarUrl: customerAvatar == null
          ? null
          : AppEnv.resolveBackendAssetUrl(customerAvatar),
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
      fee: fee,
      driverIncomeGross: driverIncomeGross,
      driverAdminFeePercent: _asDouble(
        json['driver_admin_fee_percent'] ?? json['driverAdminFeePercent'],
      ),
      driverAdminFee: driverAdminFee,
      driverIncomeNet: driverIncomeNet,
      deliveryDistanceKm: deliveryDistanceKm,
      deliveryDistanceText:
          deliveryDistanceText == null || deliveryDistanceText.isEmpty
          ? route?.distanceText ??
                (deliveryDistanceKm == null
                    ? null
                    : '${deliveryDistanceKm.toStringAsFixed(1)} km')
          : deliveryDistanceText,
      deliveryFee: _asDoubleOrNull(
        json['delivery_fee'] ??
            json['deliveryFee'] ??
            pricingRaw?['delivery_fee'] ??
            pricingSnapshot['delivery_fee'],
      ),
      deliveryFeeSource: _normalizeDeliveryFeeSource(
        json['delivery_fee_source'] ??
            json['deliveryFeeSource'] ??
            pricingRaw?['delivery_fee_source'] ??
            pricingSnapshot['delivery_fee_source'],
      ),
      manualDeliveryFee: null,
      manualDeliveryFeeReason: null,
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
      shoppingItems: shoppingItems,
      shoppingStops: shoppingStops.isEmpty && shoppingItems.isNotEmpty
          ? DriverShoppingStopModel.fallbackFromItems(
              (json['merchant'] is Map<String, dynamic>)
                  ? json['merchant'] as Map<String, dynamic>
                  : const <String, dynamic>{},
              shoppingItems,
            )
          : shoppingStops,
      route: route,
      shoppingPricing: pricingRaw == null
          ? null
          : DriverShoppingPricingModel.fromJson(pricingRaw),
      deliveryFeeNegotiation: DeliveryFeeNegotiationModel.fromRaw(
        json['delivery_fee_negotiation'] ?? json['deliveryFeeNegotiation'],
      ),
      shoppingNegotiation: ShoppingNegotiationModel.fromRaw(
        json['shopping_negotiation'] ?? json['shoppingNegotiation'],
      ),
      shoppingCapabilities: ShoppingOrderCapabilitiesModel.fromRaw(
        json['shopping_capabilities'] ?? json['shoppingCapabilities'],
      ),
      shoppingItemChangeRequest: ShoppingItemChangeRequestModel.fromRaw(
        json['shopping_item_change_request'] ??
            json['shoppingItemChangeRequest'],
      ),
      proofs: DriverOrderProofModel.parseList(
        json['proofs'] ??
            json['order_proofs'] ??
            json['evidences'] ??
            json['order_evidences'] ??
            json['attachments'] ??
            json['payment_attachments'],
      ),
      paymentProofFeedback: PaymentProofFeedbackModel.fromRaw(
        json['payment_proof_feedback'] ?? json['paymentProofFeedback'],
      ),
      hasPendingShoppingPrices:
          json['has_pending_shopping_prices'] == true ||
          pricingRaw?['has_pending_manual_prices'] == true,
      dispatch: DriverDispatchModel.fromRaw(json['dispatch']),
    );
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final normalized = value?.toString().trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
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

  static String? _normalizeDeliveryFeeSource(dynamic value) {
    final source = value?.toString().trim().toLowerCase() ?? '';
    if (source.isEmpty) {
      return null;
    }

    return source == 'manual' ? 'driver_manual' : source;
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
    this.uploaderUserId,
    this.pickupLocationId,
    this.createdAt,
  });

  final int id;
  final String type;
  final String label;
  final String? photoUrl;
  final String? status;
  final String? note;
  final int? uploaderUserId;
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
      uploaderUserId: DriverOrderModel._asIntOrNull(
        json['uploader_user_id'] ?? json['user_id'] ?? json['userId'],
      ),
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
        return 'Bukti QRIS';
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
  final bool availabilityConfirmed;
  final DriverShoppingMerchantModel merchant;
  final List<DriverShoppingItemModel> items;

  const DriverShoppingStopModel({
    required this.pickupLocationId,
    required this.sequenceNo,
    this.fulfillmentStatus = 'PENDING',
    this.failedAttemptCount = 0,
    this.availabilityConfirmed = false,
    required this.merchant,
    required this.items,
  });

  bool get isFailed => fulfillmentStatus.toUpperCase() == 'FAILED';
  bool get isSkipped => fulfillmentStatus.toUpperCase() == 'SKIPPED';
  bool get isReplaced => fulfillmentStatus.toUpperCase() == 'REPLACED';
  bool get isCompleted => fulfillmentStatus.toUpperCase() == 'COMPLETED';
  bool get isOpenConfirmed =>
      fulfillmentStatus.toUpperCase() == 'OPEN_CONFIRMED';
  bool get isItemsPendingCustomer =>
      fulfillmentStatus.toUpperCase() == 'ITEMS_PENDING_CUSTOMER';
  bool get isItemsConfirmed =>
      fulfillmentStatus.toUpperCase() == 'ITEMS_CONFIRMED';
  bool get isPricePendingCustomer =>
      fulfillmentStatus.toUpperCase() == 'PRICE_PENDING_CUSTOMER';
  bool get isPriceApproved =>
      fulfillmentStatus.toUpperCase() == 'PRICE_APPROVED';
  bool get isTerminal => isFailed || isSkipped || isReplaced || isCompleted;
  bool get isActive => !isTerminal;

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
      availabilityConfirmed: json['availability_confirmed'] == true,
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
        availabilityConfirmed: false,
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
  final double cancellationPenalty;
  final int recalculationVersion;
  final bool hasPendingManualPrices;
  final int failedAttemptCount;
  final int failedAttemptThreshold;
  final bool canCancelWithFee;

  const DriverShoppingPricingModel({
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.totalPrice,
    required this.cancellationPenalty,
    required this.recalculationVersion,
    required this.hasPendingManualPrices,
    this.failedAttemptCount = 0,
    this.failedAttemptThreshold = 3,
    this.canCancelWithFee = false,
  });

  factory DriverShoppingPricingModel.fromJson(Map<String, dynamic> json) {
    final cancellationPenalty = DriverOrderModel._asDouble(
      json['cancellation_penalty'],
    );

    return DriverShoppingPricingModel(
      subtotal: DriverOrderModel._asDouble(json['subtotal']),
      deliveryFee: DriverOrderModel._asDouble(json['delivery_fee']),
      serviceFee: DriverOrderModel._asDouble(json['service_fee']),
      totalPrice: DriverOrderModel._asDouble(json['total_price']),
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
  final int? orderId;
  final String orderNumber;
  final String customerName;
  final DateTime date;
  final int fee;
  final double deliveryFee;
  final double serviceFee;
  final double driverIncome;
  final double driverIncomeGross;
  final double driverAdminFeePercent;
  final double driverAdminFee;
  final double driverIncomeNet;
  final double totalPrice;
  final String status;
  final String statusCode;

  const DriverHistoryOrderModel({
    required this.id,
    this.orderId,
    this.orderNumber = '',
    required this.customerName,
    required this.date,
    required this.fee,
    this.deliveryFee = 0,
    this.serviceFee = 0,
    this.driverIncome = 0,
    this.driverIncomeGross = 0,
    this.driverAdminFeePercent = 0,
    this.driverAdminFee = 0,
    this.driverIncomeNet = 0,
    this.totalPrice = 0,
    required this.status,
    this.statusCode = '',
  });

  String get displayOrderNumber {
    final explicit = orderNumber.trim();
    return explicit.isNotEmpty ? explicit : id;
  }

  double get effectiveDriverIncomeNet {
    if (driverIncomeNet > 0 || driverAdminFee > 0) {
      return driverIncomeNet;
    }

    if (driverIncome > 0) {
      return driverIncome;
    }

    return fee.toDouble();
  }

  int get netIncomeRounded => effectiveDriverIncomeNet.round();

  bool get hasAdminFeeBreakdown =>
      driverAdminFee > 0 && driverIncomeGross > driverIncomeNet;

  factory DriverHistoryOrderModel.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] ?? json['created_at'] ?? '').toString();
    final rawId = (json['id'] ?? '').toString();
    final rawOrderNumber =
        (json['order_number'] ?? json['orderNumber'])?.toString().trim() ?? '';
    final driverIncome = DriverOrderModel._asDouble(
      json['driver_income'] ?? json['driverIncome'] ?? json['fee'],
    );
    final driverIncomeGross = DriverOrderModel._asDouble(
      json['driver_income_gross'] ?? json['driverIncomeGross'] ?? driverIncome,
    );
    final driverAdminFee = DriverOrderModel._asDouble(
      json['driver_admin_fee'] ?? json['driverAdminFee'],
    );
    final driverIncomeNetRaw =
        json['driver_income_net'] ?? json['driverIncomeNet'];
    final driverIncomeNet = driverIncomeNetRaw == null
        ? (driverIncomeGross - driverAdminFee)
              .clamp(0, double.infinity)
              .toDouble()
        : DriverOrderModel._asDouble(driverIncomeNetRaw);

    return DriverHistoryOrderModel(
      id: rawId,
      orderId: DriverOrderModel._asIntOrNull(
        json['order_id'] ?? json['orderId'] ?? json['server_id'] ?? rawId,
      ),
      orderNumber: rawOrderNumber.isNotEmpty ? rawOrderNumber : rawId,
      customerName: (json['customer_name'] ?? json['customerName'] ?? '-')
          .toString(),
      date: parseBackendDateTime(rawDate) ?? DateTime.now().toUtc(),
      fee: DriverOrderModel._asInt(
        json['fee'] ?? json['driver_income'] ?? json['driverIncome'],
        fallback: 0,
      ),
      deliveryFee: DriverOrderModel._asDouble(
        json['delivery_fee'] ?? json['deliveryFee'],
      ),
      serviceFee: DriverOrderModel._asDouble(
        json['service_fee'] ?? json['serviceFee'],
      ),
      driverIncome: driverIncome,
      driverIncomeGross: driverIncomeGross,
      driverAdminFeePercent: DriverOrderModel._asDouble(
        json['driver_admin_fee_percent'] ?? json['driverAdminFeePercent'],
      ),
      driverAdminFee: driverAdminFee,
      driverIncomeNet: driverIncomeNet,
      totalPrice: DriverOrderModel._asDouble(
        json['total_price'] ?? json['totalPrice'],
      ),
      status: (json['status'] ?? 'Selesai').toString(),
      statusCode: (json['status_code'] ?? json['statusCode'] ?? '')
          .toString()
          .trim()
          .toUpperCase(),
    );
  }
}

class DriverDispatchModel {
  final int? priorityRank;
  final int? distanceToPickupMeters;
  final double? distanceToPickupKm;
  final int? distanceToCustomerMeters;
  final double? distanceToCustomerKm;
  final String distanceLabel;
  final String distanceBucket;
  final String distanceTargetRole;
  final String? distanceTargetLabel;
  final String? distanceTargetAddress;
  final bool locationFresh;

  const DriverDispatchModel({
    this.priorityRank,
    this.distanceToPickupMeters,
    this.distanceToPickupKm,
    this.distanceToCustomerMeters,
    this.distanceToCustomerKm,
    this.distanceLabel = 'Jarak belum tersedia',
    this.distanceBucket = 'UNKNOWN',
    this.distanceTargetRole = 'customer',
    this.distanceTargetLabel,
    this.distanceTargetAddress,
    this.locationFresh = false,
  });

  bool get hasDistance => (distanceToCustomerKm ?? distanceToPickupKm) != null;

  factory DriverDispatchModel.fromJson(Map<String, dynamic> json) {
    final bucket = (json['distance_bucket'] ?? json['distanceBucket'])
        .toString()
        .trim()
        .toUpperCase();
    final label =
        (json['distance_label'] ?? json['distanceLabel'])?.toString().trim() ??
        '';

    return DriverDispatchModel(
      priorityRank: DriverOrderModel._asIntOrNull(
        json['priority_rank'] ?? json['priorityRank'],
      ),
      distanceToPickupMeters: DriverOrderModel._asIntOrNull(
        json['distance_to_pickup_meters'] ?? json['distanceToPickupMeters'],
      ),
      distanceToPickupKm: DriverOrderModel._asDoubleOrNull(
        json['distance_to_pickup_km'] ?? json['distanceToPickupKm'],
      ),
      distanceToCustomerMeters: DriverOrderModel._asIntOrNull(
        json['distance_to_customer_meters'] ?? json['distanceToCustomerMeters'],
      ),
      distanceToCustomerKm: DriverOrderModel._asDoubleOrNull(
        json['distance_to_customer_km'] ?? json['distanceToCustomerKm'],
      ),
      distanceLabel: label.isEmpty ? 'Jarak belum tersedia' : label,
      distanceBucket: bucket.isEmpty ? 'UNKNOWN' : bucket,
      distanceTargetRole:
          (json['distance_target_role'] ?? json['distanceTargetRole'])
              ?.toString()
              .trim()
              .toLowerCase() ??
          'customer',
      distanceTargetLabel:
          (json['distance_target_label'] ?? json['distanceTargetLabel'])
              ?.toString()
              .trim(),
      distanceTargetAddress:
          (json['distance_target_address'] ?? json['distanceTargetAddress'])
              ?.toString()
              .trim(),
      locationFresh:
          json['location_fresh'] == true || json['locationFresh'] == true,
    );
  }

  static DriverDispatchModel? fromRaw(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return DriverDispatchModel.fromJson(raw);
    }
    return null;
  }
}

class DriverOrdersPayload {
  final List<DriverOrderModel> incoming;
  final List<DriverOrderModel> running;

  const DriverOrdersPayload({required this.incoming, required this.running});
}
