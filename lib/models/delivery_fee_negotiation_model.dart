import '../utils/model_parse_utils.dart';
import 'amount_negotiation_model.dart';

class DeliveryFeeNegotiationModel {
  static const shoppingTotalTransportScope = 'SHOPPING_TOTAL_TRANSPORT';

  const DeliveryFeeNegotiationModel({
    required this.amount,
    this.oldDeliveryFee,
    this.pricingScope,
    this.activePricingScope,
    this.previousTotalTransport,
  });

  final AmountNegotiationModel amount;
  final double? oldDeliveryFee;
  final String? pricingScope;
  final String? activePricingScope;
  final double? previousTotalTransport;

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
  bool get approvalRequired => amount.approvalRequired;
  bool get isPending => amount.isPending;
  bool get isApproved => amount.isApproved;
  bool get hasQuote => amount.hasQuote;
  bool get isPendingCustomer => amount.isPendingCustomer;
  bool get isPendingDriver => amount.isPendingDriver;
  double? get displayAmount => amount.displayAmount;
  bool get isShoppingTotalTransport =>
      pricingScope == shoppingTotalTransportScope;
  bool get isActiveShoppingTotalTransport =>
      activePricingScope == shoppingTotalTransportScope;

  static DeliveryFeeNegotiationModel? fromRaw(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    return DeliveryFeeNegotiationModel(
      amount: AmountNegotiationModel.fromRaw(raw),
      oldDeliveryFee: ModelParseUtils.doubleOrNull(
        raw['old_delivery_fee'] ?? raw['oldDeliveryFee'],
      ),
      pricingScope: ModelParseUtils.normalizedText(
        raw['pricing_scope'] ?? raw['pricingScope'],
      ),
      activePricingScope: ModelParseUtils.normalizedText(
        raw['active_pricing_scope'] ?? raw['activePricingScope'],
      ),
      previousTotalTransport: ModelParseUtils.doubleOrNull(
        raw['previous_total_transport'] ?? raw['previousTotalTransport'],
      ),
    );
  }
}
