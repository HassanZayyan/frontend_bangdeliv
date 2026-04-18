enum ChatbotIntent { pesanMakanan, courierOrder, outOfDomain, unknown }

class ChatbotOrderItem {
  final String menu;
  final int qty;

  const ChatbotOrderItem({required this.menu, required this.qty});
}

class ChatbotMatchedItem {
  final int? menuId;
  final String menuName;
  final int qty;
  final int? restaurantId;
  final String? restaurantName;

  const ChatbotMatchedItem({
    required this.menuId,
    required this.menuName,
    required this.qty,
    required this.restaurantId,
    required this.restaurantName,
  });
}

class ChatbotValidation {
  final bool isValidOrder;
  final List<String> rejectionReasons;
  final List<String> missingFields;
  final List<String> nextActions;
  final String? matchedRestaurantName;
  final List<ChatbotMatchedItem> matchedItems;
  final List<ChatbotOrderItem> unmatchedItems;

  const ChatbotValidation({
    required this.isValidOrder,
    required this.rejectionReasons,
    required this.missingFields,
    required this.nextActions,
    required this.matchedRestaurantName,
    required this.matchedItems,
    required this.unmatchedItems,
  });
}

class ChatbotResult {
  final ChatbotIntent intent;
  final String? resto;
  final List<ChatbotOrderItem> items;
  final String? modelUsed;
  final ChatbotValidation? validation;
  final String? assistantText;
  final bool isOrderCreated;
  final int? createdOrderId;
  final String? createdOrderNumber;
  final String? createdOrderStatus;

  const ChatbotResult({
    required this.intent,
    required this.resto,
    required this.items,
    required this.modelUsed,
    required this.validation,
    required this.assistantText,
    required this.isOrderCreated,
    required this.createdOrderId,
    required this.createdOrderNumber,
    required this.createdOrderStatus,
  });

  factory ChatbotResult.fromApiJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final intentValue = data['intent']?.toString().toLowerCase() ?? '';
    final intent = switch (intentValue) {
      'pesan_makanan' => ChatbotIntent.pesanMakanan,
      'courier_order' => ChatbotIntent.courierOrder,
      'out_of_domain' => ChatbotIntent.outOfDomain,
      _ => ChatbotIntent.unknown,
    };

