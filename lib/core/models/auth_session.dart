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
    this.workspaceRevision = '',
    this.syncConfig = const {},
    this.deviceRuntime = const {},
    this.workflow = const {},
    this.readyActions = const [],
    this.blockedActions = const [],
    this.pendingApprovals = const [],
    this.generatedAt,
  });

  final String accessToken;
  final TenantConfig tenant;
  final AppUser user;
  final Set<String> permissions;
  final List<MobileCapability> modules;

  /// Hash of currently published Responsibilities + Workflows.
  final String workspaceRevision;
  final Map<String, dynamic> syncConfig;
  final Map<String, dynamic> deviceRuntime;
  final Map<String, dynamic> workflow;
  final List<Map<String, dynamic>> readyActions;
  final List<Map<String, dynamic>> blockedActions;
  final List<Map<String, dynamic>> pendingApprovals;
  final DateTime? generatedAt;

  bool can(String permission) => permissions.contains(permission);
}
