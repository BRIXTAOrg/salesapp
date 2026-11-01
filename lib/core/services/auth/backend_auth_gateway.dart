import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../config/tenant_config.dart';
import '../../database/app_database.dart';
import '../../device/device_identity.dart';
import '../../models/app_user.dart';
import '../../models/auth_session.dart';
import '../../models/mobile_capability.dart';
import 'auth_gateway.dart';

final ValueNotifier<List<String>> brixtaAuthDiagnostics =
    ValueNotifier<List<String>>(<String>[]);

void brixtaAuthDiag(String message) {
  final now = DateTime.now();
  final time =
      '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}:'
      '${now.second.toString().padLeft(2, '0')}';

  final next = <String>[...brixtaAuthDiagnostics.value, '[$time] $message'];

  brixtaAuthDiagnostics.value = next.length > 20
      ? next.sublist(next.length - 20)
      : next;

  debugPrint('BRIXTA AUTH: $message');
}

class BackendAuthGateway implements AuthGateway {
  BackendAuthGateway({http.Client? client, AppDatabase? database})
    : _client = client ?? http.Client(),
      _database = database ?? AppDatabase.instance;

  static const _cacheKey = 'last_auth_session';

  final http.Client _client;
  final AppDatabase _database;

  Map<String, String> get _runtimeHeaders =>
      AppDeviceIdentity.instance.requestHeaders;

  @override
  Future<AuthSession> login(LoginRequest request) async {
    brixtaAuthDiagnostics.value = <String>[];

    final loginUrl = '${ApiConfig.baseUrl}/api/salesApp/auth/login';

    brixtaAuthDiag('LOGIN PRESSED');
    brixtaAuthDiag('API: ${ApiConfig.baseUrl}');
    brixtaAuthDiag('Company: ${request.tenant.code}');
    brixtaAuthDiag('Employee: ${request.identifier.trim()}');

    try {
      brixtaAuthDiag('Initializing device identity...');
      await AppDeviceIdentity.instance.initialize();
      brixtaAuthDiag('Device identity ready');

      brixtaAuthDiag('POST /api/salesApp/auth/login');

      final loginResponse = await _client.post(
        Uri.parse(loginUrl),
        headers: {'content-type': 'application/json', ..._runtimeHeaders},
        body: jsonEncode({
          'companyCode': request.tenant.code,
          'salesmanLoginId': request.identifier.trim(),
          'password': request.password,
        }),
      );

      brixtaAuthDiag('Login HTTP ${loginResponse.statusCode}');

      final loginBody = _decodeMap(loginResponse.body);

      if (loginResponse.statusCode != 200 || loginBody['success'] != true) {
        final message = (loginBody['error'] ?? 'Unable to sign in.').toString();
        brixtaAuthDiag('LOGIN REJECTED: $message');
        throw AuthException(message);
      }

      final token = loginBody['token']?.toString();
      if (token == null || token.isEmpty) {
        brixtaAuthDiag('ERROR: login returned no token');
        throw const AuthException(
          'Login succeeded but no access token was returned.',
        );
      }

      brixtaAuthDiag('Token received');
      brixtaAuthDiag('GET /api/salesApp/bootstrap');

      final bootstrap = await _fetchBootstrap(token);

      brixtaAuthDiag('Bootstrap received');
      brixtaAuthDiag('Building workspace session...');

      // The sign-in code may change. Store the immutable tenant schema in
      // session/offline cache keys, not the editable company login code.
      final stableSchema = loginBody['tenantSchema']?.toString().trim() ?? '';
      final stableTenant = stableSchema.isNotEmpty
          ? request.tenant.copyWith(code: stableSchema)
          : request.tenant;
      final session = _buildSession(
        tenant: stableTenant,
        token: token,
        identifier: request.identifier,
        bootstrap: bootstrap,
      );

      brixtaAuthDiag('Session built');
      brixtaAuthDiag('Caching session...');

      await _cacheSession(
        token: token,
        identifier: request.identifier.trim(),
        tenantCode: stableTenant.code,
        bootstrap: bootstrap,
      );

      brixtaAuthDiag('LOGIN COMPLETE');
      return session;
    } on AuthException catch (error) {
      brixtaAuthDiag('AUTH ERROR: ${error.message}');
      rethrow;
    } catch (error) {
      brixtaAuthDiag('NETWORK/RUNTIME ERROR: ${error.runtimeType}: $error');
      throw AuthException('DIAGNOSTIC: ${error.runtimeType}: $error');
    }
  }

