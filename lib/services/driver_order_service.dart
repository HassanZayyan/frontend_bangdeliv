import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import '../models/driver_order_model.dart';
import 'auth_service.dart';

class DriverOrderService {
  static const Duration _timeout = Duration(seconds: 12);
  static const Duration _listTimeout = Duration(seconds: 8);
  static const Duration _detailTimeout = Duration(seconds: 10);

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

  Future<DriverOrderModel> fetchOrderDetail(String orderId) async {
    final response = await _safeGet(
      '/v1/driver/orders/$orderId',
      timeout: _detailTimeout,
    );
    final data = _extractData(response);

    if (data.isEmpty) {
      throw const DriverOrderApiException(
        'Detail order driver tidak ditemukan.',
        statusCode: 404,
      );
    }

    return DriverOrderModel.fromJson(data);
  }

  Future<void> transitionOrderStatus(String orderId, String actionCode) async {
    await _post(
      '/v1/driver/orders/$orderId/status-transition',
      body: <String, dynamic>{'action_code': actionCode},
      fallback: 'Gagal memproses transisi status order.',
    );
  }

  Future<DriverOrderModel> transitionStatus({
    required String orderId,
    required String actionCode,
    String? targetStatusCode,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final normalizedTargetStatusCode = targetStatusCode?.trim();
    final normalizedNote = note?.trim();

    final response = await _post(
      '/v1/driver/orders/$orderId/status-transition',
      body: <String, dynamic>{
        'action_code': actionCode,
        if (normalizedTargetStatusCode != null &&
            normalizedTargetStatusCode.isNotEmpty)
          'target_status_code': normalizedTargetStatusCode,
        if (normalizedNote != null && normalizedNote.isNotEmpty)
          'note': normalizedNote,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
      fallback: 'Gagal memproses transisi status order.',
    );

    final data = _extractData(response);
    if (data.isEmpty) {
      throw const DriverOrderApiException(
        'Respons transisi status tidak valid.',
        statusCode: 500,
      );
    }

    return DriverOrderModel.fromJson(data);
  }

  Future<void> updateLocation(
    String orderId,
    double lat,
    double lng,
    double heading,
  ) async {
    final response = await _post(
      '/v1/driver/orders/$orderId/location',
      body: <String, dynamic>{
        'latitude': lat,
        'longitude': lng,
        'heading': heading,
      },
      fallback: 'Gagal memancarkan lokasi.',
      timeout: const Duration(seconds: 5),
    );

    final data = _extractData(response);
    if (data.containsKey('location_saved') && data['location_saved'] != true) {
      throw const DriverOrderApiException(
        'Lokasi driver belum berhasil dikirim ke server.',
        statusCode: 500,
      );
    }
  }

  Future<void> collectCod({
    required String orderId,
    required double amount,
    String? note,
  }) async {
    final normalizedNote = note?.trim();

    await _post(
      '/v1/orders/$orderId/payment/collect-cod',
      body: <String, dynamic>{
        'amount': amount,
        if (normalizedNote != null && normalizedNote.isNotEmpty)
          'note': normalizedNote,
      },
      fallback: 'Gagal mencatat pembayaran COD.',
    );
  }

  Future<DriverOrderModel> updateShoppingItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? receiptNote,
  }) async {
    final response = await _patch(
      '/v1/driver/orders/$orderId/shopping-items',
      body: <String, dynamic>{
        'items': items,
        if ((receiptNote ?? '').trim().isNotEmpty)
          'receipt_note': receiptNote!.trim(),
      },
    );

    final data = _extractData(response);
    if (data.isEmpty) {
      throw const DriverOrderApiException(
        'Respons update nota tidak valid.',
        statusCode: 500,
      );
    }

    return DriverOrderModel.fromJson(data);
  }

  Future<DriverOrderModel> recordShoppingPickupFailed({
    required String orderId,
    required int pickupLocationId,
    required String reason,
  }) async {
    await _post(
      '/v1/orders/$orderId/attempt-failed',
      body: <String, dynamic>{
        'failure_type': 'PICKUP',
        'reason': reason.trim(),
        if (pickupLocationId > 0) 'pickup_location_id': pickupLocationId,
      },
      fallback: 'Gagal mencatat merchant tutup.',
    );

    return fetchOrderDetail(orderId);
  }

