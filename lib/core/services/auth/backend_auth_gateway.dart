import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../models/app_user.dart';
import '../../models/auth_session.dart';
import '../../models/mobile_capability.dart';
import 'auth_gateway.dart';
import 'mock_auth_gateway.dart' show AuthException;

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
    final lb = jsonDecode(lr.body) as Map<String, dynamic>;
    if (lr.statusCode != 200 || lb['success'] != true)
      throw AuthException(lb['error'] ?? 'Unable to sign in.');
    final token = lb['token'] as String;
    final br = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/salesApp/bootstrap'),
      headers: {'authorization': 'Bearer $token'},
    );
    final b = jsonDecode(br.body) as Map<String, dynamic>;
    if (br.statusCode != 200 || b['success'] != true)
      throw AuthException(b['error'] ?? 'Unable to load workspace.');
    final u = Map<String, dynamic>.from(b['user']);
    return AuthSession(
      accessToken: token,
      tenant: r.tenant,
      user: AppUser(
        id: u['id'].toString(),
        employeeCode: u['employeeCode'] ?? r.identifier,
        name: u['name'] ?? r.identifier,
        designation: u['designation'] ?? u['role'] ?? 'Employee',
        department: u['department'],
        roles: [if (u['role'] is String) u['role']],
      ),
      permissions: Set<String>.from(
        ((b['permissions'] as List?) ?? []).map((e) => e.toString()),
      ),
      modules: ((b['modules'] as List?) ?? [])
          .map((e) => MobileCapability.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  @override
  Future<void> logout() async {}
}
