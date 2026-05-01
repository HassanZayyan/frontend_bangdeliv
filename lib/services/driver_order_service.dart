import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import '../models/driver_order_model.dart';
import 'auth_service.dart';

class DriverOrderService {
  static const Duration _timeout = Duration(seconds: 20);

  Future<void> acceptOrder(String orderId) async {
    await _postWithFallbackPaths([
      '/v1/driver/orders/$orderId/accept',
      '/v1/driver/order/$orderId/accept',
      '/v1/driver/orders/$orderId/actions/accept',
    ]);
  }

  Future<void> rejectOrder(String orderId) async {
    await _postWithFallbackPaths([
      '/v1/driver/orders/$orderId/reject',
      '/v1/driver/order/$orderId/reject',
      '/v1/driver/orders/$orderId/actions/reject',
    ]);
  }

  Future<void> transitionOrderStatus(String orderId, String actionCode) async {
    await _postJson(
      '/v1/driver/orders/$orderId/status-transition',
      body: {'action_code': actionCode},
      fallback: 'Gagal memproses transisi status order.',
    );
  }

  Future<void> updateLocation(
    String orderId,
    double lat,
    double lng,
    double heading,
  ) async {
    await _postJson(
      '/v1/driver/orders/$orderId/location',
      body: {
        'latitude': lat,
        'longitude': lng,
        'heading': heading,
      },
      fallback: 'Gagal memancarkan lokasi.',
      timeout: const Duration(seconds: 5),
    );
  }

  Future<DriverOrdersPayload> fetchOrders() async {
    try {
      final response = await _get('/v1/driver/orders');
      final data = _extractData(response);

      final incomingRaw = _extractList(
        data['incoming_orders'] ?? data['incoming'] ?? data['new_orders'],
      );
      final runningRaw = _extractList(
        data['running_orders'] ?? data['running'] ?? data['active_orders'],
      );

      return DriverOrdersPayload(
        incoming: incomingRaw
            .map(DriverOrderModel.fromJson)
            .toList(growable: false),
        running: runningRaw
            .map(DriverOrderModel.fromJson)
            .toList(growable: false),
      );
    } on AuthException {
      rethrow;
    } on DriverOrderApiException {
      rethrow;
    } catch (_) {
      throw const DriverOrderApiException(
        'Gagal mengambil data order driver.',
        statusCode: 500,
      );
    }
  }

  Future<List<DriverHistoryOrderModel>> fetchHistory() async {
    try {
      final response = await _get('/v1/driver/history');
      final data = _extractData(response);
      final historyRaw = _extractList(
        data['history_orders'] ?? data['history'] ?? data['orders'],
      );

      return historyRaw
          .map(DriverHistoryOrderModel.fromJson)
          .toList(growable: false);
    } on AuthException {
      rethrow;
    } on DriverOrderApiException {
      rethrow;
    } catch (_) {
      throw const DriverOrderApiException(
        'Gagal mengambil riwayat driver.',
        statusCode: 500,
      );
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _buildUri(path, query: query);
    final headers = await AuthService.authorizedHeaders(
      includeJsonContentType: false,
    );

    final response = await http.get(uri, headers: headers).timeout(_timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return const <String, dynamic>{};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return const <String, dynamic>{};
    }

    throw DriverOrderApiException(
      AuthService.extractErrorMessage(
        response,
        fallback: 'Gagal mengambil data order driver.',
      ),
      statusCode: response.statusCode,
    );
  }

  Future<void> _postWithFallbackPaths(List<String> paths) async {
    DriverOrderApiException? lastError;

    for (final path in paths) {
      try {
        await _post(path);
        return;
      } on DriverOrderApiException catch (error) {
        if (error.statusCode == 404) {
          lastError = error;
          continue;
        }
        rethrow;
      }
    }

    if (lastError != null && lastError.statusCode == 404) {
      throw const DriverOrderApiException(
        'Aksi order belum tersedia di server. Coba lagi nanti.',
        statusCode: 404,
      );
    }

    throw lastError ??
        const DriverOrderApiException(
          'Gagal memproses aksi order driver.',
          statusCode: 500,
        );
  }

  Future<void> _post(String path) async {
    await _postJson(
      path,
      body: const <String, dynamic>{},
      fallback: 'Gagal memproses aksi order driver.',
    );
  }

  Future<void> _postJson(
    String path, {
    required Map<String, dynamic> body,
    required String fallback,
    Duration timeout = _timeout,
  }) async {
    final uri = _buildUri(path);
    final headers = await AuthService.authorizedHeaders(
      includeJsonContentType: true,
    );

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(timeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw DriverOrderApiException(
      AuthService.extractErrorMessage(
        response,
        fallback: fallback,
      ),
      statusCode: response.statusCode,
    );
  }

  Uri _buildUri(String path, {Map<String, String>? query}) {
    final base = Uri.parse(AppEnv.apiBaseUrl);
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final fullPath = base.path.endsWith('/')
        ? '${base.path}$normalizedPath'
        : '${base.path}/$normalizedPath';

    return base.replace(
      path: fullPath,
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractList(dynamic value) {
    if (value is! List<dynamic>) {
      return const <Map<String, dynamic>>[];
    }

    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }
}

class DriverOrderApiException implements Exception {
  final String message;
  final int statusCode;

  const DriverOrderApiException(this.message, {required this.statusCode});

  @override
  String toString() => message;
}
