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

  test('order price notification routes customer to tracking screen', () {
    final route = FirebaseNotificationService.routeForNotificationData(
      const <String, dynamic>{
        'type': 'order_price_changed',
        'order_id': '42',
        'recipient_role': 'customer',
      },
    );

    expect(route, '/orders/42/track');
  });

  test('order price notification routes driver to active order screen', () {
    final route = FirebaseNotificationService.routeForNotificationData(
      const <String, dynamic>{
        'type': 'order_price_changed',
        'order_id': '42',
        'recipient_role': 'driver',
      },
    );

    expect(route, '/driver/orders/42/active');
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

  test(
    'notification navigation allows tracking chat and driver active routes only',
    () {
      expect(
        NotificationNavigationService.normalizeRoute('/orders/42/track'),
        '/orders/42/track',
      );
      expect(
        NotificationNavigationService.normalizeRoute('/orders/42/chat'),
        '/orders/42/chat',
      );
      expect(
        NotificationNavigationService.normalizeRoute(
          '/driver/orders/42/active',
        ),
        '/driver/orders/42/active',
      );
      expect(
        NotificationNavigationService.normalizeRoute('/driver/history/42'),
        isNull,
      );
    },
  );

  test('pending notification route is persisted and consumed once', () async {
    await NotificationNavigationService.queueRoute('/orders/42/chat');

    expect(
      await NotificationNavigationService.takePendingRoute(),
      '/orders/42/chat',
    );
    expect(await NotificationNavigationService.takePendingRoute(), isNull);
  });
}
