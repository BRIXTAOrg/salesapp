abstract final class ApiConfig {
  // The compiled default -- used until Remote Config is fetched (or if
  // the fetch fails: no network on first launch, Firebase outage, etc).
  // This is NOT overwritten; _baseUrl starts equal to it and only moves
  // away from it once RemoteConfigService.initialize() actually succeeds.
  static const _compiledDefault = String.fromEnvironment(
    'SALESAPP_API_BASE_URL',
    defaultValue: 'https://sales-api.brixtahomeserver.site',
  );

  static String _baseUrl = _compiledDefault;

  static String get baseUrl => _baseUrl;

  /// Called once by RemoteConfigService at startup, after a successful
  /// fetchAndActivate(). Never called with an empty/invalid value -- an
  /// empty Remote Config parameter just means "keep the compiled default".
  static void updateBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    _baseUrl = trimmed;
  }
}