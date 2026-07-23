import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/models/customer_order_model.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/order_chat_model.dart';

void main() {
  test('order models parse WhatsApp participant and bypass capability', () {
    final driverOrder = DriverOrderModel.fromJson({
      'id': 42,
      'customer_name': 'Hassan',
      'customer_phone': '081234567890',
      'shopping_stops': [
        {
          'pickup_location_id': 7,
          'sequence_no': 1,
          'fulfillment_status': 'ITEMS_PENDING_CUSTOMER',
          'availability_confirmed': true,
          'unavailable_item_actions': {
            'can_driver_bypass': true,
            'can_driver_continue_without_item': true,
            'can_driver_cancel_merchant': true,
            'can_driver_replace_unavailable_items': true,
          },
          'merchant': {'name': 'Kedai'},
          'items': const <Map<String, dynamic>>[],
        },
      ],
    });
    final customerDetail = CustomerOrderDetailModel.fromJson({
      'id': 42,
      'order_number': 'BD-42',
      'service_type': {'code': 'SHOPPING', 'display_name': 'Nitip'},
      'status': 'DRIVER_ASSIGNED',
      'total_amount': 15000,
      'driver': {
        'user': {'name': 'Driver Satu', 'phone': '082345678901'},
      },
    });

    expect(driverOrder.customerPhone, '081234567890');
    expect(
      driverOrder.shoppingStops.single.canDriverBypassUnavailableItems,
      isTrue,
    );
    expect(
      driverOrder.shoppingStops.single.canDriverReplaceUnavailableItems,
      isTrue,
    );
    expect(
      driverOrder.shoppingStops.single.canDriverContinueWithoutUnavailableItem,
      isTrue,
    );
    expect(
      driverOrder.shoppingStops.single.canDriverCancelUnavailableMerchant,
      isTrue,
    );
    expect(customerDetail.driverPhone, '082345678901');
  });

  test('driver order parses delivery pricing and proof contract fields', () {
    final order = DriverOrderModel.fromJson({
      'id': 42,
      'customer_name': 'Hassan',
      'customer_avatar_url': '/storage/avatars/customer.jpg',
      'pickup_address': 'Pickup',
      'dropoff_address': 'Dropoff',
      'eta_minutes': 12,
      'fee': 15000,
      'item_count': 2,
      'delivery_distance_km': '3.7',
      'delivery_fee': 13000,
      'delivery_fee_source': 'driver_manual',
      'proofs': [
        {'id': 7, 'type': 'pickup', 'photo_url': '/storage/proofs/pickup.jpg'},
        {
          'id': 8,
          'type': 'payment_transfer',
          'photo_url': '/storage/proofs/transfer.jpg',
          'status': 'pending',
          'note': 'Transfer BCA',
          'uploaded_at': '2026-06-06T14:30:00Z',
        },
      ],
    });

    expect(order.deliveryDistanceKm, 3.7);
    expect(order.customerAvatarUrl, endsWith('/storage/avatars/customer.jpg'));
    expect(order.deliveryDistanceLabel, '3.7 km');
    expect(order.deliveryFee, 13000);
    expect(order.deliveryFeeSource, 'driver_manual');
    expect(order.manualDeliveryFee, isNull);
    expect(order.manualDeliveryFeeReason, isNull);
    expect(order.hasProof('pickup'), isTrue);
    expect(order.hasProof('payment_transfer'), isTrue);

    final transferProof = order.proofs.firstWhere(
      (proof) => proof.type == 'payment_transfer',
    );
    expect(transferProof.label, 'Bukti QRIS');
    expect(transferProof.photoUrl, endsWith('/storage/proofs/transfer.jpg'));
    expect(transferProof.status, 'pending');
    expect(transferProof.note, 'Transfer BCA');
    expect(transferProof.createdAt, DateTime.parse('2026-06-06T14:30:00Z'));
  });

  test('order chat message parses image attachment payloads', () {
    final message = OrderChatMessageModel.fromJson({
      'id': 9,
      'order_id': 42,
      'sender_user_id': 1,
      'sender_role': 'customer',
      'sender_name': 'Customer',
      'body': 'Foto order',
      'client_message_id': 'client-1',
      'attachment': {
        'type': 'image',
        'url': 'https://example.com/order-photo.jpg',
        'mime_type': 'image/jpeg',
      },
      'created_at': '2026-05-30T10:00:00Z',
    });

    expect(message.hasAttachment, isTrue);
    expect(message.attachmentType, 'image');
    expect(message.attachmentUrl, 'https://example.com/order-photo.jpg');
    expect(message.attachmentMimeType, 'image/jpeg');
  });

  test('order chat send result rejects missing server message payload', () {
    expect(
      () => OrderChatSendResult.fromApiJson({
        'success': true,
        'data': {'can_send': true},
      }),
      throwsFormatException,
    );

    expect(
      () => OrderChatSendResult.fromApiJson({
        'success': true,
        'data': {
          'message': {
            'id': 0,
            'order_id': 99,
            'sender_user_id': 7,
            'body': 'Halo',
          },
          'can_send': true,
        },
      }),
      throwsFormatException,
    );
  });

  test('driver order parses payment transfer from raw evidence payload', () {
    final order = DriverOrderModel.fromJson({
      'id': 77,
      'customer_name': 'Courier Customer',
      'pickup_address': 'Pickup',
      'dropoff_address': 'Dropoff',
      'eta_minutes': 8,
      'fee': 5000,
      'item_count': 1,
      'payment_method': 'TRANSFER',
      'payment_status': 'unpaid',
      'evidences': [
        {
          'id': 19,
          'evidence_type': 'PAYMENT_TRANSFER_PHOTO',
          'file_url': '/storage/orders/77/payments/transfer.jpg',
          'verification_status': 'PENDING',
          'notes': 'Bukti QRIS customer.',
          'uploaded_at': '2026-06-06T15:38:00Z',
        },
      ],
    });

    expect(order.hasProof('payment_transfer'), isTrue);

    final proof = order.proofs.single;
    expect(proof.type, 'payment_transfer');
    expect(proof.label, 'Bukti QRIS');
    expect(
      proof.photoUrl,
      endsWith('/storage/orders/77/payments/transfer.jpg'),
    );
    expect(proof.status, 'PENDING');
    expect(proof.note, 'Bukti QRIS customer.');
    expect(proof.createdAt, DateTime.parse('2026-06-06T15:38:00Z'));
  });

  test('order models parse payment proof feedback', () {
    final driverOrder = DriverOrderModel.fromJson({
      'id': 78,
      'customer_name': 'Courier Customer',
      'pickup_address': 'Pickup',
      'dropoff_address': 'Dropoff',
      'eta_minutes': 8,
      'fee': 5000,
      'item_count': 1,
      'payment_proof_feedback': {
        'status': 'rejected',
        'reason': 'Nominal tidak sesuai.',
        'proof_id': 19,
        'decided_at': '2026-06-06T15:45:00Z',
      },
    });

    expect(driverOrder.paymentProofFeedback?.isRejected, isTrue);
    expect(
      driverOrder.paymentProofFeedback?.displayReason,
      'Nominal tidak sesuai.',
    );
    expect(driverOrder.paymentProofFeedback?.proofId, 19);
    expect(
      driverOrder.paymentProofFeedback?.decidedAt,
      DateTime.parse('2026-06-06T15:45:00Z'),
    );

    final customerDetail = CustomerOrderDetailModel.fromJson({
      'id': 79,
      'order_number': 'BD-260606-0079',
      'service_type': {'code': 'RIDE', 'display_name': 'Antar Jemput'},
      'status': 'DRIVER_ASSIGNED',
      'total_amount': 5000,
      'delivery_address': 'Jl. Tujuan',
      'payment_status': 'unpaid',
      'payment_method': 'TRANSFER',
      'payment_proof_feedback': {'status': 'pending', 'proof_id': 20},
    });

    expect(customerDetail.paymentProofFeedback?.isPending, isTrue);
    expect(customerDetail.paymentProofFeedback?.proofId, 20);
  });

  test('customer detail parses driver location for live tracking marker', () {
    final detail = CustomerOrderDetailModel.fromJson({
      'id': 91,
      'order_number': 'BD-260607-0091',
      'service_type': {'code': 'SHOPPING', 'display_name': 'Nitip'},
      'status': 'DRIVER_ASSIGNED',
      'total_amount': 5000,
      'delivery_address': 'Jl. Tujuan',
      'payment_status': 'unpaid',
      'payment_method': 'TRANSFER',
      'delivery_fee': 8000,
      'delivery_fee_source': 'driver_manual',
      'delivery_fee_change_note': 'BBM naik.',
      'driver': {
        'latitude': '-7.056100',
        'longitude': '110.438400',
        'location_updated_at': '2026-06-07T15:45:00Z',
        'user': {'name': 'Driver Satu'},
      },
      'driver_avatar_url': '/storage/avatars/driver.jpg',
    });

    expect(detail.driverLatitude, -7.0561);
    expect(detail.driverLongitude, 110.4384);
    expect(detail.driverAvatarUrl, endsWith('/storage/avatars/driver.jpg'));
    expect(detail.deliveryFeeSource, 'driver_manual');
    expect(detail.deliveryFeeChangeNote, 'BBM naik.');
    expect(detail.summary.deliveryFee, 8000);
    expect(detail.summary.deliveryFeeChangeNote, 'BBM naik.');
    expect(
      detail.driverLocationUpdatedAt,
      DateTime.parse('2026-06-07T15:45:00Z'),
    );
  });

  test('customer detail parses computed driver ETA payload', () {
    final detail = CustomerOrderDetailModel.fromJson({
      'id': 92,
      'order_number': 'BD-260615-0092',
      'service_type': {'code': 'RIDE', 'display_name': 'Antar Jemput'},
      'status': 'DRIVER_ASSIGNED',
      'total_amount': 12000,
      'delivery_address': 'Jl. Tujuan',
      'driver_eta': {
        'target': 'PICKUP',
        'target_label': 'Titik jemput',
        'duration_seconds': 480,
        'duration_text': '8 menit',
        'distance_meters': 2100,
        'distance_text': '2,1 km',
        'estimated_arrival_at': '2026-06-15T10:20:00+07:00',
        'location_fresh': true,
        'route_provider': 'routes_api',
      },
    });

    expect(detail.driverEta?.target, 'PICKUP');
    expect(detail.driverEta?.targetLabel, 'Titik jemput');
    expect(detail.driverEta?.durationSeconds, 480);
    expect(detail.driverEta?.durationText, '8 menit');
    expect(detail.driverEta?.distanceMeters, 2100);
    expect(detail.driverEta?.distanceText, '2,1 km');
    expect(detail.driverEta?.locationFresh, isTrue);
    expect(detail.driverEta?.routeProvider, 'routes_api');
  });

  test('shopping stop parses event replacement capability and counters', () {
    final customerStop = CustomerShoppingStopModel.fromJson({
      'pickup_location_id': 31,
      'sequence_no': 2,
      'fulfillment_status': 'ITEMS_PENDING_CUSTOMER',
      'merchant': {'name': 'Resto Lama'},
      'items': const <Map<String, dynamic>>[],
      'unavailable_item_actions': {
        'can_customer_replace_merchant': true,
        'chain_id': 'pickup:10',
        'chain_attempt_no': 2,
        'chain_failed_attempt_count': 1,
        'chain_failed_attempt_limit': 3,
        'order_failed_trip_count': 3,
        'verified_failed_trip_count': 3,
        'compensation_eligible': true,
        'state_version': 88,
      },
    });
    final driverStop = DriverShoppingStopModel.fromJson({
      'pickup_location_id': 31,
      'sequence_no': 2,
      'fulfillment_status': 'ITEMS_PENDING_CUSTOMER',
      'merchant': {'name': 'Resto Lama'},
      'items': const <Map<String, dynamic>>[],
      'unavailable_item_actions': {
        'can_driver_replace_merchant': true,
        'can_driver_replace_unavailable_items': true,
        'chain_id': 'pickup:10',
        'chain_attempt_no': 2,
        'chain_failed_attempt_count': 1,
        'order_failed_trip_count': 3,
        'verified_failed_trip_count': 3,
        'compensation_eligible': true,
        'state_version': 88,
      },
    });

    expect(customerStop.canReplaceMerchant, isTrue);
    expect(driverStop.canReplaceMerchant, isTrue);
    expect(driverStop.canDriverReplaceUnavailableItems, isTrue);
    expect(customerStop.chainId, 'pickup:10');
    expect(driverStop.chainAttemptNo, 2);
    expect(customerStop.orderFailedTripCount, 3);
    expect(driverStop.compensationEligible, isTrue);
    expect(customerStop.stateVersion, 88);
  });

  test('customer pricing parses the single cancellation fee', () {
    final pricing = CustomerShoppingPricingModel.fromJson({
      'subtotal': 30000,
      'delivery_fee': 12000,
      'service_fee': 6500,
      'total_price': 48500,
    }, const <String, dynamic>{
      'cancellation_penalty': 6500,
    });

    expect(pricing.cancellationPenalty, 6500);
    expect(pricing.serviceFee, 6500);
  });
}
