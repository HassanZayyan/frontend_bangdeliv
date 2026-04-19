class OrderStatusSnapshot {
  final String code;
  final String label;
  final DateTime? changedAt;

  const OrderStatusSnapshot({
    required this.code,
    required this.label,
    required this.changedAt,
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

  bool get isCompleted => statusCode == 'COMPLETED';

  bool get isCancelled =>
      statusCode == 'CANCELLED' || statusCode == 'CANCELLED_WITH_FEE';

  bool get canTrack => !isTerminalStatus;

  bool get canCancel =>
      statusCode == 'PENDING' || statusCode == 'DRIVER_ASSIGNED';

  factory CustomerOrderSummaryModel.fromJson(Map<String, dynamic> json) {
    final status = _extractStatus(json);
    final serviceType = _extractServiceType(json);

    return CustomerOrderSummaryModel(
      id: _asInt(json['id']),
      orderNumber: (json['order_number'] ?? '-').toString(),
      serviceTypeCode: serviceType['code']!,
      serviceTypeLabel: serviceType['label']!,
      restaurantName: _extractRestaurantName(json, serviceType['label']!),
      itemsSummary: _extractItemsSummary(json),
      totalAmount: _asDouble(json['total_amount'] ?? json['total_price']),
      statusCode: status['code']!,
      statusLabel: status['label']!,
      isTerminalStatus: status['isTerminal'] == 'true',
      createdAt: _asDateTime(json['created_at']),
      estimatedDelivery: _asDateTime(json['estimated_delivery']),
      deliveryAddress: (json['delivery_address'] ?? '-').toString(),
    );
  }

  static Map<String, String> _extractServiceType(Map<String, dynamic> json) {
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

    final normalizedCode = _normalizeServiceTypeCode(
      codeFromObject.isNotEmpty
          ? codeFromObject
          : (codeFromPayload.isNotEmpty ? codeFromPayload : rawString),
    );

    final preferredLabel = labelFromObject.isNotEmpty
        ? labelFromObject
        : (labelFromPayload.isNotEmpty ? labelFromPayload : rawString);

    final fallbackLabel = _serviceTypeLabelFromCode(normalizedCode);

    return <String, String>{
      'code': normalizedCode,
      'label': preferredLabel.isNotEmpty
          ? _serviceTypeLabelFromCode(_normalizeServiceTypeCode(preferredLabel))
          : fallbackLabel,
    };
  }

  static Map<String, String> _extractStatus(Map<String, dynamic> json) {
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

    return <String, String>{
      'code': fallbackCode,
      'label': displayName.isNotEmpty
          ? displayName
          : _statusLabelFromCode(fallbackCode),
      'isTerminal': (isTerminal || _isTerminalCode(fallbackCode)).toString(),
    };
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

  static bool _isTerminalCode(String code) {
    return code == 'COMPLETED' ||
        code == 'CANCELLED' ||
        code == 'CANCELLED_WITH_FEE';
  }

  static String _normalizeServiceTypeCode(String raw) {
    final normalized = raw
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    switch (normalized) {
      case 'RIDE':
      case 'ANTAR_JEMPUT':
      case 'ANTAR_JEMPUT_ORANG':
        return 'RIDE';
      case 'COURIER':
      case 'KURIR':
      case 'ANTAR_BARANG':
        return 'COURIER';
      case 'SHOPPING':
      case 'NITIP':
      case 'TITIP_BELANJA':
        return 'SHOPPING';
      default:
        return normalized.isEmpty ? 'UNKNOWN' : normalized;
    }
  }

  static String _serviceTypeLabelFromCode(String code) {
    switch (_normalizeServiceTypeCode(code)) {
      case 'RIDE':
        return 'Antar Jemput';
      case 'COURIER':
        return 'Kurir';
      case 'SHOPPING':
        return 'Titip';
      default:
        return 'Layanan Bangdeliv';
    }
  }

  static String _statusLabelFromCode(String code) {
    switch (code) {
      case 'PENDING':
        return 'Menunggu Driver';
      case 'DRIVER_ASSIGNED':
        return 'Driver Ditugaskan';
      case 'PICKED_UP':
        return 'Pesanan Diambil';
      case 'ON_THE_WAY':
        return 'Dalam Perjalanan';
      case 'DELIVERED':
        return 'Sudah Sampai Tujuan';
      case 'COMPLETED':
        return 'Selesai';
      case 'CANCELLED':
        return 'Dibatalkan';
      case 'CANCELLED_WITH_FEE':
        return 'Dibatalkan Dengan Biaya';
      default:
        return code.isEmpty ? 'Status Tidak Diketahui' : code;
    }
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

    return DateTime.tryParse(raw);
  }
}

class CustomerOrderDetailModel {
  final CustomerOrderSummaryModel summary;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? notes;
  final String? driverName;
  final String? deliveryDistanceText;
  final List<OrderStatusSnapshot> timeline;

  const CustomerOrderDetailModel({
    required this.summary,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.notes,
    required this.driverName,
    required this.deliveryDistanceText,
    required this.timeline,
  });

  factory CustomerOrderDetailModel.fromJson(Map<String, dynamic> json) {
    final summary = CustomerOrderSummaryModel.fromJson(json);

    final driver = (json['driver'] is Map<String, dynamic>)
        ? json['driver'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final driverUser = (driver['user'] is Map<String, dynamic>)
        ? driver['user'] as Map<String, dynamic>
        : const <String, dynamic>{};

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
                    : CustomerOrderSummaryModel._statusLabelFromCode(code),
                changedAt: CustomerOrderSummaryModel._asDateTime(
                  history['created_at'] ?? history['updated_at'],
                ),
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final aTime = a.changedAt?.millisecondsSinceEpoch ?? 0;
            final bTime = b.changedAt?.millisecondsSinceEpoch ?? 0;
            return aTime.compareTo(bTime);
          });

    return CustomerOrderDetailModel(
      summary: summary,
      paymentStatus: json['payment_status']?.toString(),
      paymentMethod: json['payment_method']?.toString(),
      notes: json['notes']?.toString(),
      driverName: driverUser['name']?.toString(),
      deliveryDistanceText: json['delivery_distance_text']?.toString(),
      timeline: timeline,
    );
  }
}
