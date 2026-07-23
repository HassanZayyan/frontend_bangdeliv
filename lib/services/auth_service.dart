import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_env.dart';
import '../models/user_profile_model.dart';
import 'api_exception.dart';

class AuthService {
  static const String _tokenStorageKey = 'access_token';
  static const String _lastEmailStorageKey = 'last_login_email';
  static const String _legacyLastPasswordStorageKey = 'last_login_password';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static Future<void>? _googleSignInInitialization;

  static Future<void> upgradeToDriver({
    required String vehicleType,
    required String vehicleBrand,
    required String vehicleModel,
    required String vehiclePlate,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/upgrade-to-driver');

    try {
      final response = await http
          .post(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({
              'vehicle_type': vehicleType.trim(),
              'vehicle_brand': vehicleBrand.trim(),
              'vehicle_model': vehicleModel.trim(),
              'vehicle_plate': vehiclePlate,
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
    } on TimeoutException catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.noInternetMessage);
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
        await _persistLastLoginEmail(email);
        return;
      }

      final message = _extractErrorMessage(response, fallback: 'Login gagal.');
      throw AuthException(_normalizeLoginErrorMessage(message));
    } on TimeoutException catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

  static Future<void> loginWithGoogle() async {
    if (!AppEnv.hasGoogleWebClientId) {
      throw const AuthException(
        'Google Sign-In belum dikonfigurasi. Isi GOOGLE_WEB_CLIENT_ID sesuai OAuth client web.',
      );
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/google');

    try {
      await _ensureGoogleSignInInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const AuthException(
          'Google Sign-In belum tersedia di platform ini.',
        );
      }

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken?.trim() ?? '';
      if (idToken.isEmpty) {
        throw const AuthException(
          'Token Google tidak ditemukan. Silakan coba masuk ulang.',
        );
      }

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id_token': idToken}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        await _persistAccessToken(response);
        await _persistLastLoginEmail(account.email);
        return;
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Login Google gagal.'),
      );
    } on TimeoutException catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Login Google dibatalkan.');
      }
      if (error.code == GoogleSignInExceptionCode.uiUnavailable) {
        throw const AuthException(
          'Google Sign-In tidak tersedia di perangkat ini.',
        );
      }
      throw AuthException(
        error.description?.trim().isNotEmpty == true
            ? error.description!.trim()
            : 'Login Google gagal. Silakan coba lagi.',
      );
    } catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

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
        await _persistLastLoginEmail(email);
        return;
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Pendaftaran gagal.'),
      );
    } on TimeoutException catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.noInternetMessage);
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
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

  static Future<UserProfileModel> updateCurrentUserProfile({
    required String name,
    required String phone,
    required String email,
    String? vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
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
        if (vehicleType != null) {
          request.fields['vehicle_type'] = vehicleType.trim();
        }
        if (vehicleBrand != null) {
          request.fields['vehicle_brand'] = vehicleBrand.trim();
        }
        if (vehicleModel != null) {
          request.fields['vehicle_model'] = vehicleModel.trim();
        }
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
              if (vehicleType != null) 'vehicle_type': vehicleType.trim(),
              if (vehicleBrand != null) 'vehicle_brand': vehicleBrand.trim(),
              if (vehicleModel != null) 'vehicle_model': vehicleModel.trim(),
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
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

  /// Meminta kode OTP dikirim ke email user yang sedang login.
  static Future<OtpSendResult> sendPhoneOtp() async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/otp/send');

    try {
      final response = await http
          .post(uri, headers: await authorizedHeaders())
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> payload =
            jsonDecode(response.body) as Map<String, dynamic>;
        final Map<String, dynamic> data =
            (payload['data'] as Map<String, dynamic>?) ?? const {};

        return OtpSendResult(
          alreadyVerified: data['already_verified'] == true,
          resendAvailableIn: _asIntOr(data['resend_available_in'], 60),
        );
      }

      if (response.statusCode == 429) {
        final int retryAfter = _retryAfterSeconds(response);
        throw OtpCooldownException(
          _extractErrorMessage(
            response,
            fallback: 'Tunggu beberapa saat sebelum meminta kode baru.',
          ),
          retryAfter,
        );
      }

      throw AuthException(
        _extractErrorMessage(
          response,
          fallback: 'Gagal mengirim kode verifikasi.',
        ),
      );
    } on TimeoutException {
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

  /// Memverifikasi kode OTP dan mengembalikan profil terbaru.
  static Future<UserProfileModel> verifyPhoneOtp({required String code}) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/otp/verify');

    try {
      final response = await http
          .post(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({'code': code.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return _parseProfileResponse(response);
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Verifikasi kode gagal.'),
      );
    } on TimeoutException {
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

  static int _retryAfterSeconds(http.Response response) {
    try {
      final Map<String, dynamic> payload =
          jsonDecode(response.body) as Map<String, dynamic>;

      return _asIntOr(payload['retry_after_seconds'], 60);
    } catch (_) {
      return 60;
    }
  }

  static int _asIntOr(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static Future<UserProfileModel> completePhone({required String phone}) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/phone');

    try {
      final response = await http
          .patch(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({'phone': phone.trim()}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return _parseProfileResponse(response);
      }

      throw AuthException(
        _extractErrorMessage(
          response,
          fallback: 'Gagal menyimpan nomor telepon.',
        ),
      );
    } on TimeoutException {
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
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
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
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
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
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
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
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
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
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
        return;
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal mengganti password.'),
      );
    } on TimeoutException {
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

  static Future<void> createPassword({
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/user/password');

    try {
      final response = await http
          .post(
            uri,
            headers: await authorizedHeaders(),
            body: jsonEncode({
              'new_password': newPassword,
              'new_password_confirmation': newPasswordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        await _persistAccessToken(response);
        return;
      }

      throw AuthException(
        _extractErrorMessage(response, fallback: 'Gagal membuat password.'),
      );
    } on TimeoutException {
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String phone,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/password/reset');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim(),
              'phone': phone.trim(),
              'new_password': newPassword,
              'new_password_confirmation': newPasswordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return;
      }

      throw AuthException(
        _extractErrorMessage(
          response,
          fallback: 'Gagal mengatur ulang password.',
        ),
      );
    } on TimeoutException catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.timeoutMessage);
    } on AuthException {
      rethrow;
    } catch (error) {
      _logNetworkFailure('POST', uri, error);
      throw const AuthException(ApiException.noInternetMessage);
    }
  }

  static Future<void> logout({Map<String, String>? headers}) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}/auth/logout');

    try {
      await http
          .post(uri, headers: headers ?? await authorizedHeaders())
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Clear local token even if remote revoke fails.
    }

    await _clearAccessToken();
  }

  static Future<bool> hasAccessToken() async {
    final token = (await _readAccessToken())?.trim() ?? '';

    return token.isNotEmpty;
  }

  static Future<void> clearLocalSession() async {
    await _clearAccessToken();
  }

  static Future<void> signOutFromGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google sign-out is best-effort; Bang Deliv session cleanup is separate.
    }
  }

  static Future<String?> getLastLoginEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = (prefs.getString(_lastEmailStorageKey) ?? '').trim();
    await prefs.remove(_legacyLastPasswordStorageKey);

    if (email.isEmpty) {
      return null;
    }

    return email;
  }

  static Future<String> requireAccessToken() async {
    final token = await _readAccessToken();

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

    final normalizedPath = candidate.startsWith('/')
        ? candidate
        : '/$candidate';
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
    await _secureStorage.write(key: _tokenStorageKey, value: token);
    await prefs.remove(_tokenStorageKey);
    await prefs.remove(_legacyLastPasswordStorageKey);
  }

  static Future<void> _clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _tokenStorageKey);
    await prefs.remove(_tokenStorageKey);
    await prefs.remove(_legacyLastPasswordStorageKey);
  }

  static Future<String?> _readAccessToken() async {
    final secureToken = await _secureStorage.read(key: _tokenStorageKey);
    if (secureToken != null && secureToken.trim().isNotEmpty) {
      return secureToken;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_tokenStorageKey);
    await prefs.remove(_legacyLastPasswordStorageKey);

    if (legacyToken == null || legacyToken.trim().isEmpty) {
      return null;
    }

    await _secureStorage.write(key: _tokenStorageKey, value: legacyToken);
    await prefs.remove(_tokenStorageKey);

    return legacyToken;
  }

  static Future<void> _persistLastLoginEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastEmailStorageKey, email.trim());
    await prefs.remove(_legacyLastPasswordStorageKey);
  }

  static Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? AppEnv.googleWebClientId : null,
      serverClientId: AppEnv.googleWebClientId,
    );
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

  static void _logNetworkFailure(String method, Uri uri, Object error) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[AuthService] $method $uri failed: $error');
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

        return _localizeServerMessage(message);
      }

      final dynamic errors = payload['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final dynamic firstEntry = errors.values.first;
        if (firstEntry is List && firstEntry.isNotEmpty) {
          final dynamic firstError = firstEntry.first;
          if (firstError is String && firstError.trim().isNotEmpty) {
            return _localizeServerMessage(firstError);
          }
        }
      }
    } catch (_) {
      // Fallback message handled below.
    }

    return '$fallback (${response.statusCode}).';
  }

  static String _localizeServerMessage(String message) {
    final trimmed = message.trim();
    final normalized = trimmed.toLowerCase();

    if (normalized.contains('has already been taken')) {
      if (normalized.contains('phone') || normalized.contains('nomor')) {
        return 'Nomor WhatsApp sudah digunakan.';
      }
      if (normalized.contains('email')) {
        return 'Email sudah digunakan.';
      }

      return 'Data sudah digunakan.';
    }

    if (normalized.contains('field is required')) {
      return '${_englishValidationAttributeLabel(normalized)} wajib diisi.';
    }

    if (normalized.contains('must be a valid email')) {
      return 'Email harus berupa alamat email yang valid.';
    }

    if (normalized.contains('must be a string')) {
      return '${_englishValidationAttributeLabel(normalized)} harus berupa teks.';
    }

    if (normalized.contains('may not be greater than')) {
      return '${_englishValidationAttributeLabel(normalized)} terlalu panjang.';
    }

    if (normalized.contains('must be at least')) {
      return '${_englishValidationAttributeLabel(normalized)} terlalu pendek.';
    }

    return trimmed;
  }

  static String _englishValidationAttributeLabel(String normalizedMessage) {
    if (normalizedMessage.contains('phone') ||
        normalizedMessage.contains('nomor')) {
      return 'Nomor WhatsApp';
    }
    if (normalizedMessage.contains('email')) {
      return 'Email';
    }
    if (normalizedMessage.contains('password')) {
      return 'Kata sandi';
    }
    if (normalizedMessage.contains('name')) {
      return 'Nama';
    }

    return 'Data';
  }
}

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Dilempar saat server menolak permintaan OTP karena masih dalam jeda kirim ulang.
class OtpCooldownException extends AuthException {
  final int retryAfterSeconds;

  const OtpCooldownException(super.message, this.retryAfterSeconds);
}

class OtpSendResult {
  final bool alreadyVerified;
  final int resendAvailableIn;

  const OtpSendResult({
    required this.alreadyVerified,
    required this.resendAvailableIn,
  });
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