  @override
  Future<AuthSession> refresh(AuthSession current) async {
    final bootstrap = await _fetchBootstrap(current.accessToken);

    final session = _buildSession(
      tenant: current.tenant,
      token: current.accessToken,
      identifier: current.user.employeeCode,
      bootstrap: bootstrap,
    );

    await _cacheSession(
      token: current.accessToken,
      identifier: current.user.employeeCode,
      tenantCode: current.tenant.code,
      bootstrap: bootstrap,
    );

    return session;
  }

  Future<AuthSession?> restoreCachedSession(TenantConfig tenant) async {
    final cached = await _database.getCache(_cacheKey);
    if (cached is! Map) return null;

    final map = Map<String, dynamic>.from(cached);
    final token = map['token']?.toString();
    final identifier = map['identifier']?.toString();
    final tenantCode = map['tenantCode']?.toString();
    final rawBootstrap = map['bootstrap'];

    if (token == null ||
        token.isEmpty ||
        identifier == null ||
        rawBootstrap is! Map) {
      return null;
    }

    try {
      return _buildSession(
        tenant: tenant.copyWith(
          code: tenantCode == null || tenantCode.isEmpty
              ? tenant.code
              : tenantCode,
        ),
        token: token,
        identifier: identifier,
        bootstrap: Map<String, dynamic>.from(rawBootstrap),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _fetchBootstrap(String token) async {
    await AppDeviceIdentity.instance.initialize();

    late final http.Response response;

    try {
      response = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}/api/salesApp/bootstrap'),
        headers: {'authorization': 'Bearer $token', ..._runtimeHeaders},
      );
    } catch (error) {
      brixtaAuthDiag('BOOTSTRAP NETWORK ERROR: ${error.runtimeType}: $error');
      rethrow;
    }

    brixtaAuthDiag('Bootstrap HTTP ${response.statusCode}');

    final body = _decodeMap(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw AuthException(
        (body['error'] ?? 'Unable to refresh workspace.').toString(),
      );
    }

    return body;
  }

  Future<void> _cacheSession({
    required String token,
    required String identifier,
    required String tenantCode,
    required Map<String, dynamic> bootstrap,
  }) {
    return _database.putCache(_cacheKey, {
      'token': token,
      'identifier': identifier,
      'tenantCode': tenantCode,
      'bootstrap': bootstrap,
    });
  }

  AuthSession _buildSession({
    required TenantConfig tenant,
    required String token,
    required String identifier,
    required Map<String, dynamic> bootstrap,
  }) {
    final rawUser = bootstrap['user'];
    if (rawUser is! Map) {
      throw const AuthException(
        'Workspace did not contain an employee profile.',
      );
    }

    final user = Map<String, dynamic>.from(rawUser);
    final responsibilitiesRaw =
        bootstrap['responsibilities'] ?? bootstrap['modules'];
    final permissionsRaw = bootstrap['permissions'];

    final permissions = <String>{
      if (permissionsRaw is List)
        ...permissionsRaw.map((item) => item.toString()),
    };

    final readyActions = _mapList(bootstrap['readyActions']);
    for (final item in readyActions) {
      final key = item['actionKey']?.toString();
      if (key != null && key.isNotEmpty) permissions.add(key);
    }

    final sync = _map(bootstrap['sync']);
    final device = _map(bootstrap['device']);
    final workflow = _map(bootstrap['workflow']);

    return AuthSession(
      accessToken: token,
      tenant: tenant,
      user: AppUser(
        id: user['id'].toString(),
        employeeCode:
            (user['employeeCode'] ?? user['salesmanLoginId'] ?? identifier)
                .toString(),
        name: (user['name'] ?? user['displayName'] ?? identifier).toString(),
        designation: (user['designation'] ?? user['role'] ?? 'Employee')
            .toString(),
        department: user['department']?.toString(),
        roles: [if (user['role'] is String) user['role'] as String],
      ),
      permissions: permissions,
      modules: [
        if (responsibilitiesRaw is List)
          ...responsibilitiesRaw.whereType<Map>().map(
            (item) =>
                MobileCapability.fromJson(Map<String, dynamic>.from(item)),
          ),
      ],
      workspaceRevision: sync['workspaceRevision']?.toString() ?? '',
      syncConfig: sync,
      deviceRuntime: device,
      workflow: workflow,
      readyActions: readyActions,
      blockedActions: _mapList(bootstrap['blockedActions']),
      pendingApprovals: _mapList(bootstrap['pendingApprovals']),
      generatedAt: DateTime.tryParse(
        bootstrap['generatedAt']?.toString() ?? '',
      ),
    );
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static List<Map<String, dynamic>> _mapList(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Future<void> logout() async {
    await _database.removeCache(_cacheKey);
  }
}
