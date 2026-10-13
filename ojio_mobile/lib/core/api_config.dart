class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://web-production-e6533.up.railway.app/api/v1',
  );

  static String get origin => Uri.parse(baseUrl).origin;

  static String resolveMediaUrl(String path) =>
      Uri.parse('$origin/').resolve(path).toString();
}
