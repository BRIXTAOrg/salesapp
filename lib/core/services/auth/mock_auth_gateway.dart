import '../../models/app_user.dart';
import '../../models/auth_session.dart';
import 'auth_gateway.dart';

class MockAuthGateway implements AuthGateway {
  @override
  Future<AuthSession> login(LoginRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (request.identifier.trim().isEmpty || request.password.trim().isEmpty) {
      throw const AuthException('Employee ID and password are required.');
    }

    return AuthSession(
      accessToken: 'mock-access-token',
      tenant: request.tenant,
      user: AppUser(
        id: 'user-demo-001',
        employeeCode: request.identifier.trim().toUpperCase(),
        name: 'Sunil Kumar',
        designation: 'Field Sales Executive',
        roles: const ['EMPLOYEE'],
      ),
      permissions: const {},
    );
  }

  @override
  Future<AuthSession> refresh(AuthSession current) async => current;

  @override
  Future<void> logout() async {}
}
