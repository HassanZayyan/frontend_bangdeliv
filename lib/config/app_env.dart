import 'package:flutter/foundation.dart';

class AppEnv {
  AppEnv._();

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get apiBaseUrl {
    final override = _apiBaseUrlOverride.trim();
    if (override.isNotEmpty) {
      return _withoutTrailingSlash(override);
    }

    return _defaultApiBaseUrl;
  }

  static String get _defaultApiBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }

    return switch (defaultTargetPlatform) {
      // Fallback for physical Android devices on same LAN.
      TargetPlatform.android => 'http://192.168.1.89:8000/api',
      _ => 'http://localhost:8000/api',
    };
  }

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  static bool get hasGoogleMapsApiKey => googleMapsApiKey.trim().isNotEmpty;

  /// Laravel Reverb WebSocket - same host, different port.
  static String get wsHost {
    final uri = Uri.parse(apiBaseUrl);
    return uri.host;
  }

  static String get backendOrigin {
    final uri = Uri.parse(apiBaseUrl);
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  static String resolveBackendAssetUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }

    if (raw.startsWith('//')) {
      final apiUri = Uri.parse(apiBaseUrl);
      return '${apiUri.scheme}:$raw';
    }

    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme) {
      return _normalizeLoopbackUrl(parsed);
    }

    final normalizedPath = raw.startsWith('/') ? raw : '/storage/$raw';
    return '$backendOrigin$normalizedPath';
  }

  static const int wsPort = int.fromEnvironment('WS_PORT', defaultValue: 8080);

  static const String wsScheme = String.fromEnvironment(
    'WS_SCHEME',
    defaultValue: 'ws',
  );

  static String get normalizedWsScheme {
    final normalized = wsScheme.trim().toLowerCase();
    return normalized == 'https' || normalized == 'wss' ? 'wss' : 'ws';
  }

  static const String pusherAppKey = String.fromEnvironment('PUSHER_APP_KEY');

  static bool get hasPusherAppKey => pusherAppKey.trim().isNotEmpty;

  static const String pusherCluster = String.fromEnvironment(
    'PUSHER_CLUSTER',
    defaultValue: 'mt1',
  );

  static const bool realtimeDiagnostics = bool.fromEnvironment(
    'REALTIME_DIAGNOSTICS',
    defaultValue: false,
  );

  static void logDebugSummary() {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[AppEnv] API_BASE_URL=$apiBaseUrl');
    debugPrint('[AppEnv] BACKEND_ORIGIN=$backendOrigin');
    debugPrint('[AppEnv] WS=$normalizedWsScheme://$wsHost:$wsPort');
    debugPrint('[AppEnv] GOOGLE_MAPS_API_KEY configured=$hasGoogleMapsApiKey');
    debugPrint('[AppEnv] PUSHER_APP_KEY configured=$hasPusherAppKey');
    debugPrint('[AppEnv] REALTIME_DIAGNOSTICS=$realtimeDiagnostics');
  }

  static String _withoutTrailingSlash(String value) {
    return value.replaceFirst(RegExp(r'/+$'), '');
  }

  static String _normalizeLoopbackUrl(Uri uri) {
    final host = uri.host.trim().toLowerCase();
    final isLoopbackHost =
        host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';

    if (!isLoopbackHost) {
      return uri.toString();
    }

    final apiUri = Uri.parse(apiBaseUrl);
    if (apiUri.host.toLowerCase() == host) {
      return uri.toString();
    }

    return uri
        .replace(
          scheme: apiUri.scheme,
          host: apiUri.host,
          port: apiUri.hasPort ? apiUri.port : null,
        )
        .toString();
  }
}
