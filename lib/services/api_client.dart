import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const Duration _timeout = Duration(seconds: 8);

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    final requestTimeout = timeout ?? _timeout;

    try {
      final response = await _httpClient
          .get(uri, headers: _defaultHeaders(headers))
          .timeout(requestTimeout);

      return _decodeResponse(response);
    } on TimeoutException {
      throw const ApiException('Permintaan timeout. Coba lagi.');
    } on http.ClientException {
      throw const ApiException('Tidak dapat terhubung ke server API.');
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    final requestTimeout = timeout ?? _timeout;

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _defaultHeaders(headers),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(requestTimeout);

      return _decodeResponse(response);
    } on TimeoutException {
      throw const ApiException('Permintaan timeout. Coba lagi.');
    } on http.ClientException {
      throw const ApiException('Tidak dapat terhubung ke server API.');
    }
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = _buildUri(path, queryParams);
    final requestTimeout = timeout ?? _timeout;

    try {
      final response = await _httpClient
          .delete(
            uri,
            headers: _defaultHeaders(headers),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(requestTimeout);

      return _decodeResponse(response);
    } on TimeoutException {
      throw const ApiException('Permintaan timeout. Coba lagi.');
    } on http.ClientException {
      throw const ApiException('Tidak dapat terhubung ke server API.');
    }
  }

  Uri _buildUri(String path, Map<String, dynamic>? queryParams) {
    final baseUri = Uri.parse(AppEnv.apiBaseUrl);

    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final fullPath = baseUri.path.endsWith('/')
        ? '${baseUri.path}$normalizedPath'
        : '${baseUri.path}/$normalizedPath';

    return baseUri.replace(
      path: fullPath,
      queryParameters: queryParams?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Map<String, String> _defaultHeaders(Map<String, String>? headers) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final dynamic decodedBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw ApiException(
        'Format respons tidak valid dari server.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    final message = decodedBody['message']?.toString() ?? 'Terjadi kesalahan.';

    throw ApiException(message, statusCode: response.statusCode);
  }
}
