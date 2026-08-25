import '../../config/field_api.dart';
import '../../database/app_database.dart';
import '../../device/device_identity.dart';

class ResponsibilityRuntimeApi {
  const ResponsibilityRuntimeApi({required this.accessToken});

  final String accessToken;

  FieldApi get _api => FieldApi(accessToken: accessToken);

  Future<Map<String, dynamic>> runtime(
    String responsibilityKey, {
    String? recordId,
  }) {
    final query = recordId == null || recordId.isEmpty
        ? ''
        : '?recordId=${Uri.encodeQueryComponent(recordId)}';
    return _api.getJson(
      '/api/salesApp/responsibilities/${Uri.encodeComponent(responsibilityKey)}/runtime$query',
    );
  }

  Future<Map<String, dynamic>> runAction({
    required String responsibilityKey,
    required String actionId,
    required Map<String, dynamic> payload,
    String? recordId,
    String? workflowInstanceId,
    String? clientMutationId,
  }) {
    return _api.postJson(
      '/api/salesApp/responsibilities/${Uri.encodeComponent(responsibilityKey)}/actions/${Uri.encodeComponent(actionId)}',
      {
        'recordId': recordId,
        'payload': payload,
        'workflowInstanceId': workflowInstanceId,
        'clientMutationId': clientMutationId ?? AppDatabase.instance.newId(),
        'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
        ...AppDeviceIdentity.instance.registrationPayload,
      },
    );
  }

  Future<Map<String, dynamic>> dataSource(
    String sourceKey, {
    String query = '',
    int limit = 50,
  }) {
    return _api.getJson(
      '/api/salesApp/data-sources/${Uri.encodeComponent(sourceKey)}'
      '?q=${Uri.encodeQueryComponent(query)}&limit=$limit',
    );
  }

  Future<String?> latestRecordId(String responsibilityKey) async {
    try {
      final body = await _api.getJson(
        '/api/salesApp/records/${Uri.encodeComponent(responsibilityKey)}?limit=1',
      );
      final raw = body['records'];
      if (raw is List && raw.isNotEmpty && raw.first is Map) {
        return (raw.first as Map)['id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> myWork() =>
      _api.getJson('/api/salesApp/my-work');

  Future<Map<String, dynamic>> profileRuntime() =>
      _api.getJson('/api/salesApp/profile/runtime');

  Future<void> usage(
    String actionKey, {
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await _api.postJson('/api/salesApp/usage', {
        'actionKey': actionKey,
        'entityType': entityType,
        'entityId': entityId,
        'metadata': metadata,
      });
    } catch (_) {}
  }
}
