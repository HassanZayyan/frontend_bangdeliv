import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/models/amount_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/delivery_fee_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/shopping_negotiation_model.dart';

void main() {
  group('AmountNegotiationModel', () {
    test('parses shared negotiation fields consistently', () {
      final model = AmountNegotiationModel.fromRaw({
        'status': 'pending_customer',
        'trigger_type': 'driver_price_quoted',
        'quote_log_id': '12',
        'quoted_amount': '15000.50',
        'counter_amount': null,
        'approved_amount': '',
        'note': 'Harga toko berubah',
        'updated_at': '2026-06-16T01:30:00+07:00',
        'can_customer_respond': '1',
        'can_driver_submit_quote': false,
        'can_driver_accept_counter': 0,
        'approval_required': true,
        'is_pending': true,
      });

      expect(model.status, 'PENDING_CUSTOMER');
      expect(model.triggerType, 'DRIVER_PRICE_QUOTED');
      expect(model.quoteLogId, 12);
      expect(model.quotedAmount, 15000.50);
      expect(model.counterAmount, isNull);
      expect(model.approvedAmount, isNull);
      expect(model.note, 'Harga toko berubah');
      expect(model.updatedAt, isNotNull);
      expect(model.canCustomerRespond, isTrue);
      expect(model.canDriverSubmitQuote, isFalse);
      expect(model.canDriverAcceptCounter, isFalse);
      expect(model.approvalRequired, isTrue);
      expect(model.isPending, isTrue);
      expect(model.isPendingCustomer, isTrue);
      expect(model.displayAmount, 15000.50);
    });
  });

  test('shopping negotiation delegates common fields to shared model', () {
    final model = ShoppingNegotiationModel.fromRaw({
      'status': 'APPROVED',
      'pickup_location_id': '7',
      'quoted_amount': '20000',
      'approved_amount': '18000',
      'checkout_allowed': true,
    });

    expect(model, isNotNull);
    expect(model!.status, 'APPROVED');
    expect(model.pickupLocationId, 7);
    expect(model.quotedAmount, 20000);
    expect(model.approvedAmount, 18000);
    expect(model.displayAmount, 18000);
    expect(model.checkoutAllowed, isTrue);
    expect(model.isApproved, isTrue);
  });

  test('delivery fee negotiation keeps domain fields around shared amount', () {
    final model = DeliveryFeeNegotiationModel.fromRaw({
      'status': 'PENDING_DRIVER',
      'counter_amount': '12000',
      'old_delivery_fee': '9000',
      'careful_carry_required': 'true',
      'can_driver_accept_counter': true,
    });

    expect(model, isNotNull);
    expect(model!.status, 'PENDING_DRIVER');
    expect(model.counterAmount, 12000);
    expect(model.displayAmount, 12000);
    expect(model.oldDeliveryFee, 9000);
    expect(model.carefulCarryRequired, isTrue);
    expect(model.canDriverAcceptCounter, isTrue);
  });
}
