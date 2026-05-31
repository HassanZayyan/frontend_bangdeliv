import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/services/firebase_notification_service.dart';
import 'package:frontend_bangdeliv/services/notification_navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

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

  test('explicit notification route is restricted to order chat route', () {
    expect(
      FirebaseNotificationService.routeForNotificationData(
        const <String, dynamic>{
          'type': 'order_chat_message',
          'route': '/orders/42/chat',
        },
      ),
      '/orders/42/chat',
    );

    expect(
      FirebaseNotificationService.routeForNotificationData(
        const <String, dynamic>{
          'type': 'order_chat_message',
          'route': '/driver/orders',
        },
      ),
      isNull,
    );
  });

  test('pending notification route is persisted and consumed once', () async {
    await NotificationNavigationService.queueRoute('/orders/42/chat');

    expect(
      await NotificationNavigationService.takePendingRoute(),
      '/orders/42/chat',
    );
    expect(await NotificationNavigationService.takePendingRoute(), isNull);
  });
}
