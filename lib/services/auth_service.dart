import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_env.dart';
import '../models/user_profile_model.dart';

class AuthService {
  static const String _tokenStorageKey = 'access_token';
  static const String _lastEmailStorageKey = 'last_login_email';
  static const String _lastPasswordStorageKey = 'last_login_password';

  static Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/register/customer');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'phone': phone,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201) {
        return;
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Pendaftaran gagal.'),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<void> upgradeToDriver({
    required String vehiclePlate,
    required String licenseNumber,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/upgrade-to-driver');

    try {
      final response = await http
          .post(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({
              'vehicle_plate': vehiclePlate,
              'license_number': licenseNumber,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201) {
        return;
      }

      throw AuthException(
        _extractErrorMessage(
          response,
          fallback: 'Upgrade akun ke driver gagal.',
        ),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/login');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        await _persistAccessToken(response);
        await _persistLastLoginCredentials(email: email, password: password);
        return;
      }

      final message = _extractErrorMessage(response, fallback: 'Login gagal.');
      throw AuthException(_normalizeLoginErrorMessage(message));
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<UserProfileModel> fetchCurrentUserProfile() async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user');

    try {
      final response = await http
          .get(uri, headers: await authorizedHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> data =
            (payload['data'] as Map<String, dynamic>?) ?? const {};

        final normalizedData = Map<String, dynamic>.from(data);
        final avatarUrl = _normalizeAvatarUrl(normalizedData);
        if (avatarUrl != null) {
          normalizedData['avatar_url'] = avatarUrl;
        }

        return UserProfileModel.fromJson(normalizedData);
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal mengambil profil.'),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<UserProfileModel> updateCurrentUserProfile({
    required String name,
    required String phone,
    required String email,
    String? avatarPath,
    bool removeAvatar = false,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user');
    final normalizedAvatarPath = avatarPath?.trim();

    try {
      if (normalizedAvatarPath != null && normalizedAvatarPath.isNotEmpty) {
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(
          await authorizedHeaders(includeJsonContentType: false),
        );
        request.fields['_method'] = 'PUT';
        request.fields['name'] = name;
        request.fields['phone'] = phone;
        request.fields['email'] = email;
        if (removeAvatar) {
          request.fields['remove_avatar'] = '1';
        }
        request.files.add(
          await http.MultipartFile.fromPath('avatar', normalizedAvatarPath),
        );

        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
        );
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          return _parseProfileResponse(response);
        }

        throw AuthException(
          _extractErrorMessage(response, fallback: 'Gagal memperbarui profil.'),
        );
      }

      final response = await http
          .put(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({
              'name': name,
              'phone': phone,
              'email': email,
              if (removeAvatar) 'remove_avatar': true,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return _parseProfileResponse(response);
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal memperbarui profil.'),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<List<SavedAddressModel>> fetchSavedAddresses() async {
    final profile = await fetchCurrentUserProfile();
    return profile.addresses;
  }

  static Future<AddressValidationResult> validateSavedAddress({
    required String fullAddress,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/addresses/validate');

    try {
      final response = await http
          .post(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({'full_address': fullAddress.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> data =
            (payload['data'] as Map<String, dynamic>?) ?? const {};

        return AddressValidationResult.fromJson(data);
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal memvalidasi alamat.'),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<SavedAddressModel> createSavedAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String detail = '',
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/addresses');

    try {
      final response = await http
          .post(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({
              'label': label,
              'recipient_name': recipientName,
              'phone': phone,
              'full_address': fullAddress,
              'detail': detail,
              ...?(latitude == null
                  ? null
                  : <String, dynamic>{'latitude': latitude}),
              ...?(longitude == null
                  ? null
                  : <String, dynamic>{'longitude': longitude}),
              'is_default': isDefault,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> data =
            (payload['data'] as Map<String, dynamic>?) ?? const {};

        return SavedAddressModel.fromJson(data);
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal menyimpan alamat.'),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<SavedAddressModel> updateSavedAddress({
    required int addressId,
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String detail = '',
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/addresses/$addressId');

    try {
      final response = await http
          .put(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({
              'label': label,
              'recipient_name': recipientName,
              'phone': phone,
              'full_address': fullAddress,
              'detail': detail,
              ...?(latitude == null
                  ? null
                  : <String, dynamic>{'latitude': latitude}),
              ...?(longitude == null
                  ? null
                  : <String, dynamic>{'longitude': longitude}),
              'is_default': isDefault,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> data =
            (payload['data'] as Map<String, dynamic>?) ?? const {};

        return SavedAddressModel.fromJson(data);
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal memperbarui alamat.'),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<void> deleteSavedAddress({required int addressId}) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/addresses/$addressId');

    try {
      final response = await http
          .delete(uri, headers: await authorizedHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return;
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal menghapus alamat.'),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/password');

    try {
      final response = await http
          .put(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
              'new_password_confirmation': newPasswordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        await _persistAccessToken(response);
        await _persistLastLoginPassword(newPassword);
        return;
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal mengganti password.'),
      );
    } on TimeoutException {
      throw const AuthException(
        'Koneksi ke server timeout. Coba cek backend kamu berjalan.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Gagal terhubung ke server. Periksa API_BASE_URL dan koneksi jaringan.',
      );
    }
  }

  static Future<void> logout() async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/logout');

    try {
      await http
          .post(uri, headers: await authorizedHeaders())
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Clear local token even if remote revoke fails.
    }

    await _clearAccessToken();
  }

  static Future<bool> hasAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenStorageKey)?.trim() ?? '';

    return token.isNotEmpty;
  }

  static Future<void> clearLocalSession() async {
    await _clearAccessToken();
  }

  static Future<LoginCredentials?> getLastLoginCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (prefs.getString(_lastEmailStorageKey) ?? '').trim();
    final password = prefs.getString(_lastPasswordStorageKey) ?? '';

    if (email.isEmpty || password.isEmpty) {
      return null;
    }

    return LoginCredentials(email: email, password: password);
  }

  static Future<String> requireAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenStorageKey);

    if (token == null || token.trim().isEmpty) {
      throw const AuthException(
        'Sesi login tidak ditemukan. Silakan login ulang.',
      );
    }

    return token;
  }

  static Future<Map<String, String>> authorizedHeaders({
    bool includeJsonContentType = true,
  }) async {
    final token = await requireAccessToken();

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }

  static String extractErrorMessage(
    http.Response response, {
    required String fallback,
  }) {
    return _extractErrorMessage(response, fallback: fallback);
  }

  static UserProfileModel _parseProfileResponse(http.Response response) {
    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final Map<String, dynamic> data =
        (payload['data'] as Map<String, dynamic>?) ?? const {};

    final normalizedData = Map<String, dynamic>.from(data);
    final avatarUrl = _normalizeAvatarUrl(normalizedData);
    if (avatarUrl != null) {
      normalizedData['avatar_url'] = avatarUrl;
    }

    return UserProfileModel.fromJson(normalizedData);
  }

  static String? _normalizeAvatarUrl(Map<String, dynamic> profileData) {
    final rawAvatarUrl = profileData['avatar_url']?.toString().trim() ?? '';
    final rawAvatarPath = profileData['avatar']?.toString().trim() ?? '';

    String candidate = rawAvatarUrl;
    if (candidate.isEmpty && rawAvatarPath.isNotEmpty) {
      candidate = rawAvatarPath.startsWith('http')
          ? rawAvatarPath
          : '/storage/$rawAvatarPath';
    }

    if (candidate.isEmpty) {
      return null;
    }

    final apiUri = Uri.parse(AppEnv.apiBaseUrl);
    final apiOrigin = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    ).toString();

    final parsedCandidate = Uri.tryParse(candidate);
    if (parsedCandidate != null && parsedCandidate.hasScheme) {
      final host = parsedCandidate.host.trim().toLowerCase();
      final isLoopbackHost =
          host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';

      if (isLoopbackHost && host != apiUri.host.toLowerCase()) {
        return parsedCandidate
            .replace(
              scheme: apiUri.scheme,
              host: apiUri.host,
              port: apiUri.hasPort ? apiUri.port : null,
            )
            .toString();
      }

      return candidate;
    }

    final normalizedPath = candidate.startsWith('/') ? candidate : '/$candidate';
    return '$apiOrigin$normalizedPath';
  }

  static Future<void> _persistAccessToken(http.Response response) async {
    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String token = (payload['access_token'] ?? '').toString();

    if (token.isEmpty) {
      throw const AuthException(
        'Token login tidak ditemukan pada response API.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
  }

  static Future<void> _clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenStorageKey);
  }

  static Future<void> _persistLastLoginCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEmailStorageKey, email.trim());
    await prefs.setString(_lastPasswordStorageKey, password);
  }

  static Future<void> _persistLastLoginPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPasswordStorageKey, password);
  }

  static String _normalizeLoginErrorMessage(String message) {
    final normalized = message.trim().toLowerCase();

    if (normalized.contains('kredensial tidak valid') ||
        normalized.contains('these credentials do not match our records') ||
        normalized.contains('invalid credentials')) {
      return 'Email atau password salah.';
    }

    return message;
  }

  static String _extractErrorMessage(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final Map<String, dynamic> payload =
          jsonDecode(response.body) as Map<String, dynamic>;

      final dynamic message = payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        final normalizedMessage = message.toLowerCase();

        // Avoid exposing raw SQL errors to end users.
        if (normalizedMessage.contains('sqlstate') ||
            normalizedMessage.contains('integrity constraint')) {
          return '$fallback (${response.statusCode}).';
        }

        return message;
      }

      final dynamic errors = payload['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final dynamic firstEntry = errors.values.first;
        if (firstEntry is List && firstEntry.isNotEmpty) {
          final dynamic firstError = firstEntry.first;
          if (firstError is String && firstError.trim().isNotEmpty) {
            return firstError;
          }
        }
      }
    } catch (_) {
      // Fallback message handled below.
    }

    return '$fallback (${response.statusCode}).';
  }
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class AddressValidationResult {
  final String formattedAddress;
  final double latitude;
  final double longitude;

  const AddressValidationResult({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory AddressValidationResult.fromJson(Map<String, dynamic> json) {
    return AddressValidationResult(
      formattedAddress: (json['formatted_address'] ?? '').toString(),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class LoginCredentials {
  final String email;
  final String password;

  const LoginCredentials({required this.email, required this.password});
}
