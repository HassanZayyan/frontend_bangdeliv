import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_bangdeliv/features/chatbot/presentation/utils/chatbot_message_text.dart';

void main() {
  group('parseInlineBoldSegments', () {
    test('text tanpa penanda tetap satu segmen normal', () {
      final segments = parseInlineBoldSegments('halo dunia');

      expect(segments.length, 1);
      expect(segments.single.text, 'halo dunia');
      expect(segments.single.isBold, isFalse);
    });

    test('memisahkan segmen bold di tengah teks', () {
      final segments = parseInlineBoldSegments(
        'pastikan **sudah terdaftar** di BangDeliv',
      );

      expect(segments.map((s) => s.text).toList(), [
        'pastikan ',
        'sudah terdaftar',
        ' di BangDeliv',
      ]);
      expect(segments.map((s) => s.isBold).toList(), [false, true, false]);
    });

    test('mendukung beberapa penanda bold', () {
      final segments = parseInlineBoldSegments(
        'ketuk **Pilih Toko/Resto** lalu **Cari lewat Maps**',
      );

      final bold = segments.where((s) => s.isBold).map((s) => s.text).toList();
      expect(bold, ['Pilih Toko/Resto', 'Cari lewat Maps']);
    });

    test('penanda tak berpasangan diperlakukan sebagai teks biasa', () {
      final segments = parseInlineBoldSegments('harga **spesial hari ini');

      expect(segments.length, 1);
      expect(segments.single.isBold, isFalse);
      expect(segments.single.text, 'harga **spesial hari ini');
    });

    test('string kosong menghasilkan satu segmen kosong non-bold', () {
      final segments = parseInlineBoldSegments('');

      expect(segments.length, 1);
      expect(segments.single.text, '');
      expect(segments.single.isBold, isFalse);
    });
  });
}
