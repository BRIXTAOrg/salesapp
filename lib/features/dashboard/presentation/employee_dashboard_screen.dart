import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/models/mobile_capability.dart';
import '../../../core/offline/offline_attendance_queue.dart';
import '../../../core/offline/offline_submission_queue.dart';
import '../../../core/session/app_session_controller.dart';
import '../../allowances/presentation/allowances_screen.dart';
import '../../attendance/presentation/attendance_screen.dart';
import '../../dynamic/presentation/dynamic_capability_screen.dart';
import '../../tracking/data/native_tracking_repository.dart';
import '../../tracking/presentation/tracking_controller.dart';
import '../../tracking/presentation/tracking_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({
    super.key,
    required this.controller,
  });

  final AppSessionController controller;

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen>
    with WidgetsBindingObserver {
  late final TrackingController tracker;

  List<Map<String, dynamic>> _workItems = const [];
  Map<String, Object?>? _workSession;
  bool _loadingWork = true;
  int _tab = 0;
  bool _reconciling = false;

  List<MobileCapability> get _modules =>
      widget.controller.session?.modules ?? const [];

  bool get _hasTaDa => _modules.any((m) => m.key == 'ta_da');

  bool get _needsTravelCapability => _modules.any(
        (m) =>
            m.key == 'ta_da' ||
            m.key == 'live_location' ||
            m.key == 'journey_plan',
      );

  // bool get _sessionActive => _workSession?['status'] == 'active';
  // bool get _sessionCompleted => _workSession?['status'] == 'completed';

  List<Map<String, dynamic>> get _visibleWorkItems {
    final activeCapabilityIds = _modules.map((m) => m.id.toString()).toSet();
    return _workItems.where((item) {
      final capabilityId = item['capabilityId'] ?? item['capability_id'];
      if (capabilityId == null) return true;
      return activeCapabilityIds.contains(capabilityId.toString());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);

    tracker = TrackingController(
      repository: NativeTrackingRepository(),
    );

    unawaited(
      tracker
          .initialize(
            accessToken: widget.controller.session!.accessToken,
          )
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
    setState(() {});
    unawaited(_reconcileTracking());
  }

  Future<void> _refreshAll({bool refreshWorkspace = false}) async {
    if (refreshWorkspace) {
      await widget.controller.refreshWorkspace();
    }

    await Future.wait([
      _loadWork(),
      _loadWorkSession(),
    ]);

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
      final local = await AppDatabase.instance.todayWorkSession(session.user.id);
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

    final token = session.accessToken;

    try {
      await OfflineSubmissionQueue.flush(token);
      await OfflineAttendanceQueue.flush(token);

      final response = await FieldApi(
        accessToken: token,
      ).getJson('/api/salesApp/work-items');

      final raw = response['workItems'];
      if (raw is List) {
        final fresh = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where(
              (e) =>
                  e['status'] != 'completed' &&
                  e['status'] != 'cancelled',
            )
            .toList();

        await AppDatabase.instance.putCache('work_items', fresh);
        if (mounted) setState(() => _workItems = fresh);
      }
    } catch (_) {
      final cached = await AppDatabase.instance.getCache('work_items');
      if (cached is List && mounted) {
        setState(() {
          _workItems = cached
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } finally {
      if (mounted) setState(() => _loadingWork = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: Icon(AppIcons.home),
        selectedIcon: Icon(AppIcons.home, color: AppDesign.primary),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(AppIcons.work),
        selectedIcon: Icon(AppIcons.work, color: AppDesign.primary),
        label: 'Work',
      ),
      if (_hasTaDa)
        NavigationDestination(
          icon: Icon(AppIcons.wallet),
          selectedIcon: Icon(AppIcons.wallet, color: AppDesign.primary),
          label: 'TA / DA',
        ),
      NavigationDestination(
        icon: Icon(AppIcons.profile),
        selectedIcon: Icon(AppIcons.profile, color: AppDesign.primary),
        label: 'Me',
      ),
    ];

    final screens = <Widget>[
      _HomeTab(
        controller: widget.controller,
        tracker: tracker,
        workSession: _workSession,
        workItems: _visibleWorkItems,
        loadingWork: _loadingWork,
        onRefresh: () => _refreshAll(refreshWorkspace: true),
        onOpenWork: () => setState(() => _tab = 1),
        onCapabilityTap: _openCapability,
      ),
      _WorkTab(
        modules: _modules,
        onRefresh: () => _refreshAll(refreshWorkspace: true),
        onCapabilityTap: _openCapability,
      ),
      if (_hasTaDa)
        AllowancesScreen(
          controller: widget.controller,
          trackingController: tracker,
        ),
      _ProfileTab(
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

  void _openCapability(MobileCapability capability) {
    late final Widget screen;

    switch (capability.key) {
      case 'attendance':
        screen = AttendanceScreen(
          controller: widget.controller,
          trackingController: tracker,
          onReviewTaDa: _hasTaDa
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AllowancesScreen(
                        controller: widget.controller,
                        trackingController: tracker,
                      ),
                    ),
                  );
                }
              : null,
        );
        break;
      case 'ta_da':
        screen = AllowancesScreen(
          controller: widget.controller,
          trackingController: tracker,
        );
        break;
      case 'live_location':
        screen = TrackingScreen(controller: tracker);
        break;
      default:
        screen = DynamicCapabilityScreen(
          controller: widget.controller,
          capability: capability,
        );
        break;
    }

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _refreshAll());
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.controller,
    required this.tracker,
    required this.workSession,
    required this.workItems,
    required this.loadingWork,
    required this.onRefresh,
    required this.onOpenWork,
    required this.onCapabilityTap,
  });

  final AppSessionController controller;
  final TrackingController tracker;
  final Map<String, Object?>? workSession;
  final List<Map<String, dynamic>> workItems;
  final bool loadingWork;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenWork;
  final ValueChanged<MobileCapability> onCapabilityTap;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final modules = session.modules;
    final attendance = _findCapability(modules, 'attendance');
    final status = workSession?['status']?.toString();
    final checkIn = _parseDate(workSession?['check_in_at']);

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
            const SizedBox(height: 48),
            const _SectionLabel('TODAY'),
            const SizedBox(height: 16),
            _TodayPanel(
              attendanceStatus: status,
              checkIn: checkIn,
              openWork: workItems.length,
              tracker: tracker,
              offline: controller.isOffline,
              onAttendance: attendance == null
                  ? null
                  : () => onCapabilityTap(attendance),
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                const Expanded(child: _SectionLabel('NEXT')),
                if (workItems.isNotEmpty)
                  TextButton(
                    onPressed: onOpenWork,
                    child: const Text('View work'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (loadingWork)
              const LinearProgressIndicator(minHeight: 2)
            else if (workItems.isEmpty)
              const _QuietState()
            else
              _NextWorkCard(item: workItems.first, onTap: onOpenWork),
            const SizedBox(height: 48),
            _PassiveNote(
              offline: controller.isOffline,
              sessionActive: status == 'active',
            ),
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
                  fontWeight: FontWeight.w500,
                  letterSpacing: .24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Good ${_dayPart()}, $name',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                designation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (refreshing)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 16,
              height: 16,
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
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({
    required this.attendanceStatus,
    required this.checkIn,
    required this.openWork,
    required this.tracker,
    required this.offline,
    required this.onAttendance,
  });

  final String? attendanceStatus;
  final DateTime? checkIn;
  final int openWork;
  final TrackingController tracker;
  final bool offline;
  final VoidCallback? onAttendance;

  @override
  Widget build(BuildContext context) {
    final isActive = attendanceStatus == 'active';
    final isComplete = attendanceStatus == 'completed';

    return Container(
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        children: [
          _DataRow(
            icon: AppIcons.attendance,
            label: 'Attendance',
            value: isComplete
                ? 'Complete'
                : isActive
                    ? checkIn == null
                        ? 'Checked in'
                        : 'Checked in ${_time(checkIn!)}'
                    : 'Not checked in',
            actionLabel: !isComplete && onAttendance != null
                ? isActive
                    ? 'Open'
                    : 'Check in'
                : null,
            onAction: onAttendance,
          ),
          const Divider(indent: 56),
          _DataRow(
            icon: LucideIcons.clipboard_list,
            label: 'Open work',
            value: '$openWork',
          ),
          const Divider(indent: 56),
          AnimatedBuilder(
            animation: tracker,
            builder: (_, _) => _DataRow(
              icon: AppIcons.journey,
              label: 'Travel',
              value: '${tracker.distanceKm.toStringAsFixed(1)} km',
            ),
          ),
          const Divider(indent: 56),
          _DataRow(
            icon: offline ? AppIcons.cloudOff : AppIcons.cloud,
            label: 'Sync',
            value: offline ? 'Safe offline' : 'Ready',
          ),
        ],
      ),
    );
  }

  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.label,
    required this.value,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppDesign.muted),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppDesign.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppDesign.ink,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _NextWorkCard extends StatelessWidget {
  const _NextWorkCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? 'Assigned work').toString();
    final description = item['description']?.toString();
    final due = item['dueAt']?.toString();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.briefcase_business, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description != null && description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (due != null && due.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Due $due',
                        style: const TextStyle(fontSize: 12, color: AppDesign.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, size: 18, color: AppDesign.muted),
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
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Nothing needs your attention right now.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppDesign.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PassiveNote extends StatelessWidget {
  const _PassiveNote({required this.offline, required this.sessionActive});

  final bool offline;
  final bool sessionActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          offline ? AppIcons.cloudOff : LucideIcons.shield_check,
          size: 18,
          color: AppDesign.muted,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            offline
                ? 'Keep working. Changes are safe on this phone and will sync automatically.'
                : sessionActive
                    ? 'Your work session is active. Time, route and context are being recorded where needed.'
                    : 'Do the work in the real world. Salesapp remembers the rest.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _WorkTab extends StatelessWidget {
  const _WorkTab({
    required this.modules,
    required this.onRefresh,
    required this.onCapabilityTap,
  });

  final List<MobileCapability> modules;
  final Future<void> Function() onRefresh;
  final ValueChanged<MobileCapability> onCapabilityTap;

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
              'Only the tools currently assigned to you appear here.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),
            const _SectionLabel('ASSIGNED TO YOU'),
            const SizedBox(height: 16),
            if (modules.isEmpty)
              const _QuietState()
            else
              _CapabilityList(
                modules: modules,
                onTap: onCapabilityTap,
              ),
          ],
        ),
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(
                  AppIcons.forCapability(capability),
                  size: 20,
                  color: AppDesign.ink,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capability.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppDesign.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _capabilityHint(capability),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppDesign.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, size: 18, color: AppDesign.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.controller,
    required this.tracker,
    required this.workSession,
  });

  final AppSessionController controller;
  final TrackingController tracker;
  final Map<String, Object?>? workSession;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;

    return SafeArea(
      child: ListView(
        padding: AppDesign.pageInset,
        children: [
          Text('Account', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 48),
          const _SectionLabel('EMPLOYEE'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppDesign.surface,
              border: Border.all(color: AppDesign.line),
              borderRadius: BorderRadius.circular(AppDesign.radius),
            ),
            child: Row(
              children: [
                Icon(AppIcons.profile, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.user.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${session.user.designation} · ${session.user.employeeCode}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          const _SectionLabel('STATUS'),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppDesign.surface,
              border: Border.all(color: AppDesign.line),
              borderRadius: BorderRadius.circular(AppDesign.radius),
            ),
            child: Column(
              children: [
                _DataRow(
                  icon: AppIcons.attendance,
                  label: 'Work session',
                  value: _sessionLabel(workSession),
                ),
                const Divider(indent: 56),
                AnimatedBuilder(
                  animation: tracker,
                  builder: (_, _) => _DataRow(
                    icon: AppIcons.journey,
                    label: 'Travel meter',
                    value: tracker.active ? 'Active' : 'Standby',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          OutlinedButton.icon(
            onPressed: controller.logout,
            icon: Icon(AppIcons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  static String _sessionLabel(Map<String, Object?>? value) {
    switch (value?['status']) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Complete';
      default:
        return 'Not started';
    }
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
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: .24,
        color: AppDesign.muted,
      ),
    );
  }
}

MobileCapability? _findCapability(
  List<MobileCapability> modules,
  String key,
) {
  for (final module in modules) {
    if (module.key == key) return module;
  }
  return null;
}

DateTime? _parseDate(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toLocal();
}

String _capabilityHint(MobileCapability capability) {
  if (capability.description?.trim().isNotEmpty == true) {
    return capability.description!.trim();
  }

  switch (capability.key) {
    case 'attendance':
      return 'Check in / check out';
    case 'dealer_visit':
      return 'Record a dealer visit';
    case 'journey_plan':
      return 'Today’s assigned route';
    case 'leave':
      return 'Request time off';
    case 'live_location':
      return 'View your field route';
    case 'ta_da':
      return 'Travel, expenses and claims';
  }

  switch (capability.type.toLowerCase()) {
    case 'checklist':
      return 'Guided checklist';
    case 'upload':
      return 'Photo evidence';
    case 'report':
      return 'View report';
    default:
      return 'Record work';
  }
}
