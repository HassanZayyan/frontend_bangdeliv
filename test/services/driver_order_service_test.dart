import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/services/driver_order_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'access_token': 'test-token',
    });
  });

  test(
    'updateDriverLocation sends updated_at with explicit WIB offset',
    () async {
      http.Request? capturedRequest;
      final service = DriverOrderService(
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"success":true,"data":{}}', 200);
        }),
      );

      await service.updateDriverLocation(
        orderId: '42',
        latitude: -7.0545396,
        longitude: 110.4359656,
        updatedAt: DateTime.utc(2026, 6, 15, 13, 31, 34),
      );

      final request = capturedRequest!;
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(request.method, 'PATCH');
      expect(request.url.path, endsWith('/api/v1/driver/orders/42/location'));
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(body['updated_at'], '2026-06-15T20:31:34+07:00');
    },
  );

  test(
    'updateCurrentDriverLocation sends updated_at with explicit WIB offset',
    () async {
      http.Request? capturedRequest;
      final service = DriverOrderService(
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"success":true,"data":{}}', 200);
        }),
      );

      await service.updateCurrentDriverLocation(
        latitude: -7.0545396,
        longitude: 110.4359656,
        updatedAt: DateTime.utc(2026, 6, 15, 13, 31, 34),
      );

      final request = capturedRequest!;
      final body = jsonDecode(request.body) as Map<String, dynamic>;

      expect(request.method, 'PATCH');
      expect(request.url.path, endsWith('/api/v1/driver/location'));
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(body['updated_at'], '2026-06-15T20:31:34+07:00');
    },
  );
}
