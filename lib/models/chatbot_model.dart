enum ChatbotIntent {
  pesanMakanan,
  shoppingOrder,
  courierOrder,
  rideOrder,
  outOfDomain,
  unknown,
}

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

class ChatbotShoppingItem {
  final int? id;
  final int? menuId;
  final String itemSource;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final bool isAvailable;
  final String? notes;

  const ChatbotShoppingItem({
    this.id,
    this.menuId,
    required this.itemSource,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    required this.isAvailable,
    this.notes,
  });

  factory ChatbotShoppingItem.fromJson(Map<String, dynamic> json) {
    return ChatbotShoppingItem(
      id: int.tryParse(json['id']?.toString() ?? ''),
      menuId: int.tryParse(json['menu_id']?.toString() ?? ''),
      itemSource: (json['item_source'] ?? 'MANUAL').toString(),
      name: (json['name'] ?? json['menu_name'] ?? '-').toString(),
      quantity: int.tryParse(json['quantity']?.toString() ?? '') ?? 1,
      unitPrice: _asDouble(json['unit_price']),
      subtotal: _asDouble(json['subtotal'] ?? json['line_total']),
      isAvailable: json['is_available'] != false,
      notes: json['notes']?.toString(),
    );
  }
}

class ChatbotShoppingStop {
  final int index;
  final bool isActive;
  final bool ready;
  final Map<String, dynamic>? merchant;
  final List<ChatbotShoppingItem> items;

  const ChatbotShoppingStop({
    required this.index,
    required this.isActive,
    required this.ready,
    required this.merchant,
    required this.items,
  });

  factory ChatbotShoppingStop.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] is List<dynamic>)
        ? json['items'] as List<dynamic>
        : const <dynamic>[];

    return ChatbotShoppingStop(
      index: int.tryParse(json['index']?.toString() ?? '') ?? 1,
      isActive: json['is_active'] == true,
      ready: json['ready'] == true,
      merchant: (json['merchant'] is Map<String, dynamic>)
          ? json['merchant'] as Map<String, dynamic>
          : null,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ChatbotShoppingItem.fromJson)
          .toList(growable: false),
    );
  }
}

class ChatbotShoppingDraft {
  final Map<String, dynamic>? merchant;
  final Map<String, dynamic>? delivery;
  final List<ChatbotShoppingItem> items;
  final List<ChatbotShoppingStop> stops;
  final bool readyToConfirm;
  final String? paymentMethod;

  const ChatbotShoppingDraft({
    required this.merchant,
    required this.delivery,
    required this.items,
    required this.stops,
    required this.readyToConfirm,
    required this.paymentMethod,
  });

  factory ChatbotShoppingDraft.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] is List<dynamic>)
        ? json['items'] as List<dynamic>
        : const <dynamic>[];
    final rawStops = (json['stops'] is List<dynamic>)
        ? json['stops'] as List<dynamic>
        : const <dynamic>[];

    return ChatbotShoppingDraft(
      merchant: (json['merchant'] is Map<String, dynamic>)
          ? json['merchant'] as Map<String, dynamic>
          : null,
      delivery: (json['delivery'] is Map<String, dynamic>)
          ? json['delivery'] as Map<String, dynamic>
          : null,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ChatbotShoppingItem.fromJson)
          .toList(growable: false),
      stops: rawStops
          .whereType<Map<String, dynamic>>()
          .map(ChatbotShoppingStop.fromJson)
          .toList(growable: false),
      readyToConfirm: json['ready_to_confirm'] == true,
      paymentMethod: json['payment_method']?.toString(),
    );
  }
}

class ChatbotTransportDraft {
  final bool readyToConfirm;
  final String? paymentMethod;

  const ChatbotTransportDraft({
    required this.readyToConfirm,
    required this.paymentMethod,
  });

  factory ChatbotTransportDraft.fromJson(Map<String, dynamic> json) {
    return ChatbotTransportDraft(
      readyToConfirm: json['ready_to_confirm'] == true,
      paymentMethod: json['payment_method']?.toString(),
    );
  }
}

class ChatbotPricing {
  final double subtotal;
  final double deliveryFee;
  final double serviceFee;
  final double totalPrice;

  const ChatbotPricing({
    required this.subtotal,
    required this.deliveryFee,
    required this.serviceFee,
    required this.totalPrice,
  });

  factory ChatbotPricing.fromJson(Map<String, dynamic> json) {
    return ChatbotPricing(
      subtotal: _asDouble(json['subtotal']),
      deliveryFee: _asDouble(json['delivery_fee']),
      serviceFee: _asDouble(json['service_fee']),
      totalPrice: _asDouble(json['total_price']),
    );
  }
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

/// Sinyal dari backend agar frontend membuka menu selector untuk resto terdaftar
/// (mis. balasan `Lihat menu [resto]`).
class ChatbotMenuSelectorRequest {
  const ChatbotMenuSelectorRequest({
    required this.merchantId,
    required this.merchantName,
    required this.mode,
  });

