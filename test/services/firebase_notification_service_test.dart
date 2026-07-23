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

  test(
    'order price notification routes customer to focused tracking screen',
    () {
      final route = FirebaseNotificationService.routeForNotificationData(
        const <String, dynamic>{
          'type': 'order_price_changed',
          'order_id': '42',
          'recipient_role': 'customer',
          'change_type': 'DRIVER_FEE_QUOTED',
        },
      );

      expect(route, '/orders/42/track?focus=delivery_fee');
    },
  );

  test('shopping price notification keeps merchant focus query', () {
    final route = FirebaseNotificationService.routeForNotificationData(
      const <String, dynamic>{
        'type': 'order_price_changed',
        'order_id': '42',
        'recipient_role': 'customer',
        'focus': 'shopping_price',
        'pickup_location_id': '7',
      },
    );

    expect(route, '/orders/42/track?focus=shopping_price&pickup_location_id=7');
  });

  test('shopping unavailable item notification keeps merchant focus query', () {
    final route = FirebaseNotificationService.routeForNotificationData(
      const <String, dynamic>{
        'type': 'shopping_item_unavailable',
        'order_id': '42',
        'pickup_location_id': '7',
      },
    );

    expect(route, '/orders/42/track?focus=shopping_price&pickup_location_id=7');
  });

  test('merchant closed notification opens the failed merchant', () {
    final route = FirebaseNotificationService.routeForNotificationData(
      const <String, dynamic>{
        'type': 'shopping_merchant_failed',
        'order_id': '42',
        'pickup_location_id': '7',
      },
    );

    expect(route, '/orders/42/track?focus=shopping_price&pickup_location_id=7');
  });

  test('payment proof reminder notification routes to payment card', () {
    final route = FirebaseNotificationService.routeForNotificationData(
      const <String, dynamic>{
        'type': 'payment_proof_required',
        'order_id': '42',
      },
    );

    expect(route, '/orders/42/track?focus=payment');
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

  test('driver incoming order notification routes to incoming orders tab', () {
    final route = FirebaseNotificationService.routeForNotificationData(
      const <String, dynamic>{
        'type': 'driver_order_available',
        'order_id': '42',
      },
    );

    expect(route, '/driver/orders');
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

  test('explicit notification route is restricted to known order routes', () {
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
          'type': 'driver_order_available',
          'route': '/driver/orders',
        },
      ),
      '/driver/orders',
    );
  });

  test(
    'notification navigation allows tracking chat and driver order routes only',
    () {
      expect(
        NotificationNavigationService.normalizeRoute(
          '/orders/42/track?focus=payment',
        ),
        '/orders/42/track?focus=payment',
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
        NotificationNavigationService.normalizeRoute('/driver/orders'),
        '/driver/orders',
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
