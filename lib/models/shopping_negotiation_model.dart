import '../utils/model_parse_utils.dart';
import 'amount_negotiation_model.dart';

class ShoppingNegotiationModel {
  const ShoppingNegotiationModel({
    required this.amount,
    this.pickupLocationId,
    this.checkoutAllowed = false,
  });

  final AmountNegotiationModel amount;
  final int? pickupLocationId;
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
      checkoutAllowed: checkoutAllowed,
    );
  }
}
