import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/app_user.dart';
import '../../models/auth_session.dart';
import '../../models/mobile_capability.dart';
import 'auth_gateway.dart';

class BackendAuthGateway implements AuthGateway {
  BackendAuthGateway({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AuthSession> login(LoginRequest r) async {
    final lr = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/salesApp/auth/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'salesmanLoginId': r.identifier.trim(),
        'password': r.password,
      }),
    );

    final lb = _decodeMap(lr.body);
    if (lr.statusCode != 200 || lb['success'] != true) {
      throw AuthException(
        (lb['error'] ?? 'Unable to sign in.').toString(),
      );
    }

    final token = lb['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const AuthException('Login succeeded but no access token was returned.');
    }

    final br = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salesApp/bootstrap'),
      headers: {'authorization': 'Bearer $token'},
    );

    final b = _decodeMap(br.body);
    if (br.statusCode != 200 || b['success'] != true) {
      throw AuthException(
        (b['error'] ?? 'Unable to load workspace.').toString(),
      );
    }

    final rawUser = b['user'];
    if (rawUser is! Map) {
      throw const AuthException('Workspace did not contain an employee profile.');
    }

    final u = Map<String, dynamic>.from(rawUser);
    final modulesRaw = b['modules'];
    final permissionsRaw = b['permissions'];

    return AuthSession(
      accessToken: token,
      tenant: r.tenant,
      user: AppUser(
        id: u['id'].toString(),
        employeeCode: (u['employeeCode'] ?? u['salesmanLoginId'] ?? r.identifier).toString(),
        name: (u['name'] ?? u['displayName'] ?? r.identifier).toString(),
        designation: (u['designation'] ?? u['role'] ?? 'Employee').toString(),
        department: u['department']?.toString(),
        roles: [
          if (u['role'] is String) u['role'] as String,
        ],
      ),
      permissions: {
        if (permissionsRaw is List)
          ...permissionsRaw.map((e) => e.toString()),
      },
      modules: [
        if (modulesRaw is List)
          ...modulesRaw
              .whereType<Map>()
              .map((e) => MobileCapability.fromJson(Map<String, dynamic>.from(e))),
      ],
    );
  }

  Map<String, dynamic> _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  @override
  Future<void> logout() async {}
}
