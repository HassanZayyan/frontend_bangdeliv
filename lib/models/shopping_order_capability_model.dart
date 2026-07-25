import '../utils/model_parse_utils.dart';

class ShoppingOrderCapabilitiesModel {
  const ShoppingOrderCapabilitiesModel({
    this.isExplicit = false,
    this.canCustomerDirectEditItems = false,
    this.canCustomerAddShoppingMerchant = false,
    this.canCustomerCancelShoppingOrder = false,
    this.awaitsDriverCancellationFeeReview = false,
    this.allMerchantsTerminal = false,
    this.canDriverCancelShoppingOrder = false,
    this.canCustomerRequestItemChange = false,
    this.canCustomerRequestAddStop = false,
    this.canCustomerEditUnavailableItems = false,
    this.canCustomerResolveFailedMerchant = false,
    this.canDriverMarkMerchantOpen = false,
    this.canDriverMarkMerchantClosed = false,
    this.canDriverUpdateItemAvailability = false,
    this.canDriverSubmitShoppingQuote = false,
    this.canDriverSubmitMerchantQuote = false,
    this.canDriverUploadReceipt = false,
    this.hasCheckoutSaved = false,
    this.hasPendingItemChangeRequest = false,
  });

  final bool isExplicit;
  final bool canCustomerDirectEditItems;
  final bool canCustomerAddShoppingMerchant;
  final bool canCustomerCancelShoppingOrder;

  /// Semua toko/resto sudah gagal dan fee 50% menunggu driver mengonfirmasi
  /// lewat CANCEL_WITH_FEE. Customer menunggu, bukan membatalkan sendiri.
  final bool awaitsDriverCancellationFeeReview;

  /// Semua toko/resto sudah terminal (tak ada yang bisa dibelanjakan lagi).
  /// Dipakai driver untuk mempersempit menu "Laporkan masalah" ke fee 50% saja.
  final bool allMerchantsTerminal;
  final bool canDriverCancelShoppingOrder;
  final bool canCustomerRequestItemChange;
  final bool canCustomerRequestAddStop;
  final bool canCustomerEditUnavailableItems;
  final bool canCustomerResolveFailedMerchant;
  final bool canDriverMarkMerchantOpen;
  final bool canDriverMarkMerchantClosed;
  final bool canDriverUpdateItemAvailability;
  final bool canDriverSubmitShoppingQuote;
  final bool canDriverSubmitMerchantQuote;
  final bool canDriverUploadReceipt;
  final bool hasCheckoutSaved;
  final bool hasPendingItemChangeRequest;

  static ShoppingOrderCapabilitiesModel fromRaw(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return const ShoppingOrderCapabilitiesModel();
    }