  final int merchantId;
  final String merchantName;
  final String mode;

  static ChatbotMenuSelectorRequest? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final merchantId = int.tryParse(raw['merchant_id']?.toString() ?? '');
    final merchantName = raw['merchant_name']?.toString().trim();
    if (merchantId == null || merchantName == null || merchantName.isEmpty) {
      return null;
    }
    final mode = raw['mode']?.toString().trim();
    return ChatbotMenuSelectorRequest(
      merchantId: merchantId,
      merchantName: merchantName,
      mode: (mode == null || mode.isEmpty) ? 'select' : mode,
    );
  }
}

class ChatbotResult {
  final String? sessionId;
  final String? serviceType;
  final ChatbotIntent intent;
  final String? resto;
  final List<ChatbotOrderItem> items;
  final String? modelUsed;
  final ChatbotValidation? validation;
  final Map<String, dynamic>? actionPayloads;
  final String? assistantText;
  final ChatbotShoppingDraft? shopping;
  final ChatbotTransportDraft? ride;
  final ChatbotTransportDraft? courier;
  final ChatbotPricing? pricing;
  final bool isOrderCreated;
  final int? createdOrderId;
  final String? createdOrderNumber;
  final String? createdOrderStatus;
  final ChatbotMenuSelectorRequest? menuSelector;

  const ChatbotResult({
    required this.sessionId,
    required this.serviceType,
    required this.intent,
    required this.resto,
    required this.items,
    required this.modelUsed,
    required this.validation,
    required this.actionPayloads,
    required this.assistantText,
    required this.shopping,
    required this.ride,
    required this.courier,
    required this.pricing,
    required this.isOrderCreated,
    required this.createdOrderId,
    required this.createdOrderNumber,
    required this.createdOrderStatus,
    this.menuSelector,
  });

  factory ChatbotResult.fromApiJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final intentValue = data['intent']?.toString().toLowerCase() ?? '';
    final intent = switch (intentValue) {
      'pesan_makanan' => ChatbotIntent.pesanMakanan,
      'shopping_order' => ChatbotIntent.shoppingOrder,
      'courier_order' => ChatbotIntent.courierOrder,
      'ride_order' => ChatbotIntent.rideOrder,
      'out_of_domain' => ChatbotIntent.outOfDomain,
      _ => ChatbotIntent.unknown,
    };

    final shoppingRaw = (data['shopping'] is Map<String, dynamic>)
        ? data['shopping'] as Map<String, dynamic>
        : null;
    final rideRaw = (data['ride'] is Map<String, dynamic>)
        ? data['ride'] as Map<String, dynamic>
        : null;
    final courierRaw = (data['courier'] is Map<String, dynamic>)
        ? data['courier'] as Map<String, dynamic>
        : null;

