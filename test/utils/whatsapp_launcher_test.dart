import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/whatsapp_launcher.dart';

void main() {
  test('normalizes Indonesian WhatsApp numbers', () {
    expect(
      normalizeIndonesianWhatsAppNumber('0812-3456-7890'),
      '6281234567890',
    );
    expect(
      normalizeIndonesianWhatsAppNumber('+62 812 3456 7890'),
      '6281234567890',
    );
    expect(normalizeIndonesianWhatsAppNumber('81234567890'), '6281234567890');
  });

  test('rejects empty and invalid WhatsApp numbers', () {
    expect(normalizeIndonesianWhatsAppNumber(null), isNull);
    expect(normalizeIndonesianWhatsAppNumber('-'), isNull);
    expect(normalizeIndonesianWhatsAppNumber('12345'), isNull);
  });

  test('builds contextual wa.me order URI', () {
    final uri = buildOrderWhatsAppUri(
      phone: '081234567890',
      participantName: 'Muhammad Zaky',
      orderId: 99,
    );

    expect(uri?.host, 'wa.me');
    expect(uri?.path, '/6281234567890');
    expect(uri?.queryParameters['text'], contains('Muhammad Zaky'));
    expect(uri?.queryParameters['text'], contains('#99'));
  });
}
