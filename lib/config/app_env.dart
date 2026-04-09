class AppEnv {
  AppEnv._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://172.22.160.1:8000/api',
  );
}
