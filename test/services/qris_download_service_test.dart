import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/config/payment_assets.dart';
import 'package:frontend_bangdeliv/services/qris_download_service.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bangdeliv/gallery');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('downloads QRIS bytes and saves them through gallery channel', () async {
    final savedCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      savedCalls.add(call);
      return 'content://media/external/images/media/1';
    });

    final client = _FakeHttpClient(
      statusCode: 200,
      bytes: Uint8List.fromList([1, 2, 3, 4]),
    );
    final service = QrisDownloadService(client: client, channel: channel);
    addTearDown(service.close);

    await service.downloadQrisToGallery(fileName: 'qris-test.jpeg');

    expect(client.lastUri, Uri.parse(PaymentAssets.qrisUrl));
    expect(savedCalls, hasLength(1));
    expect(savedCalls.single.method, 'saveImageToGallery');

    final args = savedCalls.single.arguments as Map<Object?, Object?>;
    expect(args['fileName'], 'qris-test.jpeg');
    expect(args['mimeType'], 'image/jpeg');
    expect(args['bytes'], Uint8List.fromList([1, 2, 3, 4]));
  });

  test('throws friendly error when QRIS download fails', () async {
    final service = QrisDownloadService(
      client: _FakeHttpClient(statusCode: 404, bytes: Uint8List(0)),
      channel: channel,
    );
    addTearDown(service.close);

    expect(
      service.downloadQrisToGallery(),
      throwsA(
        isA<QrisDownloadException>().having(
          (error) => error.message,
          'message',
          'QRIS belum bisa diunduh.',
        ),
      ),
    );
  });

  test('default file name is stable and gallery friendly', () {
    final fileName = QrisDownloadService.defaultFileName(
      DateTime(2026, 6, 15, 21, 30, 5),
    );

    expect(fileName, 'bangdeliv_qris_20260615_213005.jpeg');
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({required this.statusCode, required this.bytes});

  final int statusCode;
  final Uint8List bytes;
  Uri? lastUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;

    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      headers: {'content-type': 'image/jpeg'},
    );
  }
}