    final rawItems = (data['items'] is List<dynamic>)
        ? data['items'] as List<dynamic>
        : const <dynamic>[];

    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ChatbotOrderItem(
            menu: item['menu']?.toString() ?? '-',
            qty: int.tryParse(item['qty']?.toString() ?? '') ?? 1,
          ),
        )
        .toList(growable: false);

    final validationRaw = (data['validation'] is Map<String, dynamic>)
        ? data['validation'] as Map<String, dynamic>
        : null;

    final validation = validationRaw == null
        ? null
        : _parseValidation(validationRaw);

    final orderRaw = (data['order'] is Map<String, dynamic>)
        ? data['order'] as Map<String, dynamic>
        : <String, dynamic>{};

    final isOrderCreated = orderRaw['created'] == true;

    return ChatbotResult(
      intent: intent,
      resto: data['resto']?.toString(),
      items: items,
      modelUsed: json['model_used']?.toString(),
      validation: validation,
      assistantText: data['assistant_text']?.toString(),
      isOrderCreated: isOrderCreated,
      createdOrderId: int.tryParse(orderRaw['id']?.toString() ?? ''),
      createdOrderNumber: orderRaw['order_number']?.toString(),
      createdOrderStatus: orderRaw['status']?.toString(),
    );
  }

  static ChatbotValidation _parseValidation(Map<String, dynamic> json) {
    final reasonsRaw = (json['rejection_reasons'] is List<dynamic>)
        ? json['rejection_reasons'] as List<dynamic>
        : const <dynamic>[];
    final reasons = reasonsRaw
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);

    final missingFieldsRaw = (json['missing_fields'] is List<dynamic>)
      ? json['missing_fields'] as List<dynamic>
      : const <dynamic>[];
    final missingFields = missingFieldsRaw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

    final nextActionsRaw = (json['next_actions'] is List<dynamic>)
      ? json['next_actions'] as List<dynamic>
      : const <dynamic>[];
    final nextActions = nextActionsRaw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

    final matchedRestaurant =
        (json['matched_restaurant'] is Map<String, dynamic>)
        ? json['matched_restaurant'] as Map<String, dynamic>
        : null;

    final matchedItemsRaw = (json['matched_items'] is List<dynamic>)
        ? json['matched_items'] as List<dynamic>
        : const <dynamic>[];
    final matchedItems = matchedItemsRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ChatbotMatchedItem(
            menuId: int.tryParse(item['menu_id']?.toString() ?? ''),
            menuName: item['menu_name']?.toString() ?? '-',
            qty: int.tryParse(item['qty']?.toString() ?? '') ?? 1,
            restaurantId: int.tryParse(item['restaurant_id']?.toString() ?? ''),
            restaurantName: item['restaurant_name']?.toString(),
          ),
        )
        .toList(growable: false);

    final unmatchedItemsRaw = (json['unmatched_items'] is List<dynamic>)
        ? json['unmatched_items'] as List<dynamic>
        : const <dynamic>[];
    final unmatchedItems = unmatchedItemsRaw
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ChatbotOrderItem(
            menu: item['menu']?.toString() ?? '-',
            qty: int.tryParse(item['qty']?.toString() ?? '') ?? 1,
          ),
        )
        .toList(growable: false);

    return ChatbotValidation(
      isValidOrder: json['is_valid_order'] == true,
      rejectionReasons: reasons,
      missingFields: missingFields,
      nextActions: nextActions,
      matchedRestaurantName: matchedRestaurant?['name']?.toString(),
      matchedItems: matchedItems,
      unmatchedItems: unmatchedItems,
    );
  }

  String toAssistantText() {
    final backendMessage = assistantText?.trim() ?? '';
    if (backendMessage.isNotEmpty) {
      return backendMessage;
    }

    if (intent == ChatbotIntent.courierOrder) {
      if (isOrderCreated) {
        if (createdOrderNumber != null &&
            createdOrderNumber!.trim().isNotEmpty) {
          return 'Order kurir berhasil dibuat dengan nomor $createdOrderNumber.';
        }
        return 'Order kurir berhasil dibuat.';
      }

      if (validation != null && validation!.rejectionReasons.isNotEmpty) {
        final buffer = StringBuffer('Order kurir belum bisa dibuat karena:\n');
        for (final reason in validation!.rejectionReasons) {
          buffer.writeln('- $reason');
        }
        return buffer.toString().trimRight();
      }

      return 'Data kurir belum lengkap. Mohon isi lokasi ambil, tujuan kirim, dan isi paket.';
    }

    if (intent == ChatbotIntent.outOfDomain) {
      return 'Aku fokus bantu pemesanan makanan. Coba tulis menu dan jumlahnya, ya.';
    }

    if (validation != null && !validation!.isValidOrder) {
      final buffer = StringBuffer(
        'Maaf, pesananmu belum bisa diproses karena:\n',
      );

      for (final reason in validation!.rejectionReasons) {
        buffer.writeln('- $reason');
      }

      if (validation!.unmatchedItems.isNotEmpty) {
        buffer.writeln('- Menu yang belum ditemukan:');
        for (final item in validation!.unmatchedItems) {
          buffer.writeln('  • ${item.qty}x ${item.menu}');
        }
      }

      buffer.write('\nCoba pilih menu/resto yang tersedia di aplikasi, ya.');

      return buffer.toString().trimRight();
    }

    if (validation != null && validation!.matchedItems.isNotEmpty) {
      final buffer = StringBuffer('Siap, pesananmu valid dan tersedia:\n');

      for (final item in validation!.matchedItems) {
        buffer.writeln('- ${item.qty}x ${item.menuName}');
      }

      if (validation!.matchedRestaurantName != null &&
          validation!.matchedRestaurantName!.trim().isNotEmpty) {
        buffer.write('\nResto: ${validation!.matchedRestaurantName}');
      }

      return buffer.toString().trimRight();
    }

    if (items.isEmpty) {
      return 'Aku belum menangkap item pesananmu. Coba tulis seperti: "2 ayam geprek, 1 es teh".';
    }

    final buffer = StringBuffer('Siap, aku tangkap pesananmu:\n');

    for (final item in items) {
      buffer.writeln('- ${item.qty}x ${item.menu}');
    }

    if (resto != null && resto!.trim().isNotEmpty && resto != 'null') {
      buffer.write('\nResto tujuan: $resto');
    }

    return buffer.toString().trimRight();
  }
}
