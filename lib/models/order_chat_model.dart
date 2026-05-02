import '../utils/order_formatters.dart';

class OrderChatMessageModel {
  const OrderChatMessageModel({
    required this.id,
    required this.orderId,
    required this.senderUserId,
    required this.senderRole,
    required this.senderName,
    required this.body,
    required this.clientMessageId,
    required this.createdAt,
    this.isPending = false,
    this.isFailed = false,
  });

  final int id;
  final int orderId;
  final int senderUserId;
  final String senderRole;
  final String senderName;
  final String body;
  final String? clientMessageId;
  final DateTime? createdAt;
  final bool isPending;
  final bool isFailed;

  bool get hasServerId => id > 0;

  OrderChatMessageModel copyWith({
    int? id,
    int? orderId,
    int? senderUserId,
    String? senderRole,
    String? senderName,
    String? body,
    String? clientMessageId,
    DateTime? createdAt,
    bool? isPending,
    bool? isFailed,
  }) {
    return OrderChatMessageModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      senderUserId: senderUserId ?? this.senderUserId,
      senderRole: senderRole ?? this.senderRole,
      senderName: senderName ?? this.senderName,
      body: body ?? this.body,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  factory OrderChatMessageModel.fromJson(Map<String, dynamic> json) {
    return OrderChatMessageModel(
      id: _asInt(json['id']),
      orderId: _asInt(json['order_id'] ?? json['orderId']),
      senderUserId: _asInt(
        json['sender_user_id'] ?? json['senderUserId'],
      ),
      senderRole: (json['sender_role'] ?? json['senderRole'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      senderName: (json['sender_name'] ??
              json['senderName'] ??
              json['sender_name_snapshot'] ??
              '')
          .toString()
          .trim(),
      body: (json['body'] ?? '').toString(),
      clientMessageId: _nullableString(
        json['client_message_id'] ?? json['clientMessageId'],
      ),
      createdAt: parseBackendDateTime(
        json['created_at'] ?? json['createdAt'],
      ),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    return raw.isEmpty ? null : raw;
  }
}

class OrderChatMessagesPage {
  const OrderChatMessagesPage({
    required this.messages,
    required this.canSend,
    required this.hasMore,
    required this.nextBeforeId,
  });

  final List<OrderChatMessageModel> messages;
  final bool canSend;
  final bool hasMore;
  final int? nextBeforeId;

  factory OrderChatMessagesPage.fromApiJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawMessages = (data['messages'] is List)
        ? data['messages'] as List
        : const <dynamic>[];
    final pagination = (data['pagination'] is Map<String, dynamic>)
        ? data['pagination'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return OrderChatMessagesPage(
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(OrderChatMessageModel.fromJson)
          .toList(growable: false),
      canSend: data['can_send'] == true,
      hasMore: pagination['has_more'] == true,
      nextBeforeId: _asNullableInt(pagination['next_before_id']),
    );
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class OrderChatSendResult {
  const OrderChatSendResult({
    required this.message,
    required this.canSend,
    this.broadcasted = true,
  });

  final OrderChatMessageModel message;
  final bool canSend;
  final bool broadcasted;

  factory OrderChatSendResult.fromApiJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final rawMessage = (data['message'] is Map<String, dynamic>)
        ? data['message'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return OrderChatSendResult(
      message: OrderChatMessageModel.fromJson(rawMessage),
      canSend: data['can_send'] == true,
      broadcasted: data.containsKey('broadcasted')
          ? data['broadcasted'] == true
          : true,
    );
  }
}
