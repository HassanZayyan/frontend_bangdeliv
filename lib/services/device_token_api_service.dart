import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

class DeviceTokenApiService {
  DeviceTokenApiService(this._apiClient);

  final ApiClient _apiClient;

  static const Duration _deviceTokenTimeout = Duration(seconds: 10);

  Future<void> registerDeviceToken({
    required String token,
    String deviceType = 'android',
  }) async {
    try {
      await _apiClient.post(
        '/v1/device-tokens',
        body: <String, dynamic>{'token': token, 'device_type': deviceType},
        headers: await AuthService.authorizedHeaders(),
        timeout: _deviceTokenTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }
  }

  Future<void> unregisterDeviceToken({required String token}) async {
    try {
      await _apiClient.delete(
        '/v1/device-tokens',
        body: <String, dynamic>{'token': token},
        headers: await AuthService.authorizedHeaders(),
        timeout: _deviceTokenTimeout,
      );
    } on AuthException catch (error) {
      throw ApiException(error.message);
    }
  }
}
