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
  final List<Map<String, dynamic>> _approvals = const [];
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
            // Approvals are decided in the CMS dashboard only. Rendering
            // them here was also surfacing a submitter's own request
            // back to their own account as something to "approve" --
            // never intentional. Leave _approvals at its default empty
            // list instead of wiring the backend response into it.
            // _approvals = approvals;
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
        // See _refreshWork -- approvals are CMS-only, never rendered here.
        // _approvals = _mapList(map['approvals']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(AppIcons.home),
        selectedIcon: Icon(AppIcons.home, color: AppDesign.green),
        label: 'HOME',
      ),
      NavigationDestination(
        icon: Icon(AppIcons.work),
        selectedIcon: Icon(AppIcons.work, color: AppDesign.green),
        label: 'WORK',
      ),
      NavigationDestination(
        icon: Icon(AppIcons.profile),
        selectedIcon: Icon(AppIcons.profile, color: AppDesign.green),
        label: 'ME',
      ),
    ];

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
      _WorkTab(
        controller: widget.controller,
        modules: _modules,
        readyWork: _readyWork,
        blockedWork: _blockedWork,
        approvals: _approvals,
        onRefresh: () => _refreshAll(refreshWorkspace: true),
        onCapabilityTap: _openCapability,
        onReadyTap: _openReadyWork,
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
      body: screens[safeTab],
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppDesign.surface,
          border: Border(top: BorderSide(color: AppDesign.line)),
        ),
        child: NavigationBar(
          selectedIndex: safeTab,
          destinations: destinations,
          onDestinationSelected: (index) => setState(() => _tab = index),
        ),
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

  void _openReadyWork(Map<String, dynamic> item) {
    final capabilityId =
        item['capabilityId']?.toString() ??
        _map(item['responsibility'])['id']?.toString();
    final responsibilityKey =
        _map(item['responsibility'])['key']?.toString() ??
        _responsibilityKeyFromAction(item['actionKey']?.toString());

    MobileCapability? capability;
    for (final module in _modules) {
      if ((capabilityId != null && module.id.toString() == capabilityId) ||
          (responsibilityKey != null && module.key == responsibilityKey)) {
        capability = module;
        break;
      }
    }

    if (capability == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This work item is not available on this device yet.'),
        ),
      );
      return;
    }

    _openCapability(
      capability,
      workflowInstanceId: item['workflowInstanceId']?.toString(),
      recordId: item['sourceId']?.toString() ?? item['contextId']?.toString(),
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
          padding: AppDesign.pageInset,
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
          ],
        ),
      ),
    );
  }
}

class _WorkTab extends StatelessWidget {
  const _WorkTab({
    required this.controller,
    required this.modules,
    required this.readyWork,
    required this.blockedWork,
    required this.approvals,
    required this.onRefresh,
    required this.onCapabilityTap,
    required this.onReadyTap,
    required this.onApprovalTap,
  });

