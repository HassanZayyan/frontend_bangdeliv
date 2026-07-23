import '../config/app_env.dart';
import '../utils/order_status.dart' as order_status;
import '../utils/order_formatters.dart';
import '../utils/service_type.dart' as service_type;
import 'delivery_fee_negotiation_model.dart';
import 'order_route_model.dart';
import 'payment_proof_feedback_model.dart';
import 'shopping_order_capability_model.dart';
import 'shopping_negotiation_model.dart';
import 'shopping_pending_replacement_approval.dart';

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
  final String? deliveryFeeChangeNote;
  final double? manualDeliveryFee;
  final String? manualDeliveryFeeReason;
  final String? paymentStatus;
  final String? paymentMethod;
  final bool wasCancelledWithFee;

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
    this.deliveryFeeChangeNote,
    this.manualDeliveryFee,
    this.manualDeliveryFeeReason,
    required this.paymentStatus,
    required this.paymentMethod,
    this.wasCancelledWithFee = false,
  });

  bool get hasCancelledWithFeeOutcome {
    return wasCancelledWithFee ||
        order_status.normalizeOrderStatusCode(statusCode) ==
            order_status.OrderStatusCodes.cancelledWithFee;
  }

  String get effectiveStatusCode => hasCancelledWithFeeOutcome
      ? order_status.OrderStatusCodes.cancelledWithFee
      : statusCode;

  String get effectiveStatusLabel => hasCancelledWithFeeOutcome
      ? order_status.orderStatusLabel(
          order_status.OrderStatusCodes.cancelledWithFee,
        )
      : statusLabel;

  bool get isCompleted =>
      !hasCancelledWithFeeOutcome &&
      order_status.normalizeOrderStatusCode(statusCode) ==
          order_status.OrderStatusCodes.completed;

  bool get isCancelled =>
      hasCancelledWithFeeOutcome ||
      order_status.isCancelledOrderStatus(statusCode);

  bool get requiresCustomerPaymentAction {
    final normalizedServiceType = service_type.normalizeServiceTypeCode(
      serviceTypeCode,
    );
    final normalizedPaymentMethod = (paymentMethod ?? '').trim().toUpperCase();
    final normalizedPaymentStatus = (paymentStatus ?? '').trim().toLowerCase();

    return normalizedServiceType == service_type.ServiceTypeCodes.shopping &&
        hasCancelledWithFeeOutcome &&
        normalizedPaymentMethod == 'TRANSFER' &&
        normalizedPaymentStatus != 'paid';
  }

  bool get isResolvedForCustomer =>
      isTerminalStatus && !requiresCustomerPaymentAction;

  bool get canTrack => !isResolvedForCustomer;

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
    String? deliveryFeeChangeNote,
    double? manualDeliveryFee,
    String? manualDeliveryFeeReason,
    String? paymentStatus,
    String? paymentMethod,
    bool? wasCancelledWithFee,
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
      deliveryFeeChangeNote:
          deliveryFeeChangeNote ?? this.deliveryFeeChangeNote,
      manualDeliveryFee: manualDeliveryFee ?? this.manualDeliveryFee,
      manualDeliveryFeeReason:
          manualDeliveryFeeReason ?? this.manualDeliveryFeeReason,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      wasCancelledWithFee: wasCancelledWithFee ?? this.wasCancelledWithFee,
    );
  }

  factory CustomerOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    final status = _extractStatus(json);
    final serviceType = _extractServiceType(json);
    final route = OrderRouteModel.fromRaw(
      json['route'] ?? json['shopping_route'],
    );
    final distanceKm = _distanceKmFromJson(json, route);

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
      deliveryDistanceKm: distanceKm,
      deliveryDistanceText: _distanceTextFromJson(json, route, distanceKm),
      deliveryFee: _asNullableDouble(
        json['delivery_fee'] ?? json['deliveryFee'],
      ),
      deliveryFeeSource: _normalizeDeliveryFeeSource(
        json['delivery_fee_source'] ?? json['deliveryFeeSource'],
      ),
      deliveryFeeChangeNote: _firstNonEmptyString([
        json['delivery_fee_change_note'],
        json['deliveryFeeChangeNote'],
        json['delivery_fee_change_reason'],
        json['deliveryFeeChangeReason'],
      ]),
      manualDeliveryFee: null,
      manualDeliveryFeeReason: null,
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      wasCancelledWithFee: _asBool(
        json['was_cancelled_with_fee'] ?? json['wasCancelledWithFee'],
      ),
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
      label: order_status.orderStatusDisplayLabel(
        fallbackCode,
        fallbackLabel: displayName,
      ),
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

    return serviceTypeLabel.trim().isNotEmpty ? serviceTypeLabel : 'Kurir';
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

  static String? _normalizeDeliveryFeeSource(dynamic value) {
    final source = value?.toString().trim().toLowerCase() ?? '';
    if (source.isEmpty) {
      return null;
    }

    return source == 'manual' ? 'driver_manual' : source;
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '-') {
        return text;
      }
    }

    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.trim().isEmpty) {
      return null;
    }

    return parseBackendDateTime(raw);
  }

  static double? _distanceKmFromJson(
    Map<String, dynamic> json,
    OrderRouteModel? route,
  ) {
    return _asNullableDouble(
          json['delivery_distance_km'] ?? json['deliveryDistanceKm'],
        ) ??
        route?.distanceKm;
  }

  static String? _distanceTextFromJson(
    Map<String, dynamic> json,
    OrderRouteModel? route,
    double? distanceKm,
  ) {
    return _firstNonEmptyString([
          json['delivery_distance_text'],
          json['deliveryDistanceText'],
          route?.distanceText,
        ]) ??
        (distanceKm == null ? null : '${distanceKm.toStringAsFixed(1)} km');
  }
}

