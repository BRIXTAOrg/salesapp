import 'dart:io';

import '../database/app_database.dart';

/// Stable, privacy-minimal device identity for company-device visibility.
///
/// We deliberately do not depend on platform-specific device-info packages.
/// A random install ID is generated once and kept in the app database. The
/// backend can therefore distinguish company devices without collecting a
/// hardware serial/IMEI.
class AppDeviceIdentity {
  AppDeviceIdentity._();

  static final AppDeviceIdentity instance = AppDeviceIdentity._();

  static const _cacheKey = 'brixta_device_identity_v1';
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.1.0+2',
  );

  String? _deviceId;
  DateTime? _createdAt;

  String get deviceId => _deviceId ?? '';
  String get platform => Platform.operatingSystem;
  String get osVersion => Platform.operatingSystemVersion;
  bool get ready => deviceId.isNotEmpty;

  Future<void> initialize() async {
    if (ready) return;

    final cached = await AppDatabase.instance.getCache(_cacheKey);
    if (cached is Map) {
      final map = Map<String, dynamic>.from(cached);
      final value = map['deviceId']?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        _deviceId = value;
        _createdAt = DateTime.tryParse(map['createdAt']?.toString() ?? '');
        return;
      }
    }

    _deviceId = AppDatabase.instance.newId();
    _createdAt = DateTime.now().toUtc();

    await AppDatabase.instance.putCache(_cacheKey, {
      'deviceId': _deviceId,
      'createdAt': _createdAt!.toIso8601String(),
    });
  }

  Map<String, String> get requestHeaders => {
        if (ready) 'x-brixta-device-id': deviceId,
        'x-brixta-platform': platform,
        'x-brixta-app-version': appVersion,
      };

  Map<String, dynamic> get runtimeMetadata => {
        'os': platform,
        'osVersion': osVersion,
        'locale': Platform.localeName,
        'processors': Platform.numberOfProcessors,
        'installCreatedAt': _createdAt?.toIso8601String(),
      };

  Map<String, dynamic> get registrationPayload => {
        'deviceId': deviceId,
        'platform': platform,
        'appVersion': appVersion,
        'metadata': runtimeMetadata,
      };
}
