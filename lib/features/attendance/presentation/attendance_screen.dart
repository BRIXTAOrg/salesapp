import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _checkedIn = false;
  bool _busy = false;
  DateTime? _checkInAt;

  Future<void> _toggleAttendance() async {
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;

    setState(() {
      _checkedIn = !_checkedIn;
      _checkInAt = _checkedIn ? DateTime.now() : null;
      _busy = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _checkedIn
              ? 'Check-in saved locally. Ready to sync.'
              : 'Check-out saved locally. Ready to sync.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                CircleAvatar(
                  radius: 38,
                  backgroundColor: _checkedIn
                      ? const Color(0xFFE7F7ED)
                      : const Color(0xFFFFF3E5),
                  child: Icon(
                    _checkedIn
                        ? Icons.check_circle_outline_rounded
                        : Icons.location_searching_rounded,
                    size: 38,
                    color: _checkedIn
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _checkedIn ? 'Checked in' : 'Not checked in',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _checkedIn
                      ? 'Started at ${_formatTime(_checkInAt!)}'
                      : 'Your attendance has not started today.',
                  style: const TextStyle(color: Color(0xFF737781)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _InfoCard(
            icon: Icons.my_location_rounded,
            title: 'Geofence',
            value: 'ABC Traders • 42 m away',
            detail: 'Allowed radius: 150 m',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            icon: Icons.gps_fixed_rounded,
            title: 'Location accuracy',
            value: 'Good • ±8 m',
            detail: 'Mock value in frontend v0.1',
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _busy ? null : _toggleAttendance,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _checkedIn
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                  ),
            label: Text(_checkedIn ? 'CHECK OUT' : 'CHECK IN'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Frontend v0.1 stores this interaction only in screen state. '
            'The next integration replaces it with the local outbox + GPS gateway.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7A7F8B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFF0F2F5),
            child: Icon(icon, color: const Color(0xFF3B4556)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF747985),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF747985),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
