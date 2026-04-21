class DriverOrderModel {
  final String id;
  final String customerName;
  final String pickupAddress;
  final String dropoffAddress;
  final int etaMinutes;
  final int fee;
  final int itemCount;
  final String? acceptedAt;

  const DriverOrderModel({
    required this.id,
    required this.customerName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.etaMinutes,
    required this.fee,
    required this.itemCount,
    this.acceptedAt,
  });

  DriverOrderModel copyWith({String? acceptedAt}) {
    return DriverOrderModel(
      id: id,
      customerName: customerName,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      etaMinutes: etaMinutes,
      fee: fee,
      itemCount: itemCount,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  factory DriverOrderModel.fromJson(Map<String, dynamic> json) {
    return DriverOrderModel(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customer_name'] ?? json['customerName'] ?? '-')
          .toString(),
      pickupAddress: (json['pickup_address'] ?? json['pickupAddress'] ?? '-')
          .toString(),
      dropoffAddress: (json['dropoff_address'] ?? json['dropoffAddress'] ?? '-')
          .toString(),
      etaMinutes: _asInt(
        json['eta_minutes'] ?? json['etaMinutes'],
        fallback: 0,
      ),
      fee: _asInt(json['fee'], fallback: 0),
      itemCount: _asInt(json['item_count'] ?? json['itemCount'], fallback: 0),
      acceptedAt:
          json['accepted_at']?.toString() ?? json['acceptedAt']?.toString(),
    );
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
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
