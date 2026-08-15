import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/config/field_api.dart';
import '../../../core/services/location/field_tracking_service.dart';
import '../../../core/session/app_session_controller.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.controller,
  });

  final AppSessionController controller;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, Object?>? _session;
  bool _busy = true;

  String get employeeId => widget.controller.session!.user.id;
  bool get _checkedIn => _session != null && _session!['status'] == 'active';
  bool get _completed => _session != null && _session!['status'] == 'completed';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await AppDatabase.instance.todayWorkSession(employeeId);
    if (!mounted) return;
    setState(() {
      _session = value;
      _busy = false;
    });
  }

  Future<void> _toggleAttendance() async {
    if (_busy || _completed) return;
    setState(() => _busy = true);

    final tracker = FieldTrackingService.instance;
    final session = widget.controller.session!;

    try {
      final position = await tracker.currentPosition();
      final api = FieldApi(accessToken: session.accessToken);

      if (_checkedIn) {
        final next = await AppDatabase.instance.checkOut(employeeId);

        try {
          await api.patchJson('/api/salesApp/attendance/out', {
            'outTimeLatitude': position.latitude,
            'outTimeLongitude': position.longitude,
            'outTimeImageCaptured': false,
          });
        } catch (_) {
          // Local attendance remains queued if the network is unavailable.
        }

        await tracker.stop();
        if (mounted) setState(() => _session = next);
      } else {
        final next = await AppDatabase.instance.checkIn(employeeId);

        try {
          await api.postJson('/api/salesApp/attendance/in', {
            'locationName': 'Field location',
            'inTimeLatitude': position.latitude,
            'inTimeLongitude': position.longitude,
            'inTimeImageCaptured': false,
          });
        } catch (_) {
          // Local attendance remains available even when offline.
        }

        await tracker.start(
          employeeId: employeeId,
          accessToken: session.accessToken,
        );

        if (mounted) setState(() => _session = next);
      }
    } on TrackingException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkIn = _session?['check_in_at'] as String?;
    final tracker = FieldTrackingService.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _checkedIn ? const Color(0xFFEAF7EF) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  _completed
                      ? Icons.task_alt_rounded
                      : _checkedIn
                          ? Icons.check_circle_rounded
                          : Icons.location_searching_rounded,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  _completed
                      ? 'Workday completed'
                      : _checkedIn
                          ? 'You’re checked in'
                          : 'Ready to start?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 23,
                  ),
                ),
                if (checkIn != null) ...[
                  const SizedBox(height: 6),
                  Text('Started ${_formatTimestamp(checkIn)}'),
                ],
                if (_checkedIn) ...[
                  const SizedBox(height: 8),
                  ListenableBuilder(
                    listenable: tracker,
                    builder: (_, _) => Text(
                      '${tracker.distanceKm.toStringAsFixed(1)} km tracked today',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy || _completed ? null : _toggleAttendance,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_checkedIn ? Icons.logout_rounded : Icons.login_rounded),
            label: Text(
              _completed
                  ? 'DONE FOR TODAY'
                  : _checkedIn
                      ? 'CHECK OUT'
                      : 'CHECK IN',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _checkedIn
                ? 'Field tracking runs while you are checked in so distance and movement are captured automatically.'
                : 'Checking in uses your current location and starts field tracking.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6D7280)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String value) {
    final time = DateTime.parse(value).toLocal();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
