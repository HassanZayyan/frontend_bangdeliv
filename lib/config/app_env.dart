class AppEnv {
  AppEnv._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
<<<<<<< HEAD
    defaultValue: 'http://192.168.1.86:8000/api',
  );

  static const bool enableDriverMockFallback = bool.fromEnvironment(
    'ENABLE_DRIVER_MOCK_FALLBACK',
    defaultValue: false,
=======
    defaultValue: 'http://192.168.1.85:8000/api',
>>>>>>> 0c65d18f24dd71c3e650b06c0e3643ff21df121f
  );
}
