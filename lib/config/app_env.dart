class AppEnv {
  AppEnv._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.88:8000/api',
  );

  static const bool enableDriverMockFallback = bool.fromEnvironment(
    'ENABLE_DRIVER_MOCK_FALLBACK',
    defaultValue: true,
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'GOOGLE_MAPS_API_KEY_DIHAPUS_DARI_RIWAYAT',
  );

  /// Laravel Reverb WebSocket - same host, different port.
  static String get wsHost {
    final uri = Uri.parse(apiBaseUrl);
    return uri.host;
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

  static const String pusherAppKey = String.fromEnvironment(
    'PUSHER_APP_KEY',
    defaultValue: 'REVERB_APP_KEY_DIHAPUS_DARI_RIWAYAT',
  );

  static const String pusherCluster = 'mt1';
}