  Future<String> fetchAvailabilityStatus() async {
    final response = await _safeGet(
      '/v1/driver/availability',
      timeout: _listTimeout,
    );
    final data = _extractData(response);
    final status = (data['status'] ?? 'offline')
        .toString()
        .trim()
        .toLowerCase();
    return status.isEmpty ? 'offline' : status;
  }

  Future<String> updateAvailability({required bool isOnline}) async {
    final response = await _patch(
      '/v1/driver/availability',
      body: <String, dynamic>{'is_online': isOnline},
    );

    final data = _extractData(response);
    final status = (data['status'] ?? 'offline')
        .toString()
        .trim()
        .toLowerCase();
    return status.isEmpty ? 'offline' : status;
  }

  Future<DriverOrdersPayload> fetchOrders() async {
    final response = await _safeGet('/v1/driver/orders', timeout: _listTimeout);
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
  }

  Future<List<DriverHistoryOrderModel>> fetchHistory() async {
    final response = await _safeGet(
      '/v1/driver/history',
      timeout: _listTimeout,
    );
    final data = _extractData(response);
    final historyRaw = _extractList(
      data['history_orders'] ?? data['history'] ?? data['orders'],
    );

    return historyRaw
        .map(DriverHistoryOrderModel.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, query: query);
    final headers = await AuthService.authorizedHeaders(
      includeJsonContentType: false,
    );

    final response = await http
        .get(uri, headers: headers)
        .timeout(timeout ?? _timeout);

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

  Future<Map<String, dynamic>> _safeGet(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    try {
      return await _get(path, query: query, timeout: timeout);
    } on TimeoutException {
      throw const DriverOrderApiException(
        'Koneksi timeout. Pastikan backend aktif dan API_BASE_URL benar.',
        statusCode: 408,
      );
    } on http.ClientException {
      throw const DriverOrderApiException(
        'Gagal terhubung ke server. Cek API_BASE_URL dan jaringan perangkat.',
        statusCode: 0,
      );
    } on FormatException {
      throw const DriverOrderApiException(
        'Format respons server tidak valid.',
        statusCode: 500,
      );
    }
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

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
    String fallback = 'Gagal memproses aksi order driver.',
    Duration timeout = _timeout,
  }) async {
    final uri = _buildUri(path);
    final headers = await AuthService.authorizedHeaders();
    final payload = body ?? const <String, dynamic>{};

    late final http.Response response;
    try {
      response = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(timeout);
    } on TimeoutException {
      throw const DriverOrderApiException(
        'Koneksi timeout. Pastikan backend aktif dan API_BASE_URL benar.',
        statusCode: 408,
      );
    } on http.ClientException {
      throw const DriverOrderApiException(
        'Gagal terhubung ke server. Cek API_BASE_URL dan jaringan perangkat.',
        statusCode: 0,
      );
    } on FormatException {
      throw const DriverOrderApiException(
        'Format respons server tidak valid.',
        statusCode: 500,
      );
    }

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
      AuthService.extractErrorMessage(response, fallback: fallback),
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> _patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final headers = await AuthService.authorizedHeaders();
    final payload = body ?? const <String, dynamic>{};

    late final http.Response response;
    try {
      response = await http
          .patch(uri, headers: headers, body: jsonEncode(payload))
          .timeout(_timeout);
    } on TimeoutException {
      throw const DriverOrderApiException(
        'Koneksi timeout. Pastikan backend aktif dan API_BASE_URL benar.',
        statusCode: 408,
      );
    } on http.ClientException {
      throw const DriverOrderApiException(
        'Gagal terhubung ke server. Cek API_BASE_URL dan jaringan perangkat.',
        statusCode: 0,
      );
    } on FormatException {
      throw const DriverOrderApiException(
        'Format respons server tidak valid.',
        statusCode: 500,
      );
    }

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
        fallback: 'Gagal memperbarui status kerja driver.',
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
