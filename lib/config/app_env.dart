class AppEnv {
  AppEnv._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.86:8000/api',
  );

  static const bool enableDriverMockFallback = bool.fromEnvironment(
    'ENABLE_DRIVER_MOCK_FALLBACK',
    defaultValue: true,
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'GOOGLE_MAPS_API_KEY_DIHAPUS_DARI_RIWAYAT',
  );
}
