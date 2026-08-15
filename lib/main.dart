import 'package:flutter/material.dart';

import 'app/brixta_app.dart';
import 'core/config/tenant_config.dart';
import 'core/services/auth/mock_auth_gateway.dart';
import 'core/services/connectivity/mock_connectivity_gateway.dart';
import 'core/services/sync/mock_sync_gateway.dart';
import 'core/session/app_session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = AppSessionController(
    tenant: TenantConfig.demo,
    authGateway: MockAuthGateway(),
    connectivityGateway: MockConnectivityGateway(),
    syncGateway: MockSyncGateway(),
  );

  runApp(BrixtaApp(controller: controller));
}