class DriverEtaModel {
  final String target;
  final String targetLabel;
  final int durationSeconds;
  final String durationText;
  final int? distanceMeters;
  final String? distanceText;
  final DateTime? estimatedArrivalAt;
  final bool locationFresh;
  final String? routeProvider;

  const DriverEtaModel({
    required this.target,
    required this.targetLabel,
    required this.durationSeconds,
    required this.durationText,
    this.distanceMeters,
    this.distanceText,
    this.estimatedArrivalAt,
    required this.locationFresh,
    this.routeProvider,
  });

  static DriverEtaModel? fromRaw(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final target = (raw['target'] ?? '').toString().trim().toUpperCase();
    final durationSeconds = CustomerOrderSummaryModel._asInt(
      raw['duration_seconds'] ?? raw['durationSeconds'],
    );
    final durationText = (raw['duration_text'] ?? raw['durationText'] ?? '')
        .toString()
        .trim();

    if (target.isEmpty || durationSeconds <= 0 || durationText.isEmpty) {
      return null;
    }

    final distanceText = _optionalText(
      raw['distance_text'] ?? raw['distanceText'],
    );

    return DriverEtaModel(
      target: target,
      targetLabel:
          _optionalText(raw['target_label'] ?? raw['targetLabel']) ??
          (target == 'DROPOFF' ? 'Alamat customer' : 'Titik jemput'),
      durationSeconds: durationSeconds,
      durationText: durationText,
      distanceMeters: _optionalInt(
        raw['distance_meters'] ?? raw['distanceMeters'],
      ),
      distanceText: distanceText,
      estimatedArrivalAt: CustomerOrderSummaryModel._asDateTime(
        raw['estimated_arrival_at'] ?? raw['estimatedArrivalAt'],
      ),
      locationFresh: CustomerOrderSummaryModel._asBool(
        raw['location_fresh'] ?? raw['locationFresh'],
      ),
      routeProvider: _optionalText(
        raw['route_provider'] ?? raw['routeProvider'],
      ),
    );
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty) {
      return null;
    }

    return int.tryParse(raw);
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == '-' ? null : text;
  }
}

