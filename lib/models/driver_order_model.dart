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
