import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/services/firebase_notification_service.dart';

void main() {
  test('order chat notification data resolves to chat route', () {
    final route = FirebaseNotificationService.routeForNotificationData(
      const <String, dynamic>{'type': 'order_chat_message', 'order_id': '42'},
    );

    expect(route, '/orders/42/chat');
  });

  test('invalid notification data does not resolve to route', () {
    expect(
      FirebaseNotificationService.routeForNotificationData(
        const <String, dynamic>{'type': 'other', 'order_id': '42'},
      ),
      isNull,
    );

    expect(
      FirebaseNotificationService.routeForNotificationData(
        const <String, dynamic>{
          'type': 'order_chat_message',
          'order_id': 'abc',
        },
      ),
      isNull,
    );
  });
}