class CustomerOrderDetailModel {
  final CustomerOrderSummaryModel summary;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? driverName;
  final String? driverPhone;
  final String? driverVehicleType;
  final String? driverVehicleBrand;
  final String? driverVehicleModel;
  final String? driverVehiclePlate;
  final String? driverAvatarUrl;
  final String? pickupAddress;
  final String? dropoffAddress;
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
  final String? deliveryFeeChangeNote;
  final double? manualDeliveryFee;
  final String? manualDeliveryFeeReason;
  final List<OrderStatusSnapshot> timeline;
  final List<CustomerShoppingItemModel> shoppingItems;
  final List<CustomerShoppingStopModel> shoppingStops;
  final OrderRouteModel? route;
  final CustomerShoppingPricingModel? shoppingPricing;
  final List<CustomerOrderProofModel> proofs;
  final PaymentProofFeedbackModel? paymentProofFeedback;
  final DriverEtaModel? driverEta;
  final DeliveryFeeNegotiationModel? deliveryFeeNegotiation;
  final ShoppingNegotiationModel? shoppingNegotiation;
  final ShoppingOrderCapabilitiesModel shoppingCapabilities;
  final ShoppingItemChangeRequestModel? shoppingItemChangeRequest;

  const CustomerOrderDetailModel({
    required this.summary,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.driverName,
    this.driverPhone,
    required this.driverVehicleType,
    required this.driverVehicleBrand,
    required this.driverVehicleModel,
    required this.driverVehiclePlate,
    this.driverAvatarUrl,
    this.pickupAddress,
    this.dropoffAddress,
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
    this.deliveryFeeChangeNote,
    this.manualDeliveryFee,
    this.manualDeliveryFeeReason,
    required this.timeline,
    this.shoppingItems = const <CustomerShoppingItemModel>[],
    this.shoppingStops = const <CustomerShoppingStopModel>[],
    OrderRouteModel? route,
    OrderRouteModel? shoppingRoute,
    this.shoppingPricing,
    this.proofs = const <CustomerOrderProofModel>[],
    this.paymentProofFeedback,
    this.driverEta,
    this.deliveryFeeNegotiation,
    this.shoppingNegotiation,
    this.shoppingCapabilities = const ShoppingOrderCapabilitiesModel(),
    this.shoppingItemChangeRequest,
  }) : route = route ?? shoppingRoute;

  OrderRouteModel? get shoppingRoute => route;

  bool get isShoppingOrder =>
      service_type.normalizeServiceTypeCode(summary.serviceTypeCode) ==
      service_type.ServiceTypeCodes.shopping;

  bool get canEditShoppingItems {
    if (!isShoppingOrder) {
      return false;
    }

    if (!shoppingCapabilities.isExplicit) {
      return order_status.normalizeOrderStatusCode(summary.statusCode) ==
          order_status.OrderStatusCodes.pending;
    }

    return shoppingCapabilities.canCustomerDirectEditItems;
  }

  bool get canRequestShoppingItemChange {
    if (!isShoppingOrder) {
      return false;
    }

    if (!shoppingCapabilities.isExplicit) {
      final normalized = order_status.normalizeOrderStatusCode(
        summary.statusCode,
      );
      return !hasPendingShoppingItemChangeRequest &&
          (normalized == order_status.OrderStatusCodes.driverAssigned ||
              normalized == order_status.OrderStatusCodes.arrivedMerchant);
    }

    return shoppingCapabilities.canCustomerRequestItemChange &&
        !hasPendingShoppingItemChangeRequest;
  }

  bool get canRequestAddShoppingStop {
    return false;
  }

  bool get canEditUnavailableShoppingItems {
    if (!isShoppingOrder) {
      return false;
    }

    if (!shoppingCapabilities.isExplicit) {
      final normalized = order_status.normalizeOrderStatusCode(
        summary.statusCode,
      );
      return !hasPendingShoppingItemChangeRequest &&
          normalized == order_status.OrderStatusCodes.arrivedMerchant &&
          shoppingItems.any((item) => !item.isAvailable);
    }

    return shoppingCapabilities.canCustomerEditUnavailableItems &&
        !hasPendingShoppingItemChangeRequest;
  }

