import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/field_api.dart';
import '../config/tenant_config.dart';
import '../device/device_identity.dart';
import '../models/auth_session.dart';
import '../offline/offline_attendance_queue.dart';
import '../offline/offline_record_queue.dart';
import '../offline/offline_submission_queue.dart';
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
  }) : connectivity = connectivityGateway.current,
       syncSnapshot = syncGateway.current {
    _connectivitySub = connectivityGateway.changes.listen((value) {
      final wasOffline = isOffline;
      connectivity = value;
      notifyListeners();

      if (value == ConnectivityStateValue.online && session != null) {
        unawaited(_recoverOnline(wasOffline: wasOffline));
      }
    });

    _syncSub = syncGateway.changes.listen((value) {
      syncSnapshot = value;
      notifyListeners();
    });

    if (session != null) {
      _bindOfflineScope();
      _workspaceRevision = session!.workspaceRevision;
      _lastWorkspaceRefreshAt = session!.generatedAt;
      _startRuntimeTimers();
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
  Timer? _heartbeatTimer;

  bool _refreshingWorkspace = false;
  bool _checkingRevision = false;
  bool _syncingRuntime = false;
  int _recordQueuePending = 0;
  int _compatQueuePending = 0;
  String _workspaceRevision = '';
  DateTime? _lastSyncAt;
  DateTime? _lastWorkspaceRefreshAt;
  String? _runtimeError;

  bool get isOnline => connectivity == ConnectivityStateValue.online;
  bool get isOffline => !isOnline;
  bool get refreshingWorkspace => _refreshingWorkspace;
  bool get checkingRevision => _checkingRevision;
  bool get isActivelySyncing =>
      syncSnapshot.isSyncing || _syncingRuntime || _refreshingWorkspace;
  int get pendingChanges =>
      syncSnapshot.pendingCount + _recordQueuePending + _compatQueuePending;
  String get workspaceRevision => _workspaceRevision;
  DateTime? get lastSyncAt => _lastSyncAt;
  DateTime? get lastWorkspaceRefreshAt => _lastWorkspaceRefreshAt;
  String? get runtimeError => _runtimeError;

  String get lastSyncLabel {
    if (isOffline) return 'Offline';
    final value = _lastSyncAt ?? _lastWorkspaceRefreshAt;
    if (value == null) return 'Connected to company';

    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inSeconds < 15) return 'Company is up to date';
    if (difference.inMinutes < 1) return 'Synced less than a minute ago';
    if (difference.inMinutes < 60) {
      return 'Synced ${difference.inMinutes} min ago';
    }
    return 'Synced ${difference.inHours} hr ago';
  }

  Future<void> initializeRuntime() async {
    await AppDeviceIdentity.instance.initialize();
    _bindOfflineScope();
    await OfflineRecordQueue.migrateLegacyQueue();
    await _refreshPendingCount();

    if (session != null) {
      _workspaceRevision = session!.workspaceRevision;
      if (isOnline) {
        await _registerDevice();
        await checkWorkspaceRevision(forceRefreshIfUnknown: true);
        await _flushRuntimeQueue();
      }
      _startRuntimeTimers();
    }

    notifyListeners();
  }

  Future<void> login({
    required String identifier,
    required String password,
    String? companyCode,
  }) async {
    final effectiveTenant =
        (companyCode != null && companyCode.trim().isNotEmpty)
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

    _workspaceRevision = session!.workspaceRevision;
    _lastWorkspaceRefreshAt = session!.generatedAt ?? DateTime.now();
    _runtimeError = null;
    _bindOfflineScope();
    await OfflineRecordQueue.migrateLegacyQueue();
    await _refreshPendingCount();
    _startRuntimeTimers();
    notifyListeners();

    if (isOnline) {
      await _registerDevice();
      unawaited(syncNow());
    }
  }

  Future<bool> refreshWorkspace() async {
    final current = session;
    if (current == null || isOffline || _refreshingWorkspace) return false;

    _refreshingWorkspace = true;
    _runtimeError = null;
    notifyListeners();

    try {
      session = await authGateway.refresh(current);
      _workspaceRevision = session!.workspaceRevision;
      _lastWorkspaceRefreshAt = DateTime.now();
      _bindOfflineScope();
      notifyListeners();
      return true;
    } catch (error) {
      _runtimeError = error.toString();
      return false;
    } finally {
      _refreshingWorkspace = false;
      notifyListeners();
    }
  }

  /// Cheap 15-second poll. A full bootstrap happens only when the CMS has
  /// published a different Responsibility/Workflow revision.
  Future<bool> checkWorkspaceRevision({
    bool forceRefreshIfUnknown = false,
  }) async {
    final current = session;
    if (current == null || isOffline || _checkingRevision) return false;

    _checkingRevision = true;
    try {
      final encoded = Uri.encodeQueryComponent(_workspaceRevision);
      final body = await FieldApi(
        accessToken: current.accessToken,
      ).getJson('/api/salesApp/sync/state?since=$encoded');

      final revision = body['revision']?.toString() ?? '';
      final changed =
          body['changed'] == true ||
          (_workspaceRevision.isNotEmpty &&
              revision.isNotEmpty &&
              revision != _workspaceRevision);

      if (revision.isNotEmpty) _workspaceRevision = revision;

      if (changed ||
          (forceRefreshIfUnknown && current.workspaceRevision.isEmpty)) {
        return await refreshWorkspace();
      }

      _lastSyncAt = DateTime.now();
      _runtimeError = null;
      notifyListeners();
      return false;
    } catch (error) {
      _runtimeError = error.toString();
      return false;
    } finally {
      _checkingRevision = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _workspaceTimer?.cancel();
    _heartbeatTimer?.cancel();
    await authGateway.logout();
    session = null;
    _workspaceRevision = '';
    _recordQueuePending = 0;
    _compatQueuePending = 0;
    _runtimeError = null;
    notifyListeners();
  }

  Future<void> syncNow() async {
    if (session == null || isOffline || _syncingRuntime) return;

    _syncingRuntime = true;
    _runtimeError = null;
    notifyListeners();

    try {
      await _flushRuntimeQueue();
      await syncGateway.syncNow();
      await checkWorkspaceRevision(forceRefreshIfUnknown: true);
      await _heartbeat(synced: true);
      _lastSyncAt = DateTime.now();
    } catch (error) {
      _runtimeError = error.toString();
    } finally {
      _syncingRuntime = false;
      await _refreshPendingCount();
      notifyListeners();
    }
  }

  Future<void> markLocalMutationQueued() async {
    await _refreshPendingCount();
    notifyListeners();
  }

  Future<void> _recoverOnline({required bool wasOffline}) async {
    await _registerDevice();
    await _flushRuntimeQueue();
    await syncGateway.syncNow();
    await checkWorkspaceRevision(forceRefreshIfUnknown: wasOffline);
    await _heartbeat(synced: true);
    _lastSyncAt = DateTime.now();
    await _refreshPendingCount();
    notifyListeners();
  }

  Future<void> _flushRuntimeQueue() async {
    final current = session;
    if (current == null || isOffline) return;

    _recordQueuePending = await OfflineRecordQueue.flush(current.accessToken);

    // Keep the existing specialized queues working during the Kernel rollout.
    // New CMS-built Responsibilities use OfflineRecordQueue; legacy Attendance
    // and Submission screens are still safe and sync automatically too.
    final submissionRemaining = await OfflineSubmissionQueue.flush(
      current.accessToken,
    );
    final attendanceRemaining = await OfflineAttendanceQueue.flush(
      current.accessToken,
    );
    _compatQueuePending = submissionRemaining + attendanceRemaining;
  }

  Future<void> _refreshPendingCount() async {
    _recordQueuePending = await OfflineRecordQueue.pendingCount();
    _compatQueuePending =
        await OfflineSubmissionQueue.pendingCount() +
        await OfflineAttendanceQueue.pendingCount();
  }

  void _bindOfflineScope() {
    final current = session;
    if (current == null) return;
    OfflineRecordQueue.useScope('${current.tenant.code}:${current.user.id}');
  }

  Future<void> _registerDevice() async {
    final current = session;
    if (current == null || isOffline) return;

    final identity = AppDeviceIdentity.instance;
    await identity.initialize();

    try {
      await FieldApi(accessToken: current.accessToken).postJson(
        '/api/salesApp/devices/register',
        identity.registrationPayload,
      );
    } catch (_) {
      // Device registration must never prevent field work.
    }
  }

  Future<void> _heartbeat({bool synced = false}) async {
    final current = session;
    if (current == null || isOffline) return;

    try {
      await FieldApi(accessToken: current.accessToken).postJson(
        '/api/salesApp/devices/heartbeat',
        {...AppDeviceIdentity.instance.registrationPayload, 'synced': synced},
      );
    } catch (_) {}
  }

  void _startRuntimeTimers() {
    _workspaceTimer?.cancel();
    _heartbeatTimer?.cancel();

    _workspaceTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(checkWorkspaceRevision()),
    );

    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_heartbeat()),
    );
  }

  @override
  void dispose() {
    _workspaceTimer?.cancel();
    _heartbeatTimer?.cancel();
    _connectivitySub?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }
}
