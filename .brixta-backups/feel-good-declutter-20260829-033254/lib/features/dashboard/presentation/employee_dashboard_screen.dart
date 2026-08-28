import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/models/mobile_capability.dart';
import '../../../core/offline/offline_attendance_queue.dart';
import '../../../core/offline/offline_record_queue.dart';
import '../../../core/offline/offline_submission_queue.dart';
import '../../../core/services/runtime/responsibility_runtime_api.dart';
import '../../../core/session/app_session_controller.dart';
import '../../../core/widgets/runtime_connection_banner.dart';
import '../../dynamic/presentation/dynamic_capability_screen.dart';
import '../../tracking/data/native_tracking_repository.dart';
import '../../tracking/presentation/tracking_controller.dart';
import 'employee_profile_tab.dart';
import 'brixta_premium_nav.dart';
import 'premium_work_tab.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key, required this.controller});

  final AppSessionController controller;

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with WidgetsBindingObserver {
  late final TrackingController tracker;

  List<Map<String, dynamic>> _readyWork = const [];
  List<Map<String, dynamic>> _blockedWork = const [];
  List<Map<String, dynamic>> _approvals = const [];
  Map<String, Object?>? _workSession;
  bool _loadingWork = true;
  int _tab = 0;
  bool _reconciling = false;
  String _lastRevision = '';

  List<MobileCapability> get _modules =>
      widget.controller.session?.modules ?? const [];

  bool get _needsTravelCapability => _modules.any(_capabilityNeedsTracking);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    _lastRevision = widget.controller.workspaceRevision;

    tracker = TrackingController(repository: NativeTrackingRepository());

    unawaited(
      tracker
          .initialize(accessToken: widget.controller.session!.accessToken)
          .then((_) => _refreshAll(refreshWorkspace: true)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    tracker.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAll(refreshWorkspace: true));
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final revision = widget.controller.workspaceRevision;
    if (revision.isNotEmpty && revision != _lastRevision) {
      _lastRevision = revision;
      unawaited(_loadWork());
    }
    setState(() {});
    unawaited(_reconcileTracking());
  }

  Future<void> _refreshAll({bool refreshWorkspace = false}) async {
    if (refreshWorkspace && widget.controller.isOnline) {
      await widget.controller.checkWorkspaceRevision(
        forceRefreshIfUnknown: true,
      );
    }

    await Future.wait([_loadWork(), _loadWorkSession()]);

    await _reconcileTracking();
  }

  Future<void> _loadWorkSession() async {
    final session = widget.controller.session;
    if (session == null) return;

    final value = await AppDatabase.instance.todayWorkSession(session.user.id);
    if (!mounted) return;
    setState(() => _workSession = value);
  }

  Future<void> _reconcileTracking() async {
    if (_reconciling) return;
    final session = widget.controller.session;
    if (session == null) return;

    _reconciling = true;
    try {
      final local = await AppDatabase.instance.todayWorkSession(
        session.user.id,
      );
      if (mounted) setState(() => _workSession = local);

      final shouldRun = local?['status'] == 'active' && _needsTravelCapability;
      if (shouldRun) {
        await tracker.ensureAutomatic(session.user.id);
      } else if (tracker.active) {
        await tracker.stop();
      }
    } finally {
      _reconciling = false;
    }
  }

  Future<void> _loadWork() async {
    final session = widget.controller.session;
    if (session == null) return;
    if (mounted) setState(() => _loadingWork = true);

    try {
      if (widget.controller.isOnline) {
        await OfflineRecordQueue.flush(session.accessToken);
        await OfflineSubmissionQueue.flush(session.accessToken);
        await OfflineAttendanceQueue.flush(session.accessToken);
        await widget.controller.markLocalMutationQueued();

        final response = await ResponsibilityRuntimeApi(
          accessToken: session.accessToken,
        ).myWork();

        final work = _map(response['work']);
        final ready = _mapList(work['ready']);
        final blocked = _mapList(work['blocked']);
        final approvals = _mapList(work['approvals']);

        await AppDatabase.instance.putCache('my_work:${_workScope(session)}', {
          'ready': ready,
          'blocked': blocked,
          'approvals': approvals,
        });

        if (mounted) {
          setState(() {
            _readyWork = ready;
            _blockedWork = blocked;
            // Backend authority resolution is authoritative.
            // Only approvals this user may actually decide are returned.
            _approvals = approvals;
          });
        }
      } else {
        await _loadCachedWork();
      }
    } catch (_) {
      // Compatibility fallback while backend rollout finishes.
      try {
        final response = await FieldApi(
          accessToken: session.accessToken,
        ).getJson('/api/salesApp/work-items');
        final raw = response['workItems'];
        if (raw is List && mounted) {
          setState(() {
            _readyWork = _mapList(raw)
                .where(
                  (item) =>
                      item['status'] != 'completed' &&
                      item['status'] != 'cancelled',
                )
                .toList();
          });
        }
      } catch (_) {
        await _loadCachedWork();
      }
    } finally {
      if (mounted) setState(() => _loadingWork = false);
    }
  }

  Future<void> _loadCachedWork() async {
    final session = widget.controller.session;
    if (session == null) return;
    final cached = await AppDatabase.instance.getCache(
      'my_work:${_workScope(session)}',
    );
    if (cached is Map && mounted) {
      final map = Map<String, dynamic>.from(cached);
      setState(() {
        _readyWork = _mapList(map['ready']);
        _blockedWork = _mapList(map['blocked']);
        _approvals = _mapList(map['approvals']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      _HomeTab(
        controller: widget.controller,
        tracker: tracker,
        workSession: _workSession,
        readyWork: _readyWork,
        approvals: _approvals,
        modules: _modules,
        loadingWork: _loadingWork,
        onRefresh: () => _refreshAll(refreshWorkspace: true),
        onOpenWork: () => setState(() => _tab = 1),
        onCapabilityTap: _openCapability,
      ),
      PremiumWorkTab(
        controller: widget.controller,
        modules: _modules,
        readyWork: _readyWork,
        blockedWork: _blockedWork,
        approvals: _approvals,
        onRefresh: () => _refreshAll(refreshWorkspace: true),
        onCapabilityTap: _openCapability,
        onReadyTap: (item) {
          unawaited(_openReadyWork(item));
        },
        onApprovalTap: _reviewApproval,
      ),
      EmployeeProfileTab(
        controller: widget.controller,
        tracker: tracker,
        workSession: _workSession,
      ),
    ];

    final safeTab = _tab >= 0 && _tab < screens.length ? _tab : 0;

    return Scaffold(
      // BRIXTA_PREMIUM_FLOATING_SHELL_V2
      //
      // The app content deliberately continues beneath the navigation.
      // The navigation is a floating layer, not a hard layout boundary.
      extendBody: true,
      body: screens[safeTab],
      bottomNavigationBar: BrixtaPremiumNav(
        selectedIndex: safeTab,
        onChanged: (index) => setState(() => _tab = index),
      ),
    );
  }

  void _openCapability(
    MobileCapability capability, {
    String? workflowInstanceId,
    String? recordId,
  }) {
    // CMS IS AUTHORITATIVE FOR BUSINESS UI.
    //
    // Attendance / TA-DA / Tracking / Visit / Inspection etc. are not
    // privileged application names here anymore.
    //
    // The CMS compiles the Responsibility definition and this generic
    // renderer executes it.
    final screen = DynamicCapabilityScreen(
      controller: widget.controller,
      capability: capability,
      initialRecordId: recordId,
      workflowInstanceId: workflowInstanceId,
    );

    if (widget.controller.isOnline) {
      unawaited(
        ResponsibilityRuntimeApi(
          accessToken: widget.controller.session!.accessToken,
        ).usage(
          'responsibility.open',
          entityType: 'responsibility',
          entityId: capability.key,
          metadata: {
            'kernel': capability.kernelAvailable,
            'manifestVersion': capability.manifestVersion,
          },
        ),
      );
    }

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _refreshAll());
  }

  Future<void> _openReadyWork(Map<String, dynamic> item) async {
    // BRIXTA_DYNAMIC_PARTICIPANT_WORK_OPEN
    final responsibility = _map(item['responsibility']);

    final payload = _map(item['payload']);

    final capabilityId =
        item['capabilityId']?.toString() ?? responsibility['id']?.toString();

    final responsibilityKey =
        responsibility['key']?.toString() ??
        payload['responsibilityKey']?.toString() ??
        _responsibilityKeyFromAction(item['actionKey']?.toString());

    final recordId =
        payload['recordId']?.toString() ??
        item['sourceId']?.toString() ??
        item['contextId']?.toString();

    final workflowInstanceId = item['workflowInstanceId']?.toString();

    MobileCapability? capability;

    for (final module in _modules) {
      if ((capabilityId != null && module.id.toString() == capabilityId) ||
          (responsibilityKey != null && module.key == responsibilityKey)) {
        capability = module;
        break;
      }
    }

    /*
     * The actor may be involved only in THIS RECORD and therefore not
     * own the whole Responsibility in their normal module list.
     */
    if (capability == null &&
        responsibilityKey != null &&
        responsibilityKey.isNotEmpty &&
        widget.controller.isOnline) {
      try {
        final response =
            await FieldApi(
              accessToken: widget.controller.session!.accessToken,
            ).getJson(
              '/api/salesApp/responsibilities/'
              '${Uri.encodeComponent(responsibilityKey)}'
              '/manifest',
            );

        final manifest = _map(response['manifest']);

        final baseDefinition = _map(manifest['baseDefinition']);

        final resolvedId =
            int.tryParse(
              capabilityId ?? responsibility['id']?.toString() ?? '',
            ) ??
            0;

        capability = MobileCapability.fromJson({
          'id': resolvedId,

          'key': responsibilityKey,

          'title': responsibility['title']?.toString() ?? responsibilityKey,

          'type': 'record',

          'description': responsibility['description']?.toString(),

          'config': baseDefinition,

          'definition': baseDefinition,

          'runtimeManifest': {
            'kernelAvailable': response['kernelAvailable'] == true,

            'version': response['version'],

            'hash': response['manifestHash'],

            'source': response['source'],

            'manifest': manifest,
          },
        });
      } catch (error) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open delegated work: $error')),
        );

        return;
      }
    }

    if (capability == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This work item has no published Responsibility manifest.',
          ),
        ),
      );

      return;
    }

    _openCapability(
      capability,
      workflowInstanceId: workflowInstanceId,
      recordId: recordId,
    );
  }

  Future<void> _reviewApproval(Map<String, dynamic> approval) async {
    if (widget.controller.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Approval decisions need a connection. Your offline work remains safe on this phone.',
          ),
        ),
      );
      return;
    }

    final approvalId = approval['id']?.toString();
    if (approvalId == null || approvalId.isEmpty) return;

    final noteController = TextEditingController();
    String? decision;

    try {
      decision = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          final title = approval['title']?.toString() ?? 'Approval';
          final workflowName = approval['workflowName']?.toString();
          final requester = approval['requesterUserId']?.toString();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  if (workflowName != null && workflowName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      workflowName,
                      style: Theme.of(sheetContext).textTheme.bodyMedium,
                    ),
                  ],
                  if (requester != null && requester.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Requested by employee #$requester',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesign.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Decision note',
                      hintText: 'Optional note for the employee',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, 'rejected'),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, 'approved'),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (decision == null || !mounted) return;

      await FieldApi(
        accessToken: widget.controller.session!.accessToken,
      ).postJson(
        '/api/salesApp/workflow/approvals/${Uri.encodeComponent(approvalId)}/decision',
        {'decision': decision, 'note': noteController.text.trim()},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(decision == 'approved' ? 'Approved.' : 'Rejected.'),
        ),
      );
      await widget.controller.syncNow();
      await _loadWork();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      noteController.dispose();
    }
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.controller,
    required this.tracker,
    required this.workSession,
    required this.readyWork,
    required this.approvals,
    required this.modules,
    required this.loadingWork,
    required this.onRefresh,
    required this.onOpenWork,
    required this.onCapabilityTap,
  });

  final AppSessionController controller;
  final TrackingController tracker;
  final Map<String, Object?>? workSession;
  final List<Map<String, dynamic>> readyWork;
  final List<Map<String, dynamic>> approvals;
  final List<MobileCapability> modules;
  final bool loadingWork;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenWork;
  final ValueChanged<MobileCapability> onCapabilityTap;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final status = workSession?['status']?.toString();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          // BRIXTA_HOME_FLOATING_NAV_CLEARANCE
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 118),
          children: [
            _Header(
              name: session.user.name,
              designation: session.user.designation,
              refreshing: controller.refreshingWorkspace,
            ),
            const SizedBox(height: 22),
            RuntimeConnectionBanner(controller: controller),
            const SizedBox(height: 24),
            _LiveOverview(
              readyCount: readyWork.length,
              approvalCount: approvals.length,
              responsibilityCount: modules.length,
              tracker: tracker,
              sessionStatus: status,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Expanded(child: _SectionLabel('NEXT FOR YOU')),
                if (readyWork.isNotEmpty)
                  TextButton(
                    onPressed: onOpenWork,
                    child: const Text('View all'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (loadingWork)
              const LinearProgressIndicator(minHeight: 2)
            else if (approvals.isNotEmpty)
              _NextCard(
                title:
                    approvals.first['title']?.toString() ??
                    'Approval needs your attention',
                description: 'Open Work to review and decide.',
                icon: LucideIcons.shield_check,
                tone: AppDesign.green,
                onTap: onOpenWork,
              )
            else if (readyWork.isNotEmpty)
              _NextCard.fromWork(readyWork.first, onTap: onOpenWork)
            else
              const _QuietState(),
            if (modules.isNotEmpty) ...[
              const SizedBox(height: 32),
              const _SectionLabel('YOUR RESPONSIBILITIES'),
              const SizedBox(height: 12),
              _QuickResponsibilityGrid(
                modules: modules.take(4).toList(),
                onTap: onCapabilityTap,
              ),
            ],
            // Floating navigation overlays the body.
            const SizedBox(height: 92),
          ],
        ),
      ),
    );
  }
}