  bool get hasPendingShoppingItemChangeRequest {
    return shoppingCapabilities.hasPendingItemChangeRequest ||
        shoppingItemChangeRequest?.isPending == true;
  }

  bool get isCancelledWithFee {
    return summary.hasCancelledWithFeeOutcome ||
        timeline.any(
          (entry) =>
              order_status.normalizeOrderStatusCode(entry.code) ==
              order_status.OrderStatusCodes.cancelledWithFee,
        );
  }

  String get shoppingServiceFeeLabel {
    return isCancelledWithFee ? 'Fee pembatalan' : 'Biaya layanan';
  }

  bool get canResolveFailedShoppingMerchant {
    return false;
  }

  bool get canAddShoppingMerchant {
    if (!isShoppingOrder) {
      return false;
    }

    final activeStopCount = shoppingStops.where((stop) => stop.isActive).length;
    if (activeStopCount >= 3) {
      return false;
    }

    if (!shoppingCapabilities.isExplicit) {
      return canEditShoppingItems;
    }

    return canEditShoppingItems &&
        shoppingCapabilities.canCustomerAddShoppingMerchant;
  }

  CustomerOrderDetailModel copyWith({
    CustomerOrderSummaryModel? summary,
    String? paymentStatus,
    String? paymentMethod,
    String? driverName,
    String? driverPhone,
    String? driverVehicleType,
    String? driverVehicleBrand,
    String? driverVehicleModel,
    String? driverVehiclePlate,
    String? driverAvatarUrl,
    String? pickupAddress,
    String? dropoffAddress,
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
    String? deliveryFeeChangeNote,
    double? manualDeliveryFee,
    String? manualDeliveryFeeReason,
    List<OrderStatusSnapshot>? timeline,
    List<CustomerShoppingItemModel>? shoppingItems,
    List<CustomerShoppingStopModel>? shoppingStops,
    OrderRouteModel? route,
    OrderRouteModel? shoppingRoute,
    CustomerShoppingPricingModel? shoppingPricing,
    List<CustomerOrderProofModel>? proofs,
    PaymentProofFeedbackModel? paymentProofFeedback,
    DriverEtaModel? driverEta,
    DeliveryFeeNegotiationModel? deliveryFeeNegotiation,
    ShoppingNegotiationModel? shoppingNegotiation,
    ShoppingOrderCapabilitiesModel? shoppingCapabilities,
    ShoppingItemChangeRequestModel? shoppingItemChangeRequest,
    bool clearDriverEta = false,
  }) {
    return CustomerOrderDetailModel(
      summary: summary ?? this.summary,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverVehicleType: driverVehicleType ?? this.driverVehicleType,
      driverVehicleBrand: driverVehicleBrand ?? this.driverVehicleBrand,
      driverVehicleModel: driverVehicleModel ?? this.driverVehicleModel,
      driverVehiclePlate: driverVehiclePlate ?? this.driverVehiclePlate,
      driverAvatarUrl: driverAvatarUrl ?? this.driverAvatarUrl,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
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
      deliveryFeeChangeNote:
          deliveryFeeChangeNote ?? this.deliveryFeeChangeNote,
      manualDeliveryFee: manualDeliveryFee ?? this.manualDeliveryFee,
      manualDeliveryFeeReason:
          manualDeliveryFeeReason ?? this.manualDeliveryFeeReason,
      timeline: timeline ?? this.timeline,
      shoppingItems: shoppingItems ?? this.shoppingItems,
      shoppingStops: shoppingStops ?? this.shoppingStops,
      route: route ?? shoppingRoute ?? this.route,
      shoppingPricing: shoppingPricing ?? this.shoppingPricing,
      proofs: proofs ?? this.proofs,
      paymentProofFeedback: paymentProofFeedback ?? this.paymentProofFeedback,
      driverEta: clearDriverEta ? null : (driverEta ?? this.driverEta),
      deliveryFeeNegotiation:
          deliveryFeeNegotiation ?? this.deliveryFeeNegotiation,
      shoppingNegotiation: shoppingNegotiation ?? this.shoppingNegotiation,
      shoppingCapabilities: shoppingCapabilities ?? this.shoppingCapabilities,
      shoppingItemChangeRequest:
          shoppingItemChangeRequest ?? this.shoppingItemChangeRequest,
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
    final driverLocation = (driver['location'] is Map<String, dynamic>)
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
    final pickupAddress = _firstNonEmptyString([
      pickupLocation?['full_address'],
      pickupLocation?['address'],
      json['pickup_address'],
      json['pickupAddress'],
      pickupSource['full_address'],
      pickupSource['address'],
    ]);
    final dropoffAddress = _firstNonEmptyString([
      dropoffLocation?['full_address'],
      dropoffLocation?['address'],
      json['dropoff_address'],
      json['dropoffAddress'],
      json['delivery_address'],
      json['deliveryAddress'],
    ]);
    final driverAvatar = _firstNonEmptyString([
      json['driver_avatar_url'],
      json['driverAvatarUrl'],
      driver['avatar_url'],
      driver['avatarUrl'],
      driver['avatar'],
      driverUser['avatar_url'],
      driverUser['avatarUrl'],
      driverUser['avatar'],
    ]);
    final driverLatitude = _asNullableDouble(
      json['driver_latitude'] ??
          json['driverLatitude'] ??
          driver['latitude'] ??
          driverLocation['latitude'],
    );
    final driverLongitude = _asNullableDouble(
      json['driver_longitude'] ??
          json['driverLongitude'] ??
          driver['longitude'] ??
          driverLocation['longitude'],
    );
    final driverLocationUpdatedAt = CustomerOrderSummaryModel._asDateTime(
      json['driver_location_updated_at'] ??
          json['driverLocationUpdatedAt'] ??
          driver['location_updated_at'] ??
          driver['locationUpdatedAt'] ??
          driverLocation['updated_at'] ??
          driverLocation['updatedAt'],
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
                label: order_status.orderStatusDisplayLabel(
                  code,
                  fallbackLabel: label,
                ),
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
    final route = OrderRouteModel.fromRaw(
      json['route'] ?? json['shopping_route'],
      shoppingOrder,
    );
    final distanceKm = CustomerOrderSummaryModel._distanceKmFromJson(
      json,
      route,
    );

    return CustomerOrderDetailModel(
      summary: summary,
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      driverName: driverUser['name']?.toString(),
      driverPhone: driverUser['phone']?.toString(),
      driverVehicleType: driver['vehicle_type']?.toString(),
      driverVehicleBrand: driver['vehicle_brand']?.toString(),
      driverVehicleModel: driver['vehicle_model']?.toString(),
      driverVehiclePlate: driver['vehicle_plate']?.toString(),
      driverAvatarUrl: driverAvatar == null
          ? null
          : AppEnv.resolveBackendAssetUrl(driverAvatar),
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
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
      driverLatitude: driverLatitude != null && _isValidLatitude(driverLatitude)
          ? driverLatitude
          : null,
      driverLongitude:
          driverLongitude != null && _isValidLongitude(driverLongitude)
          ? driverLongitude
          : null,
      driverLocationUpdatedAt: driverLocationUpdatedAt,
      deliveryDistanceText: CustomerOrderSummaryModel._distanceTextFromJson(
        json,
        route,
        distanceKm,
      ),
      deliveryDistanceKm: distanceKm,
      deliveryFeeSource: CustomerOrderSummaryModel._normalizeDeliveryFeeSource(
        json['delivery_fee_source'] ?? json['deliveryFeeSource'],
      ),
      deliveryFeeChangeNote: _firstNonEmptyString([
        json['delivery_fee_change_note'],
        json['deliveryFeeChangeNote'],
        json['delivery_fee_change_reason'],
        json['deliveryFeeChangeReason'],
      ]),
      manualDeliveryFee: null,
      manualDeliveryFeeReason: null,
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
      route: route,
      shoppingPricing: CustomerShoppingPricingModel.fromJson(
        json,
        shoppingOrder,
      ),
      proofs: CustomerOrderProofModel.parseList(
        json['proofs'] ?? json['order_proofs'] ?? json['attachments'],
      ),
      paymentProofFeedback: PaymentProofFeedbackModel.fromRaw(
        json['payment_proof_feedback'] ?? json['paymentProofFeedback'],
      ),
      driverEta: DriverEtaModel.fromRaw(
        json['driver_eta'] ?? json['driverEta'],
      ),
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

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '-') {
        return text;
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
    this.uploaderUserId,
    this.createdAt,
  });

  final int id;
  final String type;
  final String label;
  final String? photoUrl;
  final String? status;
  final String? note;
  final int? uploaderUserId;
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
      uploaderUserId: int.tryParse(
        (json['uploader_user_id'] ?? json['user_id'] ?? json['userId'])
                ?.toString() ??
            '',
      ),
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
        return 'Bukti QRIS';
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
  final String chainId;
  final int chainAttemptNo;
  final int chainFailedAttemptCount;
  final int chainFailedAttemptLimit;
  final int orderFailedTripCount;
  final int verifiedFailedTripCount;
  final bool compensationEligible;
  final int stateVersion;
  final CustomerShoppingMerchantModel merchant;
  final List<CustomerShoppingItemModel> items;
  final bool hasExplicitUnavailableItemActions;
  final bool canEditUnavailableItems;
  final bool canContinueWithoutUnavailableItem;
  final bool canCancelUnavailableMerchant;
  final bool canReplaceMerchant;
  final String? replacementBlockReason;
  final ShoppingPendingReplacementApproval? pendingReplacementApproval;

  const CustomerShoppingStopModel({
    required this.pickupLocationId,
    required this.sequenceNo,
    this.fulfillmentStatus = 'PENDING',
    this.failedAttemptCount = 0,
    this.chainId = '',
    this.chainAttemptNo = 1,
    this.chainFailedAttemptCount = 0,
    this.chainFailedAttemptLimit = 3,
    this.orderFailedTripCount = 0,
    this.verifiedFailedTripCount = 0,
    this.compensationEligible = false,
    this.stateVersion = 0,
    required this.merchant,
    required this.items,
    this.hasExplicitUnavailableItemActions = false,
    this.canEditUnavailableItems = false,
    this.canContinueWithoutUnavailableItem = false,
    this.canCancelUnavailableMerchant = false,
    this.canReplaceMerchant = false,
    this.replacementBlockReason,
    this.pendingReplacementApproval,
  });

  bool get isFailed => fulfillmentStatus.toUpperCase() == 'FAILED';
  bool get isSkipped => fulfillmentStatus.toUpperCase() == 'SKIPPED';
  bool get isReplaced => fulfillmentStatus.toUpperCase() == 'REPLACED';
  bool get isCompleted => fulfillmentStatus.toUpperCase() == 'COMPLETED';
  bool get isAbandoned =>
      fulfillmentStatus.toUpperCase() == 'ABANDONED_AFTER_LIMIT';
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
  bool get isActive => !isFailed && !isSkipped && !isReplaced && !isAbandoned;

  factory CustomerShoppingStopModel.fromJson(Map<String, dynamic> json) {
    final merchantJson = (json['merchant'] is Map<String, dynamic>)
        ? json['merchant'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawItems = (json['items'] is List)
        ? (json['items'] as List).whereType<Map<String, dynamic>>().toList(
            growable: false,
          )
        : const <Map<String, dynamic>>[];
    final rawUnavailableActions =
        json['unavailable_item_actions'] ?? json['unavailableItemActions'];
    final unavailableActions = rawUnavailableActions is Map<String, dynamic>
        ? rawUnavailableActions
        : const <String, dynamic>{};
    final hasExplicitUnavailableItemActions = unavailableActions.isNotEmpty;

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
      chainId: (json['chain_id'] ?? unavailableActions['chain_id'] ?? '')
          .toString(),
      chainAttemptNo: CustomerOrderSummaryModel._asInt(
        json['chain_attempt_no'] ?? unavailableActions['chain_attempt_no'] ?? 1,
      ),
      chainFailedAttemptCount: CustomerOrderSummaryModel._asInt(
        json['chain_failed_attempt_count'] ??
            unavailableActions['chain_failed_attempt_count'],
      ),
      chainFailedAttemptLimit:
          CustomerOrderSummaryModel._asInt(
                json['chain_failed_attempt_limit'] ??
                    unavailableActions['chain_failed_attempt_limit'] ??
                    3,
              ) <=
              0
          ? 3
          : CustomerOrderSummaryModel._asInt(
              json['chain_failed_attempt_limit'] ??
                  unavailableActions['chain_failed_attempt_limit'] ??
                  3,
            ),
      orderFailedTripCount: CustomerOrderSummaryModel._asInt(
        json['order_failed_trip_count'] ??
            unavailableActions['order_failed_trip_count'],
      ),
      verifiedFailedTripCount: CustomerOrderSummaryModel._asInt(
        json['verified_failed_trip_count'] ??
            unavailableActions['verified_failed_trip_count'],
      ),
      compensationEligible:
          json['compensation_eligible'] == true ||
          unavailableActions['compensation_eligible'] == true,
      stateVersion: CustomerOrderSummaryModel._asInt(
        json['state_version'] ?? unavailableActions['state_version'],
      ),
      merchant: CustomerShoppingMerchantModel.fromJson(merchantJson),
      items: rawItems
          .map(CustomerShoppingItemModel.fromJson)
          .toList(growable: false),
      hasExplicitUnavailableItemActions: hasExplicitUnavailableItemActions,
      canEditUnavailableItems:
          unavailableActions['can_edit'] == true ||
          unavailableActions['canEdit'] == true,
      canContinueWithoutUnavailableItem:
          unavailableActions['can_continue_without_item'] == true ||
          unavailableActions['canContinueWithoutItem'] == true,
      canCancelUnavailableMerchant:
          unavailableActions['can_cancel_merchant'] == true ||
          unavailableActions['canCancelMerchant'] == true,
      canReplaceMerchant:
          unavailableActions['can_customer_replace_merchant'] == true ||
          unavailableActions['canCustomerReplaceMerchant'] == true,
      replacementBlockReason:
          (unavailableActions['replacement_block_reason'] ??
                  unavailableActions['replacementBlockReason'])
              ?.toString(),
      pendingReplacementApproval: ShoppingPendingReplacementApproval.fromJson(
        unavailableActions['pending_replacement_approval'] ??
            unavailableActions['pendingReplacementApproval'],
      ),
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
  final double cancellationPenalty;
  final int failedAttemptCount;
  final int failedAttemptThreshold;
  final bool canCancelWithFee;

  const CustomerShoppingPricingModel({
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.totalPrice,
    required this.cancellationPenalty,
    this.failedAttemptCount = 0,
    this.failedAttemptThreshold = 3,
    this.canCancelWithFee = false,
  });

  factory CustomerShoppingPricingModel.fromJson(
    Map<String, dynamic> orderJson,
    Map<String, dynamic> shoppingJson,
  ) {
    final cancellationPenalty = CustomerOrderSummaryModel._asDouble(
      shoppingJson['cancellation_penalty'],
    );
    return CustomerShoppingPricingModel(
      subtotal: CustomerOrderSummaryModel._asDouble(orderJson['subtotal']),
      deliveryFee: CustomerOrderSummaryModel._asDouble(
        orderJson['delivery_fee'],
      ),
      serviceFee: CustomerOrderSummaryModel._asDouble(orderJson['service_fee']),
      totalPrice: CustomerOrderSummaryModel._asDouble(orderJson['total_price']),
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
    );
  }
}
