import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.employeeId,
  });

  final String employeeId;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Map<String, Object?>? _session;
  bool _busy = true;

  bool get _checkedIn =>
      _session != null && _session!['status'] == 'active';

  bool get _completed =>
      _session != null && _session!['status'] == 'completed';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value =
        await AppDatabase.instance.todayWorkSession(widget.employeeId);
    if (!mounted) return;
    setState(() {
      _session = value;
      _busy = false;
    });
  }

  Future<void> _toggleAttendance() async {
    if (_busy || _completed) return;

    setState(() => _busy = true);
    try {
      final next = _checkedIn
          ? await AppDatabase.instance.checkOut(widget.employeeId)
          : await AppDatabase.instance.checkIn(widget.employeeId);

      if (!mounted) return;
      setState(() => _session = next);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next['status'] == 'active'
                ? 'Checked in locally. Tracking session can start here next.'
                : 'Checked out locally. Attendance is queued for sync.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkIn =
        _session?['check_in_at'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  _completed
                      ? Icons.task_alt_rounded
                      : _checkedIn
                          ? Icons.check_circle_outline_rounded
                          : Icons.location_searching_rounded,
                  size: 44,
                ),
                const SizedBox(height: 14),
                Text(
                  _completed
                      ? 'Workday completed'
                      : _checkedIn
                          ? 'Checked in'
                          : 'Not checked in',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                if (checkIn != null) ...[
                  const SizedBox(height: 6),
                  Text('Started: ${_formatTimestamp(checkIn)}'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy || _completed ? null : _toggleAttendance,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _checkedIn
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                  ),
            label: Text(
              _completed
                  ? 'COMPLETED FOR TODAY'
                  : _checkedIn
                      ? 'CHECK OUT'
                      : 'CHECK IN',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Attendance is stored in SQLite first. Duplicate work sessions '
            'for the same employee/day are prevented locally by a unique constraint.',
            textAlign: TextAlign.center,
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
