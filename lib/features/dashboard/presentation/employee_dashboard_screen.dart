import 'package:flutter/material.dart';

import '../../../core/models/mobile_capability.dart';
import '../../../core/config/field_api.dart';
import '../../../core/services/location/field_tracking_service.dart';
import '../../../core/session/app_session_controller.dart';
import '../../allowances/presentation/allowances_screen.dart';
import '../../attendance/presentation/attendance_screen.dart';
import '../../dynamic/presentation/dynamic_capability_screen.dart';
import '../../tracking/presentation/tracking_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({
    super.key,
    required this.controller,
  });

  final AppSessionController controller;

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  List<Map<String, dynamic>> _workItems = const [];
  bool _loadingWork = true;

  @override
  void initState() {
    super.initState();
    _loadWork();
  }

  Future<void> _loadWork() async {
    try {
      final response = await FieldApi(
        accessToken: widget.controller.session!.accessToken,
      ).getJson('/api/salesApp/work-items');

      final raw = response['workItems'];
      if (raw is List && mounted) {
        setState(() {
          _workItems = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => e['status'] != 'completed' && e['status'] != 'cancelled')
              .toList();
        });
      }
    } catch (_) {
      // The responsibility workspace still works even if assignments are offline.
    } finally {
      if (mounted) setState(() => _loadingWork = false);
    }
  }

  Future<void> _refresh() async {
    await widget.controller.syncNow();
    await _loadWork();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session!;
    final tracker = FieldTrackingService.instance;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(color: Color(0xFF6D7280)),
                        ),
                        Text(
                          session.user.name,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          [
                            session.user.department,
                            session.user.designation,
                          ].whereType<String>().join(' · '),
                          style: const TextStyle(color: Color(0xFF6D7280)),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'logout') widget.controller.logout();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'logout', child: Text('Sign out')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: tracker,
                builder: (_, _) => _TodayCard(
                  tracking: tracker.isTracking,
                  distanceKm: tracker.distanceKm,
                ),
              ),
              if (_loadingWork || _workItems.isNotEmpty) ...[
                const SizedBox(height: 22),
                const _SectionTitle('Today’s assignments'),
                const SizedBox(height: 10),
                if (_loadingWork)
                  const LinearProgressIndicator()
                else
                  ..._workItems.take(4).map(
                        (item) => Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.checklist_rounded),
                            ),
                            title: Text((item['title'] ?? 'Assignment').toString()),
                            subtitle: Text(
                              [
                                if (item['priority'] != null) item['priority'].toString(),
                                if (item['dueAt'] != null) 'Due ${item['dueAt']}',
                              ].join(' · '),
                            ),
                          ),
                        ),
                      ),
              ],
              const SizedBox(height: 22),
              const _SectionTitle('Your work'),
              const SizedBox(height: 4),
              const Text(
                'Only responsibilities assigned by management appear here.',
                style: TextStyle(color: Color(0xFF6D7280)),
              ),
              const SizedBox(height: 12),
              if (session.modules.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No responsibilities assigned yet.'),
                  ),
                )
              else
                ...session.modules.map(
                  (capability) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        minVerticalPadding: 14,
                        leading: CircleAvatar(
                          child: Icon(_iconFor(capability)),
                        ),
                        title: Text(
                          capability.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: capability.description == null
                            ? null
                            : Text(
                                capability.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openCapability(capability),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCapability(MobileCapability capability) {
    Widget screen;

    switch (capability.key) {
      case 'attendance':
        screen = AttendanceScreen(controller: widget.controller);
        break;
      case 'ta_da':
        screen = AllowancesScreen(controller: widget.controller);
        break;
      case 'live_location':
        screen = TrackingScreen(controller: widget.controller);
        break;
      default:
        screen = DynamicCapabilityScreen(
          controller: widget.controller,
          capability: capability,
        );
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  IconData _iconFor(MobileCapability c) {
    switch (c.key) {
      case 'attendance':
        return Icons.how_to_reg_rounded;
      case 'ta_da':
        return Icons.receipt_long_rounded;
      case 'live_location':
        return Icons.my_location_rounded;
      case 'dealer_visit':
        return Icons.storefront_rounded;
      case 'journey_plan':
        return Icons.route_rounded;
      case 'leave':
        return Icons.event_busy_rounded;
    }

    switch (c.type) {
      case 'form':
        return Icons.edit_note_rounded;
      case 'checklist':
        return Icons.checklist_rounded;
      case 'approval_queue':
        return Icons.approval_rounded;
      case 'upload':
        return Icons.cloud_upload_outlined;
      case 'report':
        return Icons.insights_rounded;
      default:
        return Icons.widgets_outlined;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.tracking,
    required this.distanceKm,
  });

  final bool tracking;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFF303541),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TODAY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'field distance',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tracking ? '● Tracking' : 'Not tracking',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