  final AppSessionController controller;
  final List<MobileCapability> modules;
  final List<Map<String, dynamic>> readyWork;
  final List<Map<String, dynamic>> blockedWork;
  final List<Map<String, dynamic>> approvals;
  final Future<void> Function() onRefresh;
  final ValueChanged<MobileCapability> onCapabilityTap;
  final ValueChanged<Map<String, dynamic>> onReadyTap;
  final ValueChanged<Map<String, dynamic>> onApprovalTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: AppDesign.pageInset,
          children: [
            Text('Work', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Your company controls what appears here. Published changes arrive automatically when you are online.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            RuntimeConnectionBanner(controller: controller, compact: false),
            if (approvals.isNotEmpty) ...[
              const SizedBox(height: 30),
              const _SectionLabel('NEEDS YOUR DECISION'),
              const SizedBox(height: 12),
              for (final approval in approvals.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WorkNotice(
                    icon: LucideIcons.shield_check,
                    title: approval['title']?.toString() ?? 'Approval',
                    subtitle: 'Tap to review and decide',
                    tone: AppDesign.green,
                    onTap: () => onApprovalTap(approval),
                  ),
                ),
            ],
            if (readyWork.isNotEmpty) ...[
              const SizedBox(height: 30),
              const _SectionLabel('READY NOW'),
              const SizedBox(height: 12),
              for (final item in readyWork.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WorkNotice(
                    icon: LucideIcons.circle_play,
                    title: item['title']?.toString() ?? _workActionLabel(item),
                    subtitle: _workSubtitle(item),
                    tone: AppDesign.green,
                    onTap: () => onReadyTap(item),
                  ),
                ),
            ],
            const SizedBox(height: 30),
            const _SectionLabel('RESPONSIBILITIES'),
            const SizedBox(height: 12),
            if (modules.isEmpty)
              const _QuietState()
            else
              _CapabilityList(modules: modules, onTap: onCapabilityTap),
            if (blockedWork.isNotEmpty) ...[
              const SizedBox(height: 30),
              const _SectionLabel('WAITING'),
              const SizedBox(height: 12),
              for (final item in blockedWork.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WorkNotice(
                    icon: LucideIcons.lock_keyhole,
                    title: item['title']?.toString() ?? _workActionLabel(item),
                    subtitle:
                        item['reason']?.toString() ??
                        'Waiting for an earlier step',
                    tone: AppDesign.muted,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dateLabel(),
                style: const TextStyle(
                  color: AppDesign.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Good ${_dayPart()}, $name',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(designation, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (refreshing)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  static String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
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
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: AppDesign.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Right now',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Metric(value: '$readyCount', label: 'Ready'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(value: '$approvalCount', label: 'Approvals'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(value: '$responsibilityCount', label: 'Tools'),
              ),
            ],
          ),
          if (sessionStatus == 'active' || tracker.active) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppDesign.greenWash,
                borderRadius: BorderRadius.circular(AppDesign.controlRadius),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.journey, size: 18, color: AppDesign.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: tracker,
                      builder: (_, _) => Text(
                        tracker.active
                            ? 'Field session active · ${tracker.distanceKm.toStringAsFixed(1)} km recorded'
                            : 'Work session active',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppDesign.greenWash,
        borderRadius: BorderRadius.circular(AppDesign.controlRadius),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppDesign.greenDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppDesign.muted,
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: modules
          .map(
            (module) => SizedBox(
              width: (MediaQuery.sizeOf(context).width - 58) / 2,
              child: Material(
                color: AppDesign.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesign.radius),
                  side: const BorderSide(color: AppDesign.line),
                ),
                child: InkWell(
                  onTap: () => onTap(module),
                  borderRadius: BorderRadius.circular(AppDesign.radius),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          AppIcons.forCapability(module),
                          color: AppDesign.green,
                          size: 21,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          module.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (module.kernelAvailable) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Live v${module.manifestVersion}',
                            style: const TextStyle(
                              color: AppDesign.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CapabilityList extends StatelessWidget {
  const _CapabilityList({required this.modules, required this.onTap});
  final List<MobileCapability> modules;
  final ValueChanged<MobileCapability> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < modules.length; i++) ...[
            _CapabilityRow(
              capability: modules[i],
              onTap: () => onTap(modules[i]),
            ),
            if (i != modules.length - 1) const Divider(indent: 56),
          ],
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.capability, required this.onTap});
  final MobileCapability capability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: capability.kernelAvailable
                      ? AppDesign.softGreen
                      : AppDesign.softGray,
                  borderRadius: BorderRadius.circular(AppDesign.controlRadius),
                ),
                alignment: Alignment.center,
                child: Icon(
                  AppIcons.forCapability(capability),
                  size: 19,
                  color: capability.kernelAvailable
                      ? AppDesign.green
                      : AppDesign.ink,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capability.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _capabilityHint(capability),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppDesign.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (capability.kernelAvailable)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesign.softGreen,
                    borderRadius: BorderRadius.circular(AppDesign.radius),
                  ),
                  child: Text(
                    'v${capability.manifestVersion}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppDesign.greenDark,
                    ),
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

class _WorkNotice extends StatelessWidget {
  const _WorkNotice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback? onTap;

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
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppDesign.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(AppIcons.chevronRight, size: 17, color: AppDesign.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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

String _capabilityHint(MobileCapability capability) {
  final description = capability.description?.trim() ?? '';

  if (description.isNotEmpty) {
    return description;
  }

  return 'Company Responsibility';
}

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