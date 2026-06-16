import '../utils/model_parse_utils.dart';

class AmountNegotiationModel {
  const AmountNegotiationModel({
    required this.status,
    this.triggerType,
    this.quoteLogId,
    this.quotedAmount,
    this.counterAmount,
    this.approvedAmount,
    this.note,
    this.updatedAt,
    this.canCustomerRespond = false,
    this.canDriverSubmitQuote = false,
    this.canDriverAcceptCounter = false,
    this.approvalRequired = false,
    this.isPending = false,
    this.isApproved = false,
  });

  final String status;
  final String? triggerType;
  final int? quoteLogId;
  final double? quotedAmount;
  final double? counterAmount;
  final double? approvedAmount;
  final String? note;
  final DateTime? updatedAt;
  final bool canCustomerRespond;
  final bool canDriverSubmitQuote;
  final bool canDriverAcceptCounter;
  final bool approvalRequired;
  final bool isPending;
  final bool isApproved;

  bool get hasQuote =>
      quotedAmount != null || counterAmount != null || approvedAmount != null;

  bool get isPendingCustomer => status == 'PENDING_CUSTOMER';

  bool get isPendingDriver => status == 'PENDING_DRIVER';

  double? get displayAmount => approvedAmount ?? counterAmount ?? quotedAmount;

  static AmountNegotiationModel fromRaw(
    Map<String, dynamic> raw, {
    bool Function(String status, Map<String, dynamic> raw)? isApproved,
  }) {
    final status = ModelParseUtils.normalizedStatus(raw['status']);
    final pendingCustomer = status == 'PENDING_CUSTOMER';
    final pendingDriver = status == 'PENDING_DRIVER';

    return AmountNegotiationModel(
      status: status,
      triggerType: ModelParseUtils.normalizedText(
        raw['trigger_type'] ?? raw['triggerType'],
      ),
      quoteLogId: ModelParseUtils.intOrNull(
        raw['quote_log_id'] ?? raw['quoteLogId'],
      ),
      quotedAmount: ModelParseUtils.doubleOrNull(
        raw['quoted_amount'] ?? raw['quotedAmount'],
      ),
      counterAmount: ModelParseUtils.doubleOrNull(
        raw['counter_amount'] ?? raw['counterAmount'],
      ),
      approvedAmount: ModelParseUtils.doubleOrNull(
        raw['approved_amount'] ?? raw['approvedAmount'],
      ),
      note: ModelParseUtils.optionalText(raw['note']),
      updatedAt: ModelParseUtils.backendDateTime(
        raw['updated_at'] ?? raw['updatedAt'],
      ),
      canCustomerRespond: ModelParseUtils.boolValue(
        raw['can_customer_respond'] ?? raw['canCustomerRespond'],
      ),
      canDriverSubmitQuote: ModelParseUtils.boolValue(
        raw['can_driver_submit_quote'] ?? raw['canDriverSubmitQuote'],
      ),
      canDriverAcceptCounter: ModelParseUtils.boolValue(
        raw['can_driver_accept_counter'] ?? raw['canDriverAcceptCounter'],
      ),
      approvalRequired: ModelParseUtils.boolValue(
        raw['approval_required'] ?? raw['approvalRequired'],
        fallback: pendingCustomer || pendingDriver,
      ),
      isPending: ModelParseUtils.boolValue(
        raw['is_pending'] ?? raw['isPending'],
        fallback: pendingCustomer || pendingDriver,
      ),
      isApproved:
          isApproved?.call(status, raw) ??
          ModelParseUtils.boolValue(
            raw['is_approved'] ?? raw['isApproved'],
            fallback: status == 'APPROVED',
          ),
    );
  }
}