    return ShoppingOrderCapabilitiesModel(
      isExplicit: true,
      canCustomerDirectEditItems: ModelParseUtils.boolValue(
        raw['can_customer_direct_edit_items'] ??
            raw['canCustomerDirectEditItems'],
      ),
      canCustomerAddShoppingMerchant: ModelParseUtils.boolValue(
        raw['can_customer_add_shopping_merchant'] ??
            raw['canCustomerAddShoppingMerchant'] ??
            raw['can_customer_direct_edit_items'] ??
            raw['canCustomerDirectEditItems'],
      ),
      canCustomerCancelShoppingOrder: ModelParseUtils.boolValue(
        raw['can_customer_cancel_shopping_order'] ??
            raw['canCustomerCancelShoppingOrder'],
      ),
      awaitsDriverCancellationFeeReview: ModelParseUtils.boolValue(
        raw['awaits_driver_cancellation_fee_review'] ??
            raw['awaitsDriverCancellationFeeReview'],
      ),
      allMerchantsTerminal: ModelParseUtils.boolValue(
        raw['all_merchants_terminal'] ?? raw['allMerchantsTerminal'],
      ),
      canDriverCancelShoppingOrder: ModelParseUtils.boolValue(
        raw['can_driver_cancel_shopping_order'] ??
            raw['canDriverCancelShoppingOrder'],
      ),
      canCustomerRequestItemChange: ModelParseUtils.boolValue(
        raw['can_customer_request_item_change'] ??
            raw['canCustomerRequestItemChange'],
      ),
      canCustomerRequestAddStop: ModelParseUtils.boolValue(
        raw['can_customer_request_add_stop'] ??
            raw['canCustomerRequestAddStop'],
      ),
      canCustomerEditUnavailableItems: ModelParseUtils.boolValue(
        raw['can_customer_edit_unavailable_items'] ??
            raw['canCustomerEditUnavailableItems'],
      ),
      canCustomerResolveFailedMerchant: ModelParseUtils.boolValue(
        raw['can_customer_resolve_failed_merchant'] ??
            raw['canCustomerResolveFailedMerchant'],
      ),
      canDriverMarkMerchantOpen: ModelParseUtils.boolValue(
        raw['can_driver_mark_merchant_open'] ??
            raw['canDriverMarkMerchantOpen'],
      ),
      canDriverMarkMerchantClosed: ModelParseUtils.boolValue(
        raw['can_driver_mark_merchant_closed'] ??
            raw['canDriverMarkMerchantClosed'],
      ),
      canDriverUpdateItemAvailability: ModelParseUtils.boolValue(
        raw['can_driver_update_item_availability'] ??
            raw['canDriverUpdateItemAvailability'],
      ),
      canDriverSubmitShoppingQuote: ModelParseUtils.boolValue(
        raw['can_driver_submit_shopping_quote'] ??
            raw['canDriverSubmitShoppingQuote'],
      ),
      canDriverSubmitMerchantQuote: ModelParseUtils.boolValue(
        raw['can_driver_submit_merchant_quote'] ??
            raw['canDriverSubmitMerchantQuote'] ??
            raw['can_driver_submit_shopping_quote'] ??
            raw['canDriverSubmitShoppingQuote'],
      ),
      canDriverUploadReceipt: ModelParseUtils.boolValue(
        raw['can_driver_upload_receipt'] ?? raw['canDriverUploadReceipt'],
      ),
      hasCheckoutSaved: ModelParseUtils.boolValue(
        raw['has_checkout_saved'] ?? raw['hasCheckoutSaved'],
      ),
      hasPendingItemChangeRequest: ModelParseUtils.boolValue(
        raw['has_pending_item_change_request'] ??
            raw['hasPendingItemChangeRequest'],
      ),
    );
  }
}

class ShoppingItemChangeRequestModel {
  const ShoppingItemChangeRequestModel({
    required this.status,
    required this.triggerType,
    this.requestLogId,
    this.action,
    this.requestKind,
    this.targetPickupLocationId,
    this.items = const <ShoppingItemChangeRequestItemModel>[],
    this.requestedStops = const <ShoppingItemChangeRequestStopModel>[],
    this.itemId,
    this.note,
    this.updatedAt,
    this.canDriverRespond = false,
  });

  final String status;
  final String triggerType;
  final int? requestLogId;
  final String? action;
  final String? requestKind;
  final int? targetPickupLocationId;
  final List<ShoppingItemChangeRequestItemModel> items;
  final List<ShoppingItemChangeRequestStopModel> requestedStops;
  final int? itemId;
  final String? note;
  final DateTime? updatedAt;
  final bool canDriverRespond;

  bool get isPending =>
      status == 'PENDING_DRIVER' ||
      triggerType == 'CUSTOMER_ITEM_CHANGE_REQUESTED';

  bool get isApproveable => isPending && canDriverRespond;

  static ShoppingItemChangeRequestModel? fromRaw(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final triggerType = ModelParseUtils.normalizedStatus(
      raw['trigger_type'] ?? raw['triggerType'],
      fallback: '',
    );
    final status = ModelParseUtils.normalizedStatus(raw['status']);
    final itemsRaw = raw['items'];
    final requestedStopsRaw = raw['requested_stops'] ?? raw['requestedStops'];

    return ShoppingItemChangeRequestModel(
      status: status,
      triggerType: triggerType,
      requestLogId: ModelParseUtils.intOrNull(
        raw['request_log_id'] ?? raw['requestLogId'] ?? raw['id'],
      ),
      action: ModelParseUtils.normalizedText(raw['action']),
      requestKind: ModelParseUtils.normalizedText(
        raw['request_kind'] ?? raw['requestKind'],
      ),
      targetPickupLocationId: ModelParseUtils.intOrNull(
        raw['target_pickup_location_id'] ?? raw['targetPickupLocationId'],
      ),
      items: itemsRaw is List
          ? itemsRaw
                .whereType<Map<String, dynamic>>()
                .map(ShoppingItemChangeRequestItemModel.fromJson)
                .toList(growable: false)
          : const <ShoppingItemChangeRequestItemModel>[],
      requestedStops: requestedStopsRaw is List
          ? requestedStopsRaw
                .whereType<Map<String, dynamic>>()
                .map(ShoppingItemChangeRequestStopModel.fromJson)
                .toList(growable: false)
          : const <ShoppingItemChangeRequestStopModel>[],
      itemId: ModelParseUtils.intOrNull(raw['item_id'] ?? raw['itemId']),
      note: ModelParseUtils.optionalText(raw['note']),
      updatedAt: ModelParseUtils.backendDateTime(
        raw['updated_at'] ?? raw['updatedAt'],
      ),
      canDriverRespond: ModelParseUtils.boolValue(
        raw['can_driver_respond'] ?? raw['canDriverRespond'],
      ),
    );
  }
}

