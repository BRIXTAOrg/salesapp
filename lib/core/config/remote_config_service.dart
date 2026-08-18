import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../config/api_config.dart';

/// Fetches the production API base URL from Firebase Remote Config at app
/// startup, so it can be changed (e.g. server migration, incident
/// failover) without shipping a new app build.
///
/// Must run AFTER Firebase.initializeApp() and BEFORE any HTTP call reads
/// ApiConfig.baseUrl -- see main.dart for the ordering. Failure here
/// (no network, Firebase outage, first-ever launch before any fetch has
/// ever succeeded) is non-fatal: ApiConfig simply keeps its compiled
/// default, matching the previous hardcoded-baseUrl behavior exactly.
abstract final class RemoteConfigService {
  static const _baseUrlKey = 'SALESAPP_API_BASE_URL';

  static Future<void> initialize() async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          // Remote Config itself caches fetched values on-device and
          // serves them instantly on the NEXT launch even before this
          // fetch call resolves again -- this interval just controls how
          // often a fresh network fetch is attempted, not whether a
          // previously-fetched value is available immediately at startup.
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      await remoteConfig.setDefaults({
        _baseUrlKey: ApiConfig.baseUrl,
      });

      await remoteConfig.fetchAndActivate();
    } catch (_) {
      // No network, Firebase misconfigured, fetch timeout, etc. --
      // ApiConfig already has its compiled default; nothing more to do.
      return;
    }

    final fetchedUrl = remoteConfig.getString(_baseUrlKey);
    ApiConfig.updateBaseUrl(fetchedUrl);
  }
}