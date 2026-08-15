import '../config/tenant_config.dart';
import 'app_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tenant,
    required this.user,
    required this.permissions,
  });

  final String accessToken;
  final TenantConfig tenant;
  final AppUser user;
  final Set<String> permissions;

  bool can(String permission) => permissions.contains(permission);
}