class ShoppingItemChangeRequestStopModel {
  const ShoppingItemChangeRequestStopModel({
    this.pickupLocationId,
    this.requestKind,
    this.merchantId,
    required this.merchantName,
    this.merchantAddress,
    this.merchantType,
    this.latitude,
    this.longitude,
    this.items = const <ShoppingItemChangeRequestItemModel>[],
  });

  final int? pickupLocationId;
  final String? requestKind;
  final int? merchantId;
  final String merchantName;
  final String? merchantAddress;
  final String? merchantType;
  final double? latitude;
  final double? longitude;
  final List<ShoppingItemChangeRequestItemModel> items;

  factory ShoppingItemChangeRequestStopModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final itemsRaw = json['items'];
    return ShoppingItemChangeRequestStopModel(
      pickupLocationId: ModelParseUtils.intOrNull(
        json['pickup_location_id'] ?? json['pickupLocationId'],
      ),
      requestKind: ModelParseUtils.normalizedText(
        json['request_kind'] ?? json['requestKind'],
      ),
      merchantId: ModelParseUtils.intOrNull(
        json['merchant_id'] ?? json['merchantId'],
      ),
      merchantName:
          ModelParseUtils.optionalText(
            json['merchant_name'] ?? json['merchantName'] ?? json['name'],
          ) ??
          'Tempat',
      merchantAddress: ModelParseUtils.optionalText(
        json['merchant_address'] ?? json['merchantAddress'] ?? json['address'],
      ),
      merchantType: ModelParseUtils.normalizedText(
        json['merchant_type'] ?? json['merchantType'],
      ),
      latitude: ModelParseUtils.doubleOrNull(
        json['merchant_latitude'] ??
            json['merchantLatitude'] ??
            json['latitude'],
      ),
      longitude: ModelParseUtils.doubleOrNull(
        json['merchant_longitude'] ??
            json['merchantLongitude'] ??
            json['longitude'],
      ),
      items: itemsRaw is List
          ? itemsRaw
                .whereType<Map<String, dynamic>>()
                .map(ShoppingItemChangeRequestItemModel.fromJson)
                .toList(growable: false)
          : const <ShoppingItemChangeRequestItemModel>[],
    );
  }
}

class ShoppingItemChangeRequestItemModel {
  const ShoppingItemChangeRequestItemModel({
    this.merchantId,
    this.merchantName,
    this.menuId,
    this.itemSource = 'MANUAL',
    required this.name,
    required this.quantity,
    this.notes,
  });

  final int? merchantId;
  final String? merchantName;
  final int? menuId;
  final String itemSource;
  final String name;
  final int quantity;
  final String? notes;

  factory ShoppingItemChangeRequestItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final merchantPlace = json['merchant_place'] is Map<String, dynamic>
        ? json['merchant_place'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return ShoppingItemChangeRequestItemModel(
      merchantId: ModelParseUtils.intOrNull(
        json['merchant_id'] ?? json['merchantId'],
      ),
      merchantName: ModelParseUtils.optionalText(
        json['merchant_name'] ??
            json['merchantName'] ??
            merchantPlace['name'] ??
            merchantPlace['formatted_address'],
      ),
      menuId: ModelParseUtils.intOrNull(json['menu_id'] ?? json['menuId']),
      itemSource: (json['item_source'] ?? json['itemSource'] ?? 'MANUAL')
          .toString()
          .trim()
          .toUpperCase(),
      name:
          ModelParseUtils.optionalText(
            json['menu_name'] ??
                json['name'] ??
                json['item_name'] ??
                json['display_name'] ??
                json['displayName'],
          ) ??
          '-',
      quantity: ModelParseUtils.intOrNull(json['quantity']) ?? 1,
      notes: ModelParseUtils.optionalText(json['notes']),
    );
  }
}
