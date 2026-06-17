import '../utils/model_parse_utils.dart';
import 'amount_negotiation_model.dart';

class ShoppingNegotiationModel {
  const ShoppingNegotiationModel({
    required this.amount,
    this.pickupLocationId,
    this.merchantName,
    this.merchantQuotes = const <ShoppingMerchantQuoteModel>[],
    this.approvedSubtotal,
    this.allRequiredQuotesApproved = false,
    this.checkoutAllowed = false,
  });

  final AmountNegotiationModel amount;
  final int? pickupLocationId;
  final String? merchantName;
  final List<ShoppingMerchantQuoteModel> merchantQuotes;
  final double? approvedSubtotal;
  final bool allRequiredQuotesApproved;
  final bool checkoutAllowed;

  String get status => amount.status;
  String? get triggerType => amount.triggerType;
  int? get quoteLogId => amount.quoteLogId;
  double? get quotedAmount => amount.quotedAmount;
  double? get counterAmount => amount.counterAmount;
  double? get approvedAmount => amount.approvedAmount;
  String? get note => amount.note;
  DateTime? get updatedAt => amount.updatedAt;
  bool get canCustomerRespond => amount.canCustomerRespond;
  bool get canDriverSubmitQuote => amount.canDriverSubmitQuote;
  bool get canDriverAcceptCounter => amount.canDriverAcceptCounter;
  bool get hasQuote => amount.hasQuote;
  bool get isPendingCustomer => amount.isPendingCustomer;
  bool get isPendingDriver => amount.isPendingDriver;
  bool get isApproved => amount.isApproved || checkoutAllowed;
  double? get displayAmount => amount.displayAmount;

  ShoppingMerchantQuoteModel? quoteForPickup(int? pickupLocationId) {
    if (pickupLocationId == null) {
      return null;
    }

    for (final quote in merchantQuotes) {
      if (quote.pickupLocationId == pickupLocationId) {
        return quote;
      }
    }

    return null;
  }

  static ShoppingNegotiationModel? fromRaw(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final checkoutAllowed = ModelParseUtils.boolValue(
      raw['checkout_allowed'] ?? raw['checkoutAllowed'],
    );

    return ShoppingNegotiationModel(
      amount: AmountNegotiationModel.fromRaw(
        raw,
        isApproved: (status, _) => status == 'APPROVED' || checkoutAllowed,
      ),
      pickupLocationId: ModelParseUtils.intOrNull(
        raw['pickup_location_id'] ?? raw['pickupLocationId'],
      ),
      merchantName: ModelParseUtils.optionalText(
        raw['merchant_name'] ?? raw['merchantName'],
      ),
      merchantQuotes: (raw['merchant_quotes'] ?? raw['merchantQuotes']) is List
          ? ((raw['merchant_quotes'] ?? raw['merchantQuotes']) as List)
                .whereType<Map<String, dynamic>>()
                .map(ShoppingMerchantQuoteModel.fromJson)
                .toList(growable: false)
          : const <ShoppingMerchantQuoteModel>[],
      approvedSubtotal: ModelParseUtils.doubleOrNull(
        raw['approved_subtotal'] ?? raw['approvedSubtotal'],
      ),
      allRequiredQuotesApproved: ModelParseUtils.boolValue(
        raw['all_required_quotes_approved'] ?? raw['allRequiredQuotesApproved'],
      ),
      checkoutAllowed: checkoutAllowed,
    );
  }
}

class ShoppingMerchantQuoteModel {
  const ShoppingMerchantQuoteModel({
    required this.amount,
    this.pickupLocationId,
    this.merchantName,
    this.hasAvailableItems = true,
    this.checkoutAllowed = false,
  });

  final AmountNegotiationModel amount;
  final int? pickupLocationId;
  final String? merchantName;
  final bool hasAvailableItems;
  final bool checkoutAllowed;

  String get status => amount.status;
  bool get isApproved => amount.isApproved || checkoutAllowed;
  bool get isPendingCustomer => amount.isPendingCustomer;
  bool get isPendingDriver => amount.isPendingDriver;
  bool get needsRequote => status == 'NEEDS_REQUOTE';
  double? get approvedAmount => amount.approvedAmount;
  double? get displayAmount => amount.displayAmount;

  factory ShoppingMerchantQuoteModel.fromJson(Map<String, dynamic> json) {
    final checkoutAllowed = ModelParseUtils.boolValue(
      json['checkout_allowed'] ?? json['checkoutAllowed'],
    );

    return ShoppingMerchantQuoteModel(
      amount: AmountNegotiationModel.fromRaw(
        json,
        isApproved: (status, _) => status == 'APPROVED' || checkoutAllowed,
      ),
      pickupLocationId: ModelParseUtils.intOrNull(
        json['pickup_location_id'] ?? json['pickupLocationId'],
      ),
      merchantName: ModelParseUtils.optionalText(
        json['merchant_name'] ?? json['merchantName'],
      ),
      hasAvailableItems: ModelParseUtils.boolValue(
        json['has_available_items'] ?? json['hasAvailableItems'],
        fallback: true,
      ),
      checkoutAllowed: checkoutAllowed,
    );
  }
}
