import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../config/tenant_config.dart';
import '../../database/app_database.dart';
import '../../models/app_user.dart';
import '../../models/auth_session.dart';
import '../../models/mobile_capability.dart';
import 'auth_gateway.dart';

class BackendAuthGateway implements AuthGateway {
  BackendAuthGateway({
    http.Client? client,
    AppDatabase? database,
  })  : _client = client ?? http.Client(),
        _database = database ?? AppDatabase.instance;

  static const _cacheKey = 'last_auth_session';

  final http.Client _client;
  final AppDatabase _database;

  @override
  Future<AuthSession> login(LoginRequest request) async {
    final loginResponse = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/salesApp/auth/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'companyCode': request.tenant.code,
        'salesmanLoginId': request.identifier.trim(),
        'password': request.password,
      }),
    );

    final loginBody = _decodeMap(loginResponse.body);
    if (loginResponse.statusCode != 200 || loginBody['success'] != true) {
      throw AuthException(
        (loginBody['error'] ?? 'Unable to sign in.').toString(),
      );
    }

    final token = loginBody['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const AuthException(
        'Login succeeded but no access token was returned.',
      );
    }

    final bootstrap = await _fetchBootstrap(token);
    final session = _buildSession(
      tenant: request.tenant,
      token: token,
      identifier: request.identifier,
      bootstrap: bootstrap,
    );

    await _cacheSession(
      token: token,
      identifier: request.identifier.trim(),
      bootstrap: bootstrap,
    );

    return session;
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
    final rawBootstrap = map['bootstrap'];

    if (token == null ||
        token.isEmpty ||
        identifier == null ||
        rawBootstrap is! Map) {
      return null;
    }

    try {
      return _buildSession(
        tenant: tenant,
        token: token,
        identifier: identifier,
        bootstrap: Map<String, dynamic>.from(rawBootstrap),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _fetchBootstrap(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salesApp/bootstrap'),
      headers: {'authorization': 'Bearer $token'},
    );

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
    required Map<String, dynamic> bootstrap,
  }) {
    return _database.putCache(_cacheKey, {
      'token': token,
      'identifier': identifier,
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

    // Platform Core renamed business modules to Responsibilities. Keep the
    // modules fallback so already-cached sessions from an older server can
    // still restore during rollout.
    final responsibilitiesRaw =
        bootstrap['responsibilities'] ?? bootstrap['modules'];
    final permissionsRaw = bootstrap['permissions'];

    final permissions = <String>{
      if (permissionsRaw is List)
        ...permissionsRaw.map((item) => item.toString()),
    };

    // The workflow bootstrap already exposes ready action keys. Treat them as
    // runtime permissions for presentation purposes; the backend remains the
    // authoritative enforcement point.
    final readyActions = bootstrap['readyActions'];
    if (readyActions is List) {
      for (final item in readyActions) {
        if (item is String) {
          permissions.add(item);
        } else if (item is Map && item['actionKey'] != null) {
          permissions.add(item['actionKey'].toString());
        }
      }
    }

    return AuthSession(
      accessToken: token,
      tenant: tenant,
      user: AppUser(
        id: user['id'].toString(),
        employeeCode:
            (user['employeeCode'] ?? user['salesmanLoginId'] ?? identifier)
                .toString(),
        name: (user['name'] ?? user['displayName'] ?? identifier).toString(),
        designation:
            (user['designation'] ?? user['role'] ?? 'Employee').toString(),
        department: user['department']?.toString(),
        roles: [
          if (user['role'] is String) user['role'] as String,
        ],
      ),
      permissions: permissions,
      modules: [
        if (responsibilitiesRaw is List)
          ...responsibilitiesRaw.whereType<Map>().map(
                (item) => MobileCapability.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
      ],
    );
  }

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
