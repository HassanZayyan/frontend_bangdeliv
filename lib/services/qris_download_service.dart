import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/payment_assets.dart';
import 'api_exception.dart';

class QrisDownloadException implements Exception {
  const QrisDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class QrisDownloadService {
  QrisDownloadService({
    http.Client? client,
    MethodChannel channel = const MethodChannel('bangdeliv/gallery'),
  }) : _client = client ?? http.Client(),
       _channel = channel;

  final http.Client _client;
  final MethodChannel _channel;

  static const _timeout = Duration(seconds: 20);

  Future<void> downloadQrisToGallery({String? fileName}) async {
    late final http.Response response;
    try {
      response = await _client
          .get(Uri.parse(PaymentAssets.qrisUrl))
          .timeout(_timeout);
    } on TimeoutException {
      throw const QrisDownloadException(ApiException.timeoutMessage);
    } on http.ClientException {
      throw const QrisDownloadException(ApiException.noInternetMessage);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const QrisDownloadException('QRIS belum bisa diunduh.');
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw const QrisDownloadException('File QRIS kosong.');
    }

    await saveImageToGallery(
      bytes,
      fileName: fileName ?? defaultFileName(),
      mimeType: 'image/jpeg',
    );
  }

  Future<String?> saveImageToGallery(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    try {
      return _channel.invokeMethod<String>('saveImageToGallery', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
      });
    } on MissingPluginException {
      throw const QrisDownloadException(
        'Download QRIS ke galeri hanya tersedia di Android.',
      );
    } on PlatformException catch (error) {
      throw QrisDownloadException(
        error.message?.trim().isNotEmpty == true
            ? error.message!
            : 'QRIS gagal disimpan ke galeri.',
      );
    }
  }

  static String defaultFileName([DateTime? now]) {
    final value = now ?? DateTime.now();
    final date =
        '${value.year.toString().padLeft(4, '0')}'
        '${value.month.toString().padLeft(2, '0')}'
        '${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}'
        '${value.second.toString().padLeft(2, '0')}';

    return 'bangdeliv_qris_${date}_$time.jpeg';
  }

  void close() {
    _client.close();
  }
}
