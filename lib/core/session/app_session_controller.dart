import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/tenant_config.dart';
import '../models/auth_session.dart';
import '../services/auth/auth_gateway.dart';
import '../services/connectivity/connectivity_gateway.dart';
import '../services/sync/sync_gateway.dart';

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    required this.tenant,
    required this.authGateway,
    required this.connectivityGateway,
    required this.syncGateway,
  })  : connectivity = connectivityGateway.current,
        syncSnapshot = syncGateway.current {
    _connectivitySub = connectivityGateway.changes.listen((value) {
      connectivity = value;
      notifyListeners();
    });

    _syncSub = syncGateway.changes.listen((value) {
      syncSnapshot = value;
      notifyListeners();
    });
  }

  final TenantConfig tenant;
  final AuthGateway authGateway;
  final ConnectivityGateway connectivityGateway;
  final SyncGateway syncGateway;

  AuthSession? session;
  ConnectivityStateValue connectivity;
  SyncSnapshot syncSnapshot;

  StreamSubscription<ConnectivityStateValue>? _connectivitySub;
  StreamSubscription<SyncSnapshot>? _syncSub;

  bool get isOnline => connectivity == ConnectivityStateValue.online;

  Future<void> login({
    required String portalKey,
    required String roleCode,
    required String identifier,
    required String password,
  }) async {
    session = await authGateway.login(
      LoginRequest(
        tenant: tenant,
        portalKey: portalKey,
        roleCode: roleCode,
        identifier: identifier,
        password: password,
      ),
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await authGateway.logout();
    session = null;
    notifyListeners();
  }

  Future<void> syncNow() => syncGateway.syncNow();

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }
}
