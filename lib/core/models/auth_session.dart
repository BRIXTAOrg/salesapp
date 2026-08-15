import '../config/tenant_config.dart';
import 'app_user.dart';
import 'mobile_capability.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tenant,
    required this.user,
    required this.permissions,
    this.modules = const [],
  });
  final String accessToken;
  final TenantConfig tenant;
  final AppUser user;
  final Set<String> permissions;
  final List<MobileCapability> modules;
  bool can(String p) => permissions.contains(p);
}