    final rawItems = (data['items'] is List<dynamic>)
        ? data['items'] as List<dynamic>
        : (shoppingRaw?['items'] is List<dynamic>)
        ? shoppingRaw!['items'] as List<dynamic>
        : const <dynamic>[];

    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ChatbotOrderItem(
            menu: (item['menu'] ?? item['name'] ?? item['menu_name'] ?? '-')
                .toString(),
            qty:
                int.tryParse(
                  (item['qty'] ?? item['quantity'])?.toString() ?? '',
                ) ??
                1,
          ),
        )
        .toList(growable: false);

    final validationRaw = (data['validation'] is Map<String, dynamic>)
        ? data['validation'] as Map<String, dynamic>
        : null;

    final validation = validationRaw == null
        ? null
        : _parseValidation(validationRaw);

    final actionPayloads = (data['action_payloads'] is Map<String, dynamic>)
        ? data['action_payloads'] as Map<String, dynamic>
        : null;

    final serviceContext = (json['service_context'] is Map<String, dynamic>)
        ? json['service_context'] as Map<String, dynamic>
        : <String, dynamic>{};

    final orderRaw = (data['order'] is Map<String, dynamic>)
        ? data['order'] as Map<String, dynamic>
        : <String, dynamic>{};

    final isOrderCreated = orderRaw['created'] == true;

    return ChatbotResult(
      sessionId: json['session_id']?.toString(),
      serviceType: serviceContext['service_type']?.toString(),
      intent: intent,
      resto: data['resto']?.toString(),
      items: items,
      modelUsed: json['model_used']?.toString(),
      validation: validation,
      actionPayloads: actionPayloads,
      assistantText: data['assistant_text']?.toString(),
      shopping: shoppingRaw == null
          ? null
          : ChatbotShoppingDraft.fromJson(shoppingRaw),
      ride: rideRaw == null ? null : ChatbotTransportDraft.fromJson(rideRaw),
      courier: courierRaw == null
          ? null
          : ChatbotTransportDraft.fromJson(courierRaw),
      pricing: (data['pricing'] is Map<String, dynamic>)
          ? ChatbotPricing.fromJson(data['pricing'] as Map<String, dynamic>)
          : null,
      isOrderCreated: isOrderCreated,
      createdOrderId: int.tryParse(orderRaw['id']?.toString() ?? ''),
      createdOrderNumber: orderRaw['order_number']?.toString(),
      createdOrderStatus: orderRaw['status']?.toString(),
      menuSelector: ChatbotMenuSelectorRequest.fromJson(data['menu_selector']),
    );
  }

  bool get draftReadyToConfirm {
    return shopping?.readyToConfirm == true ||
        ride?.readyToConfirm == true ||
        courier?.readyToConfirm == true ||
        validation?.isValidOrder == true;
  }

  String? get draftPaymentMethod {
    return shopping?.paymentMethod ??
        ride?.paymentMethod ??
        courier?.paymentMethod;
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
      return normalizeAssistantCopy(backendMessage, serviceType: serviceType);
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

    if (intent == ChatbotIntent.shoppingOrder) {
      if (isOrderCreated) {
        return createdOrderNumber != null &&
                createdOrderNumber!.trim().isNotEmpty
            ? 'Order Nitip berhasil dibuat dengan nomor $createdOrderNumber.'
            : 'Order Nitip berhasil dibuat.';
      }

      if (validation != null && validation!.rejectionReasons.isNotEmpty) {
        final buffer = StringBuffer('Draft Nitip belum lengkap:\n');
        for (final reason in validation!.rejectionReasons) {
          buffer.writeln('- $reason');
        }
        return buffer.toString().trimRight();
      }

      return 'Tulis toko/resto dan barang yang ingin dibeli, lalu pilih alamat antar.';
    }

    if (intent == ChatbotIntent.outOfDomain) {
      return 'Aku fokus bantu Nitip. Tulis toko/resto dan barang yang ingin dibeli, ya.';
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

  static String normalizeAssistantCopy(String text, {String? serviceType}) {
    var normalized = _normalizeDeliveryFeeLabel(text.trim());

    normalized = normalized.replaceAll(
      RegExp(
        r'Lokasi tujuan belum terbaca\.\s*Tulis contoh:\s*"antar ke Stasiun Tawang"\s*atau\s*"tujuan ke Jalan Sudirman No 10"\.',
        caseSensitive: false,
      ),
      'Lokasi tujuan belum terbaca.',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'Contoh:\s*antar ke Stasiun Tawang,\s*tujuan ke Jalan Sudirman No 10,\s*atau saya mau ke Polines\.',
        caseSensitive: false,
      ),
      'Contoh: Antar ke Ramayana Salatiga, atau Saya mau ke Alun-Alun Salatiga.',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'(^|\n)\s*Silakan klik tombol "Atur Titik Jemput & Tujuan" di bawah untuk memilih tujuan baru\.\s*',
        caseSensitive: false,
      ),
      '\n',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'(^|\n)\s*Setelah itu,\s*klik tombol "Atur Titik Jemput & Tujuan" di bawah untuk memilih tujuan baru\.\s*',
        caseSensitive: false,
      ),
      '\n',
    );

    normalized = normalized.replaceAll(
      RegExp(
        r'(^|\n)\s*Pilih metode pembayaran dulu:\s*COD atau Transfer\.\s*',
        caseSensitive: false,
      ),
      '\n',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\s+Pilih metode pembayaran\.\s*', caseSensitive: false),
      ' ',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'\s*Ketik "Konfirmasi" untuk lanjut atau "Ubah Tujuan" untuk ganti tujuan\.\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'\s*Ketik "Konfirmasi" untuk lanjut atau "Ubah Tujuan"\.\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\s*Ketik "Konfirmasi" untuk lanjut\.\s*', caseSensitive: false),
      ' ',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'\s*Ketik "Konfirmasi" untuk membuat order\.\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'\s*Ketik "Konfirmasi" kalau sudah oke\.\s*',
        caseSensitive: false,
      ),
      ' ',
    );

    return normalized
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static String _normalizeDeliveryFeeLabel(String text) {
    return text.replaceAllMapped(
      RegExp(r'(^|\n)\s*Ongkir\s*:', caseSensitive: false),
      (match) => '${match.group(1) ?? ''}Estimasi ongkir sementara:',
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}
