import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_env.dart';
import '../models/driver_verification_model.dart';
import 'auth_service.dart';

class DriverVerificationService {
  static Future<DriverVerificationStatusModel> fetchMyStatus() async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/v1/driver/verification');

    try {
      final response = await http
          .get(uri, headers: await AuthService.authorizedHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return _parseStatus(response);
      }

      throw DriverVerificationException(
        AuthService.extractErrorMessage(
          response,
          fallback: 'Gagal mengambil status verifikasi driver.',
        ),
      );
    } on TimeoutException {
      throw const DriverVerificationException(
        'Koneksi ke server timeout. Silakan coba lagi.',
      );
    } on AuthException catch (e) {
      throw DriverVerificationException(e.message);
    } on DriverVerificationException {
      rethrow;
    } catch (_) {
      throw const DriverVerificationException(
        'Gagal terhubung ke server verifikasi driver.',
      );
    }
  }

  static Future<DriverVerificationStatusModel> submitDocuments({
    XFile? ktp,
    XFile? sim,
    XFile? selfie,
  }) async {
    if (ktp == null && sim == null && selfie == null) {
      throw const DriverVerificationException(
        'Pilih minimal satu dokumen untuk diunggah.',
      );
    }

    final uri = Uri.parse(
      '${AppEnv.apiBaseUrl}/v1/driver/verification/documents',
    );

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(
        await AuthService.authorizedHeaders(includeJsonContentType: false),
      );

      if (ktp != null) {
        request.files.add(await http.MultipartFile.fromPath('ktp', ktp.path));
      }

      if (sim != null) {
        request.files.add(await http.MultipartFile.fromPath('sim', sim.path));
      }

      if (selfie != null) {
        request.files.add(
          await http.MultipartFile.fromPath('selfie', selfie.path),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseStatus(response);
      }

      throw DriverVerificationException(
        AuthService.extractErrorMessage(
          response,
          fallback: 'Gagal mengunggah dokumen driver.',
        ),
      );
    } on TimeoutException {
      throw const DriverVerificationException(
        'Upload dokumen timeout. Silakan coba lagi.',
      );
    } on AuthException catch (e) {
      throw DriverVerificationException(e.message);
    } on DriverVerificationException {
      rethrow;
    } catch (_) {
      throw const DriverVerificationException(
        'Terjadi kesalahan saat mengunggah dokumen.',
      );
    }
  }

  static Future<void> cancelApplication() async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/v1/driver/verification');

    try {
      final response = await http
          .delete(uri, headers: await AuthService.authorizedHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw DriverVerificationException(
        AuthService.extractErrorMessage(
          response,
          fallback: 'Gagal membatalkan pengajuan driver.',
        ),
      );
    } on TimeoutException {
      throw const DriverVerificationException(
        'Koneksi ke server timeout. Silakan coba lagi.',
      );
    } on AuthException catch (e) {
      throw DriverVerificationException(e.message);
    } on DriverVerificationException {
      rethrow;
    } catch (_) {
      throw const DriverVerificationException(
        'Terjadi kesalahan saat membatalkan pengajuan driver.',
      );
    }
  }

  static DriverVerificationStatusModel _parseStatus(http.Response response) {
    final dynamic decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const DriverVerificationException(
        'Format respons verifikasi tidak valid.',
      );
    }

    final data = (decoded['data'] as Map<String, dynamic>?) ?? const {};
    return DriverVerificationStatusModel.fromJson(data);
  }
}

class DriverVerificationException implements Exception {
  final String message;

  const DriverVerificationException(this.message);

  @override
  String toString() => message;
}
