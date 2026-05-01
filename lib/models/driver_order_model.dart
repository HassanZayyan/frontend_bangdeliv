import '../utils/order_status.dart';
import '../utils/service_type.dart';

/// Represents a single action available to the driver, as returned by the backend.
class DriverOrderAction {
  final String actionCode;
  final String label;
  final String? targetStatusCode;
  final bool blocked;
  final String? blockedReason;

  const DriverOrderAction({
    required this.actionCode,
    required this.label,
    this.targetStatusCode,
    this.blocked = false,
    this.blockedReason,
  });

  factory DriverOrderAction.fromJson(Map<String, dynamic> json) {
    return DriverOrderAction(
      actionCode: normalizeOrderStatusCode(json['action_code']?.toString()),
      label: (json['label'] ?? json['action_code'] ?? '-').toString(),
      targetStatusCode: json['target_status_code']?.toString(),
      blocked: json['blocked'] == true,
      blockedReason: json['blocked_reason']?.toString(),
    );
  }
}

class DriverOrderModel {
  final String id;
  final String customerName;
  final String pickupAddress;
  final String dropoffAddress;
  final double? dropoffLatitude;
  final double? dropoffLongitude;
  final int etaMinutes;
  final int fee;
  final int itemCount;
  final String? acceptedAt;
  final String statusCode;
  final String serviceTypeCode;
  final List<DriverOrderAction> availableActions;

  const DriverOrderModel({
    required this.id,
    required this.customerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.dropoffLatitude,
    this.dropoffLongitude,
    required this.etaMinutes,
    required this.fee,
    required this.itemCount,
    this.acceptedAt,
    this.statusCode = 'UNKNOWN',
    this.serviceTypeCode = '',
    this.availableActions = const [],
  });

  DriverOrderModel copyWith({
    String? acceptedAt,
    String? statusCode,
    List<DriverOrderAction>? availableActions,
  }) {
    return DriverOrderModel(
      id: id,
      customerName: customerName,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      dropoffLatitude: dropoffLatitude,
      dropoffLongitude: dropoffLongitude,
      etaMinutes: etaMinutes,
      fee: fee,
      itemCount: itemCount,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      statusCode: statusCode ?? this.statusCode,
      serviceTypeCode: serviceTypeCode,
      availableActions: availableActions ?? this.availableActions,
    );
  }

  factory DriverOrderModel.fromJson(Map<String, dynamic> json) {
    final rawActions = json['available_actions'];
    final actions = <DriverOrderAction>[];
    if (rawActions is List) {
      for (final item in rawActions) {
        if (item is Map<String, dynamic>) {
          actions.add(DriverOrderAction.fromJson(item));
        }
      }
    }

    return DriverOrderModel(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customer_name'] ?? json['customerName'] ?? '-')
          .toString(),
      pickupAddress: (json['pickup_address'] ?? json['pickupAddress'] ?? '-')
          .toString(),
      dropoffAddress: (json['dropoff_address'] ?? json['dropoffAddress'] ?? '-')
          .toString(),
      dropoffLatitude: _asDouble(
        json['dropoff_latitude'] ?? json['dropoffLatitude'],
      ),
      dropoffLongitude: _asDouble(
        json['dropoff_longitude'] ?? json['dropoffLongitude'],
      ),
      etaMinutes: _asInt(
        json['eta_minutes'] ?? json['etaMinutes'],
        fallback: 0,
      ),
      fee: _asInt(json['fee'], fallback: 0),
      itemCount: _asInt(json['item_count'] ?? json['itemCount'], fallback: 0),
      acceptedAt:
          json['accepted_at']?.toString() ?? json['acceptedAt']?.toString(),
      statusCode: normalizeOrderStatusCode(
        (json['status_code'] ?? json['status'] ?? 'UNKNOWN').toString(),
      ),
      serviceTypeCode: normalizeServiceTypeCode(
        (json['service_type_code'] ?? '').toString(),
      ),
      availableActions: actions,
    );
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
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
      date: DateTime.tryParse(rawDate) ?? DateTime.now(),
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
