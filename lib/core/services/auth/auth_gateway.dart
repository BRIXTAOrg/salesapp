import '../../config/tenant_config.dart';
import '../../models/auth_session.dart';

class LoginRequest {
  const LoginRequest({
    required this.tenant,
    required this.portalKey,
    required this.roleCode,
    required this.identifier,
    required this.password,
  });

  final TenantConfig tenant;
  final String portalKey;
  final String roleCode;
  final String identifier;
  final String password;
}

abstract interface class AuthGateway {
  Future<AuthSession> login(LoginRequest request);
  Future<void> logout();
}
