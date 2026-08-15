abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'KAMDHENU_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
