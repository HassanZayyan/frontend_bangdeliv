import '../config/app_env.dart';
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
    this.attachmentType,
    this.attachmentUrl,
    this.attachmentMimeType,
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
  final String? attachmentType;
  final String? attachmentUrl;
  final String? attachmentMimeType;
  final bool isPending;
  final bool isFailed;

  bool get hasServerId => id > 0;
  bool get hasAttachment => (attachmentUrl ?? '').trim().isNotEmpty;

  OrderChatMessageModel copyWith({
    int? id,
    int? orderId,
    int? senderUserId,
    String? senderRole,
    String? senderName,
    String? body,
    String? clientMessageId,
    DateTime? createdAt,
    String? attachmentType,
    String? attachmentUrl,
    String? attachmentMimeType,
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
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
    );
  }

  factory OrderChatMessageModel.fromJson(Map<String, dynamic> json) {
    final attachment = _extractAttachment(json);
    final rawAttachmentUrl =
        (attachment['url'] ??
                attachment['file_url'] ??
                attachment['photo_url'] ??
                attachment['path'] ??
                json['attachment_url'] ??
                '')
            .toString()
            .trim();

    return OrderChatMessageModel(
      id: _asInt(json['id']),
      orderId: _asInt(json['order_id'] ?? json['orderId']),
      senderUserId: _asInt(json['sender_user_id'] ?? json['senderUserId']),
      senderRole: (json['sender_role'] ?? json['senderRole'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      senderName:
          (json['sender_name'] ??
                  json['senderName'] ??
                  json['sender_name_snapshot'] ??
                  '')
              .toString()
              .trim(),
      body: (json['body'] ?? '').toString(),
      clientMessageId: _nullableString(
        json['client_message_id'] ?? json['clientMessageId'],
      ),
      createdAt: parseBackendDateTime(json['created_at'] ?? json['createdAt']),
      attachmentType: _nullableString(
        attachment['type'] ?? json['attachment_type'],
      ),
      attachmentUrl: rawAttachmentUrl.isEmpty
          ? null
          : AppEnv.resolveBackendAssetUrl(rawAttachmentUrl),
      attachmentMimeType: _nullableString(
        attachment['mime_type'] ?? json['attachment_mime_type'],
      ),
    );
  }

  static Map<String, dynamic> _extractAttachment(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'];
    if (rawAttachments is List && rawAttachments.isNotEmpty) {
      final first = rawAttachments.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
    }

    final rawAttachment = json['attachment'];
    if (rawAttachment is Map<String, dynamic>) {
      return rawAttachment;
    }

    return const <String, dynamic>{};
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
    required this.unreadCount,
    required this.lastReadMessageId,
  });

  final List<OrderChatMessageModel> messages;
  final bool canSend;
  final bool hasMore;
  final int? nextBeforeId;
  final int unreadCount;
  final int lastReadMessageId;

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
      unreadCount: _asInt(data['unread_count']),
      lastReadMessageId: _asInt(data['last_read_message_id']),
    );
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class OrderChatUnreadSummary {
  const OrderChatUnreadSummary({
    required this.unreadCount,
    required this.lastReadMessageId,
  });

  final int unreadCount;
  final int lastReadMessageId;

  factory OrderChatUnreadSummary.fromApiJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return OrderChatUnreadSummary(
      unreadCount: OrderChatMessagesPage._asInt(data['unread_count']),
      lastReadMessageId: OrderChatMessagesPage._asInt(
        data['last_read_message_id'],
      ),
    );
  }
}

class OrderChatSendResult {
  const OrderChatSendResult({required this.message, required this.canSend});

  final OrderChatMessageModel message;
  final bool canSend;

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
    );
  }
}
