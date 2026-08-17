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
    this.session,
  })  : connectivity = connectivityGateway.current,
        syncSnapshot = syncGateway.current {
    _connectivitySub = connectivityGateway.changes.listen((value) {
      connectivity = value;
      notifyListeners();

      if (value == ConnectivityStateValue.online && session != null) {
        unawaited(refreshWorkspace());
        unawaited(syncGateway.syncNow());
      }
    });

    _syncSub = syncGateway.changes.listen((value) {
      syncSnapshot = value;
      notifyListeners();
    });

    if (session != null) {
      _startWorkspaceTimer();
    }
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
  Timer? _workspaceTimer;
  bool _refreshingWorkspace = false;

  bool get isOnline => connectivity == ConnectivityStateValue.online;
  bool get isOffline => !isOnline;
  bool get refreshingWorkspace => _refreshingWorkspace;

  Future<void> login({
    required String identifier,
    required String password,
    String? companyCode,
  }) async {
    final effectiveTenant = (companyCode != null && companyCode.trim().isNotEmpty)
        ? tenant.copyWith(code: companyCode.trim())
        : tenant;

    session = await authGateway.login(
      LoginRequest(
        tenant: effectiveTenant,
        portalKey: 'employee',
        roleCode: 'EMPLOYEE',
        identifier: identifier,
        password: password,
      ),
    );

    _startWorkspaceTimer();
    notifyListeners();

    if (isOnline) {
      unawaited(syncGateway.syncNow());
    }
  }

  Future<bool> refreshWorkspace() async {
    final current = session;
    if (current == null || isOffline || _refreshingWorkspace) return false;

    _refreshingWorkspace = true;
    notifyListeners();

    try {
      session = await authGateway.refresh(current);
      notifyListeners();
      return true;
    } catch (_) {
      // Cached workspace remains usable if refresh fails.
      return false;
    } finally {
      _refreshingWorkspace = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _workspaceTimer?.cancel();
    await authGateway.logout();
    session = null;
    notifyListeners();
  }

  Future<void> syncNow() async {
    await refreshWorkspace();
    await syncGateway.syncNow();
  }

  void _startWorkspaceTimer() {
    _workspaceTimer?.cancel();
    _workspaceTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(refreshWorkspace()),
    );
  }

  @override
  void dispose() {
    _workspaceTimer?.cancel();
    _connectivitySub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }
}