import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/order_chat_model.dart';

void main() {
  test('driver order parses delivery pricing and proof contract fields', () {
    final order = DriverOrderModel.fromJson({
      'id': 42,
      'customer_name': 'Hassan',
      'pickup_address': 'Pickup',
      'dropoff_address': 'Dropoff',
      'eta_minutes': 12,
      'fee': 15000,
      'item_count': 2,
      'delivery_distance_km': '3.7',
      'delivery_fee': 13000,
      'delivery_fee_source': 'manual',
      'manual_delivery_fee': 13000,
      'manual_delivery_fee_reason': 'Rute sistem kurang akurat',
      'careful_carry_required': true,
      'fee_breakdown': [
        {
          'code': 'ITEM_BLOCK_SURCHARGE',
          'label': 'Biaya banyak item',
          'description': 'Tambahan nitip',
          'amount': 2000,
        },
      ],
      'proofs': [
        {'id': 7, 'type': 'pickup', 'photo_url': '/storage/proofs/pickup.jpg'},
      ],
    });

    expect(order.deliveryDistanceKm, 3.7);
    expect(order.deliveryDistanceLabel, '3.7 km');
    expect(order.deliveryFee, 13000);
    expect(order.deliveryFeeSource, 'manual');
    expect(order.manualDeliveryFeeReason, 'Rute sistem kurang akurat');
    expect(order.carefulCarryRequired, isTrue);
    expect(order.feeBreakdown.single.amount, 2000);
    expect(order.hasProof('pickup'), isTrue);
  });

  test('order chat message parses image attachment payloads', () {
    final message = OrderChatMessageModel.fromJson({
      'id': 9,
      'order_id': 42,
      'sender_user_id': 1,
      'sender_role': 'customer',
      'sender_name': 'Customer',
      'body': 'Bukti transfer',
      'client_message_id': 'client-1',
      'attachment': {
        'type': 'payment_transfer',
        'url': 'https://example.com/proof.jpg',
        'mime_type': 'image/jpeg',
      },
      'created_at': '2026-05-30T10:00:00Z',
    });

    expect(message.hasAttachment, isTrue);
    expect(message.attachmentType, 'payment_transfer');
    expect(message.attachmentUrl, 'https://example.com/proof.jpg');
    expect(message.attachmentMimeType, 'image/jpeg');
  });
}
