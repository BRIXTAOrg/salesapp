import 'package:flutter/material.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
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

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  late final TrackingController tracker;

  List<Map<String, dynamic>> _workItems = const [];
  bool _loadingWork = true;
  int _tab = 0;

  bool get _hasTaDa =>
      widget.controller.session!.modules.any((m) => m.key == 'ta_da');

  bool get _needsAutomaticTracking =>
      widget.controller.session!.modules.any(
        (m) =>
            m.key == 'ta_da' ||
            m.key == 'live_location' ||
            m.key == 'journey_plan',
      );

  @override
  void initState() {
    super.initState();

    tracker = TrackingController(
      repository: NativeTrackingRepository(),
    );

    tracker.initialize(
      accessToken: widget.controller.session!.accessToken,
    ).then((_) {
      if (_needsAutomaticTracking) {
        tracker.ensureAutomatic(
          widget.controller.session!.user.id,
        );
      }
    });

    _loadWork();
  }

  @override
  void dispose() {
    tracker.dispose();
    super.dispose();
  }

  Future<void> _loadWork() async {
    final token = widget.controller.session!.accessToken;

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

        await AppDatabase.instance.putCache(
          'work_items',
          fresh,
        );

        if (mounted) {
          setState(() => _workItems = fresh);
        }
      }
    } catch (_) {
      final cached =
          await AppDatabase.instance.getCache('work_items');

      if (cached is List && mounted) {
        setState(() {
          _workItems = cached
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingWork = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: 'Work',
      ),
      if (_hasTaDa)
        const NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet_rounded),
          label: 'TA / DA',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Me',
      ),
    ];

    final screens = <Widget>[
      _HomeTab(
        controller: widget.controller,
        tracker: tracker,
        workItems: _workItems,
        loadingWork: _loadingWork,
        onCapabilityTap: _openCapability,
      ),
      _WorkTab(
        modules: widget.controller.session!.modules,
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
      ),
    ];

    final safeTab =
        _tab >= 0 && _tab < screens.length ? _tab : 0;

    return Scaffold(
      body: screens[safeTab],
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppDesign.line),
          ),
        ),
        child: NavigationBar(
          selectedIndex: safeTab,
          destinations: destinations,
          onDestinationSelected: (index) {
            setState(() => _tab = index);
          },
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

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.controller,
    required this.tracker,
    required this.workItems,
    required this.loadingWork,
    required this.onCapabilityTap,
  });

  final AppSessionController controller;
  final TrackingController tracker;
  final List<Map<String, dynamic>> workItems;
  final bool loadingWork;
  final ValueChanged<MobileCapability> onCapabilityTap;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await tracker.refresh();
          await controller.syncNow();
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _HomeHeader(
                name: session.user.name,
                designation: session.user.designation,
              ),
            ),
            if (controller.isOffline) ...[
              const SizedBox(height: 14),
              Padding(
                padding: AppDesign.pagePadding,
                child: _OfflineNotice(
                  pending: controller.syncSnapshot.pendingCount,
                ),
              ),
            ],
            const SizedBox(height: 25),
            Padding(
              padding: AppDesign.pagePadding,
              child: Text(
                'Today’s Summary',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: AppDesign.pagePadding,
              child: _SummaryCard(
                tracker: tracker,
                openItems: workItems.length,
                offline: controller.isOffline,
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: AppDesign.pagePadding,
              child: _SectionHeader(
                title: 'Today',
                trailing: loadingWork
                    ? null
                    : workItems.isEmpty
                        ? 'Clear'
                        : '${workItems.length} open',
              ),
            ),
            const SizedBox(height: 12),
            if (loadingWork)
              const Padding(
                padding: AppDesign.pagePadding,
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (workItems.isEmpty)
              const Padding(
                padding: AppDesign.pagePadding,
                child: _AllClearCard(),
              )
            else
              SizedBox(
                height: 184,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  scrollDirection: Axis.horizontal,
                  itemCount: workItems.length.clamp(0, 6),
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: 10),
                  itemBuilder: (_, index) =>
                      _TaskCard(item: workItems[index]),
                ),
              ),
            const SizedBox(height: 28),
            Padding(
              padding: AppDesign.pagePadding,
              child: const _SectionHeader(
                title: 'Work tools',
                trailing: 'Assigned',
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: AppDesign.pagePadding,
              child: _CapabilityGrid(
                modules: session.modules,
                onTap: onCapabilityTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.name,
    required this.designation,
  });

  final String name;
  final String designation;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

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
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Welcome, $name',
                style: const TextStyle(
                  color: AppDesign.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (designation.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  designation,
                  style: const TextStyle(
                    color: AppDesign.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppDesign.line),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
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
    return '${weekdays[now.weekday - 1]}, '
        '${now.day} ${months[now.month - 1]}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.tracker,
    required this.openItems,
    required this.offline,
  });

  final TrackingController tracker;
  final int openItems;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tracker,
      builder: (_, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Open work',
                      value: '$openItems',
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                  const _VerticalRule(),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Travel',
                      value:
                          '${tracker.distanceKm.toStringAsFixed(1)} km',
                      icon: Icons.route_outlined,
                    ),
                  ),
                  const _VerticalRule(),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Sync',
                      value: offline ? 'Offline' : 'Ready',
                      icon: offline
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_done_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: tracker.active
                      ? AppDesign.softGreen
                      : AppDesign.softGray,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Icon(
                      tracker.active
                          ? Icons.location_on_outlined
                          : Icons.location_off_outlined,
                      size: 17,
                      color: tracker.active
                          ? AppDesign.green
                          : AppDesign.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tracker.active
                            ? 'Travel capture is running automatically.'
                            : 'Travel capture is on standby.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppDesign.muted),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppDesign.muted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 55,
      color: AppDesign.line,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: AppDesign.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final priority = item['priority']?.toString();
    final due = item['dueAt']?.toString();

    return Container(
      width: 210,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesign.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppDesign.softBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 17,
                ),
              ),
              const Spacer(),
              if (priority != null && priority.isNotEmpty)
                _StatusPill(
                  text: priority,
                  color: AppDesign.softAmber,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            (item['title'] ?? 'Assignment').toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (due != null && due.isNotEmpty)
            Text(
              'Due $due',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppDesign.muted,
                fontSize: 11.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppDesign.line),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppDesign.softGreen,
            child: Icon(
              Icons.check_rounded,
              color: AppDesign.green,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nothing pending right now.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityGrid extends StatelessWidget {
  const _CapabilityGrid({
    required this.modules,
    required this.onTap,
  });

  final List<MobileCapability> modules;
  final ValueChanged<MobileCapability> onTap;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const _AllClearCard();
    }

    return GridView.builder(
      itemCount: modules.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.22,
      ),
      itemBuilder: (_, index) {
        final capability = modules[index];

        return _CapabilityTile(
          capability: capability,
          onTap: () => onTap(capability),
        );
      },
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({
    required this.capability,
    required this.onTap,
  });

  final MobileCapability capability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _capabilityAccent(capability);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppDesign.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.$2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _capabilityIcon(capability),
                  size: 20,
                  color: accent.$1,
                ),
              ),
              const Spacer(),
              Text(
                capability.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _capabilityHint(capability),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppDesign.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.pending});

  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppDesign.softAmber,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              pending > 0
                  ? 'Offline • $pending change${pending == 1 ? '' : 's'} waiting safely'
                  : 'Offline • work is being saved on this phone',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTab extends StatelessWidget {
  const _WorkTab({
    required this.modules,
    required this.onCapabilityTap,
  });

  final List<MobileCapability> modules;
  final ValueChanged<MobileCapability> onCapabilityTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
        children: [
          Text(
            'Work',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Forms, inspections and tools assigned to you.',
            style: TextStyle(color: AppDesign.muted),
          ),
          const SizedBox(height: 22),
          _CapabilityGrid(
            modules: modules,
            onTap: onCapabilityTap,
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.controller,
    required this.tracker,
  });

  final AppSessionController controller;
  final TrackingController tracker;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
        children: [
          Text(
            'Account',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppDesign.softGray,
                    child: Text(
                      session.user.name.isEmpty
                          ? '?'
                          : session.user.name.characters.first
                              .toUpperCase(),
                      style: const TextStyle(
                        color: AppDesign.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.user.designation,
                          style: const TextStyle(
                            color: AppDesign.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: tracker,
            builder: (_, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('Travel capture'),
                subtitle: const Text(
                  'Automatic for travel-enabled responsibilities.',
                ),
                trailing: Text(
                  tracker.active ? 'Active' : 'Standby',
                  style: TextStyle(
                    color: tracker.active
                        ? AppDesign.green
                        : AppDesign.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: controller.logout,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _capabilityIcon(MobileCapability capability) {
  switch (capability.key) {
    case 'attendance':
      return Icons.fingerprint_rounded;
    case 'ta_da':
      return Icons.account_balance_wallet_outlined;
    case 'live_location':
      return Icons.route_outlined;
    case 'dealer_visit':
      return Icons.storefront_outlined;
    case 'journey_plan':
      return Icons.alt_route_rounded;
    case 'leave':
      return Icons.event_busy_outlined;
  }

  switch (capability.type) {
    case 'form':
      return Icons.description_outlined;
    case 'checklist':
      return Icons.fact_check_outlined;
    case 'upload':
      return Icons.add_a_photo_outlined;
    case 'report':
      return Icons.bar_chart_outlined;
    default:
      return Icons.widgets_outlined;
  }
}

(Color, Color) _capabilityAccent(
  MobileCapability capability,
) {
  switch (capability.key) {
    case 'attendance':
      return (AppDesign.green, AppDesign.softGreen);
    case 'ta_da':
      return (AppDesign.blue, AppDesign.softBlue);
    case 'leave':
      return (AppDesign.red, AppDesign.softRed);
    case 'live_location':
    case 'journey_plan':
      return (AppDesign.amber, AppDesign.softAmber);
    default:
      return (AppDesign.ink, AppDesign.softGray);
  }
}

String _capabilityHint(MobileCapability capability) {
  switch (capability.key) {
    case 'attendance':
      return 'Photo attendance';
    case 'ta_da':
      return 'Travel & claims';
    case 'live_location':
      return 'Field route';
    case 'dealer_visit':
      return 'Visit report';
    case 'journey_plan':
      return 'Assigned route';
    case 'leave':
      return 'Request leave';
  }

  switch (capability.type) {
    case 'form':
      return 'Smart form';
    case 'checklist':
      return 'Inspection';
    case 'upload':
      return 'Photo / file';
    case 'report':
      return 'View report';
    default:
      return capability.type;
  }
}
