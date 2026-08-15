import '../../models/app_user.dart';
import '../../models/auth_session.dart';
import 'auth_gateway.dart';

class MockAuthGateway implements AuthGateway {
  @override
  Future<AuthSession> login(LoginRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (request.identifier.trim().isEmpty || request.password.trim().isEmpty) {
      throw const AuthException('Employee ID and password are required.');
    }

    if (request.roleCode != 'EMPLOYEE') {
      throw const AuthException(
        'This v0.1 build currently enables the Employee portal only.',
      );
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
      permissions: const {
        'attendance.self.read',
        'attendance.self.write',
        'daily_status.self.write',
        'enquiry.self.create',
        'appointments.self.read',
        'targets.self.read',
        'history.self.read',
        'claim.self.create',
        'claim.self.read',
        'notices.self.read',
        'route.self.read',
        'leave.self.create',
        'resignation.self.create',
        'chat.self.use',
        'help.self.read',
      },
    );
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
