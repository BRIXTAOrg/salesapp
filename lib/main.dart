import 'package:flutter/material.dart';

import 'app/brixta_app.dart';
import 'core/config/tenant_config.dart';
import 'core/database/app_database.dart';
import 'core/services/auth/backend_auth_gateway.dart';
import 'core/services/connectivity/device_connectivity_gateway.dart';
import 'core/services/sync/local_sync_gateway.dart';
import 'core/services/sync/sync_transport.dart';
import 'core/session/app_session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppDatabase.instance.initialize();

  final connectivity = await DeviceConnectivityGateway.create();
  final authGateway = BackendAuthGateway(database: AppDatabase.instance);
  final cachedSession = await authGateway.restoreCachedSession(TenantConfig.demo);

  late final AppSessionController controller;

  final syncGateway = LocalSyncGateway(
    database: AppDatabase.instance,
    connectivityGateway: connectivity,
    transport: const UnconfiguredSyncTransport(),
    employeeIdProvider: () => controller.session?.user.id,
  );

  await syncGateway.initialize();

  controller = AppSessionController(
    tenant: TenantConfig.demo,
    authGateway: authGateway,
    connectivityGateway: connectivity,
    syncGateway: syncGateway,
    session: cachedSession,
  );

  runApp(BrixtaApp(controller: controller));
}
