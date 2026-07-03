import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/services/auth_service.dart';
import 'package:http/http.dart' as http;

void main() {
  group('AuthService.extractErrorMessage', () {
    test(
      'localizes duplicate phone validation from Laravel English fallback',
      () {
        final response = http.Response(
          jsonEncode({
            'errors': {
              'phone': ['The nomor has already been taken.'],
            },
          }),
          422,
        );

        expect(
          AuthService.extractErrorMessage(
            response,
            fallback: 'Gagal menyimpan.',
          ),
          'Nomor WhatsApp sudah digunakan.',
        );
      },
    );

    test(
      'localizes required phone validation from Laravel English fallback',
      () {
        final response = http.Response(
          jsonEncode({
            'errors': {
              'phone': ['The phone field is required.'],
            },
          }),
          422,
        );

        expect(
          AuthService.extractErrorMessage(
            response,
            fallback: 'Gagal menyimpan.',
          ),
          'Nomor WhatsApp wajib diisi.',
        );
      },
    );
  });
}