// _WorkTab removed after migration to PremiumWorkTab.

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.designation,
    required this.refreshing,
  });

  final String name;
  final String designation;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final firstName = name.trim().split(RegExp(r'\s+')).first;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppDesign.sans(
                  size: 32,
                  weight: FontWeight.w700,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                designation.trim().isEmpty ? _dateLabel() : designation,
                style: AppDesign.sans(
                  size: 13,
                  color: AppDesign.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppDesign.ink,
            shape: BoxShape.circle,
            border: Border.all(color: AppDesign.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: refreshing
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppDesign.white,
                  ),
                )
              : Text(
                  _initials(name),
                  style: AppDesign.sans(
                    size: 14,
                    color: AppDesign.white,
                    weight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'BR';

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String _dateLabel() {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final now = DateTime.now();

    return '${weekdays[now.weekday - 1]} · Your workspace is ready';
  }
}

class _LiveOverview extends StatelessWidget {
  const _LiveOverview({
    required this.readyCount,
    required this.approvalCount,
    required this.responsibilityCount,
    required this.tracker,
    required this.sessionStatus,
  });

  final int readyCount;
  final int approvalCount;
  final int responsibilityCount;
  final TrackingController tracker;
  final String? sessionStatus;

  @override
  Widget build(BuildContext context) {
    final active = sessionStatus == 'active' || tracker.active;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDesign.heroRadius),
      child: SizedBox(
        height: 330,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/brixta_work_hero.jpg',
              fit: BoxFit.cover,
              cacheWidth: 1000,
              filterQuality: FilterQuality.medium,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x08000000),
                    Color(0x26000000),
                    Color(0xD9000000),
                  ],
                  stops: [0, .45, 1],
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppDesign.white.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(AppDesign.pillRadius),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? AppDesign.green : AppDesign.muted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      active ? 'FIELD SESSION ACTIVE' : 'TODAY',
                      style: AppDesign.mono(
                        size: 7.5,
                        color: AppDesign.ink,
                        weight: FontWeight.w700,
                        letterSpacing: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    active ? 'You’re in motion.' : 'Everything is ready.',
                    style: AppDesign.sans(
                      size: 27,
                      color: AppDesign.white,
                      weight: FontWeight.w700,
                      height: 1.02,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: tracker,
                    builder: (_, _) => Text(
                      tracker.active
                          ? '${tracker.distanceKm.toStringAsFixed(1)} km recorded today'
                          : '$responsibilityCount Responsibilities available',
                      style: AppDesign.sans(
                        size: 13,
                        color: AppDesign.white.withValues(alpha: .74),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(value: '$readyCount', label: 'READY'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Metric(
                          value: '$approvalCount',
                          label: 'DECISIONS',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Metric(
                          value: '$responsibilityCount',
                          label: 'WORK',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppDesign.ink.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesign.white.withValues(alpha: .12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppDesign.sans(
              size: 19,
              color: AppDesign.white,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: AppDesign.mono(
              size: 6.5,
              color: AppDesign.white.withValues(alpha: .62),
              weight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickResponsibilityGrid extends StatelessWidget {
  const _QuickResponsibilityGrid({required this.modules, required this.onTap});

  final List<MobileCapability> modules;
  final ValueChanged<MobileCapability> onTap;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;

        final tileWidth = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final module in modules)
              SizedBox(
                width: tileWidth,
                height: 174,
                child: _ResponsibilityTile(
                  module: module,
                  onTap: () => onTap(module),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ResponsibilityTile extends StatelessWidget {
  const _ResponsibilityTile({required this.module, required this.onTap});

  final MobileCapability module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesign.white,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppDesign.line.withValues(alpha: .72)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppDesign.softGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.forCapability(module),
                      color: AppDesign.green,
                      size: 21,
                    ),
                  ),

                  const Spacer(),

                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppDesign.softGray.withValues(alpha: .7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: AppDesign.muted,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              Text(
                module.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppDesign.sans(
                  size: 16,
                  weight: FontWeight.w600,
                  height: 1.12,
                  letterSpacing: -.2,
                ),
              ),

              const SizedBox(height: 7),

              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: module.kernelAvailable
                          ? AppDesign.green
                          : AppDesign.faint,
                      shape: BoxShape.circle,
                    ),
                  ),

                  const SizedBox(width: 7),

                  Expanded(
                    child: Text(
                      module.kernelAvailable ? 'Ready to open' : 'Available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesign.sans(size: 11, color: AppDesign.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// _CapabilityList removed after PremiumWorkTab migration.

// _CapabilityRow removed after PremiumWorkTab migration.

class _NextCard extends StatelessWidget {
  const _NextCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  factory _NextCard.fromWork(
    Map<String, dynamic> item, {
    required VoidCallback onTap,
  }) {
    return _NextCard(
      title: item['title']?.toString() ?? _workActionLabel(item),
      description: _workSubtitle(item),
      icon: LucideIcons.circle_play,
      tone: AppDesign.green,
      onTap: onTap,
    );
  }

  final String title;
  final String description;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppDesign.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radius),
        side: const BorderSide(color: AppDesign.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppDesign.controlRadius),
                ),
                child: Icon(icon, color: tone, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, size: 18, color: AppDesign.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// _WorkNotice removed after PremiumWorkTab migration.

class _QuietState extends StatelessWidget {
  const _QuietState();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Row(
        children: [
          Icon(AppIcons.check, size: 20, color: AppDesign.green),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Nothing needs your attention right now.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
        color: AppDesign.muted,
      ),
    );
  }
}

bool _capabilityNeedsTracking(MobileCapability capability) {
  for (final field in capability.fields) {
    final type = (field['inputType'] ?? field['type'] ?? '')
        .toString()
        .toLowerCase();

    if (type == 'location_route' ||
        type == 'route' ||
        type == 'route_movement') {
      return true;
    }
  }

  return _kernelNeedsTracking(capability);
}

bool _kernelNeedsTracking(MobileCapability capability) {
  if (!capability.kernelAvailable) return false;
  final kernel = capability.kernelDefinition;
  final possibilities = kernel['possibilities'];
  if (possibilities is! List) return false;
  for (final item in possibilities.whereType<Map>()) {
    final capture = item['capture'];
    if (capture is Map) {
      final kind = capture['kind']?.toString().toLowerCase() ?? '';
      if (kind.contains('route') ||
          kind.contains('movement') ||
          kind.contains('distance')) {
        return true;
      }
    }
  }
  return false;
}
// _capabilityHint removed after PremiumWorkTab migration.

String? _responsibilityKeyFromAction(String? actionKey) {
  if (actionKey == null || !actionKey.startsWith('responsibility.')) {
    return null;
  }
  final parts = actionKey.split('.');
  if (parts.length < 3) return null;
  return parts.sublist(1, parts.length - 1).join('.');
}

String _workActionLabel(Map<String, dynamic> item) {
  return (item['label'] ?? item['actionKey'] ?? item['kind'] ?? 'Work item')
      .toString();
}

String _workSubtitle(Map<String, dynamic> item) {
  final responsibility = _map(item['responsibility']);
  return item['description']?.toString() ??
      responsibility['title']?.toString() ??
      item['reason']?.toString() ??
      'Ready to continue';
}

String _workScope(dynamic session) =>
    '${session.tenant.code}:${session.user.id}';

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : <Map<String, dynamic>>[];
