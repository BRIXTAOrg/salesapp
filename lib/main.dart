import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:stac/stac.dart';

import 'app/brixta_app.dart';
import 'core/config/remote_config_service.dart';
import 'core/config/tenant_config.dart';
import 'core/database/app_database.dart';
import 'core/device/device_identity.dart';
import 'core/services/auth/backend_auth_gateway.dart';
import 'core/services/connectivity/device_connectivity_gateway.dart';
import 'core/services/sync/local_sync_gateway.dart';
import 'core/services/sync/sync_transport.dart';
import 'core/session/app_session_controller.dart';
import 'firebase_options.dart';
import 'features/dynamic/presentation/brixta_stac_ui.dart';
import 'features/dynamic/presentation/builder_preview_app.dart';
import 'features/external/presentation/brixta_external_runtime_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /*
   * BRIXTA_STAC_LOCAL_RUNTIME_V1
   *
   * Local JSON renderer only.
   * No Stac Cloud account/API is required.
   */
  await Stac.initialize(parsers: const [BrixtaScreenParser()]);

  // BRIXTA_UNIVERSAL_INTEGRATION_V1
  // CMS live preview runs the actual Flutter/Stac renderer without auth, DB,
  // Firebase or employee runtime side effects.
  if (Uri.base.queryParameters['brixtaPreview'] == '1') {
    runApp(const BrixtaBuilderPreviewApp());
    return;
  }

  /*
   * BRIXTA_EXTERNAL_WEB_RUNTIME_V1
   *
   * /r/{tenant}/{token}
   * /x/{tenant}/{responsibility}
   *
   * This runs BEFORE Firebase, local DB, device identity and employee
   * session initialization.
   */
  if (BrixtaExternalRuntimeRoute.matches(Uri.base)) {
    runApp(const BrixtaExternalRuntimeApp());
    return;
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await RemoteConfigService.initialize();
  await AppDatabase.instance.initialize();
  await AppDeviceIdentity.instance.initialize();

  final connectivity = await DeviceConnectivityGateway.create();
  final authGateway = BackendAuthGateway(database: AppDatabase.instance);
  final cachedSession = await authGateway.restoreCachedSession(
    TenantConfig.demo,
  );

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

  await controller.initializeRuntime();

  runApp(BrixtaApp(controller: controller));
}
