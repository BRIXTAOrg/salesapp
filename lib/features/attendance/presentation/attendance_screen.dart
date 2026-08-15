import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
import '../../../core/offline/offline_attendance_queue.dart';
import '../../../core/services/media/local_photo_store.dart';
import '../../../core/session/app_session_controller.dart';
import '../../tracking/presentation/tracking_controller.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.controller,
    required this.trackingController,
  });

  final AppSessionController controller;
  final TrackingController trackingController;

  @override
  State<AttendanceScreen> createState() =>
      _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _picker = ImagePicker();

  Map<String, Object?>? _session;
  Timer? _clock;
  DateTime _now = DateTime.now();
  String? _photoPath;
  bool _busy = true;

  String get employeeId =>
      widget.controller.session!.user.id;

  bool get checkedIn => _session?['status'] == 'active';
  bool get completed =>
      _session?['status'] == 'completed';

  @override
  void initState() {
    super.initState();
    _load();

    _clock = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      },
    );

    if (widget.controller.isOnline) {
      OfflineAttendanceQueue.flush(
        widget.controller.session!.accessToken,
      );
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final value =
        await AppDatabase.instance.todayWorkSession(employeeId);

    if (!mounted) return;

    setState(() {
      _session = value;
      _busy = false;
    });
  }

  Future<void> _capturePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 76,
        maxWidth: 1280,
      );

      if (picked == null) return;

      final persisted = await LocalPhotoStore.persist(
        picked,
        prefix: checkedIn ? 'attendance-out' : 'attendance-in',
      );

      await LocalPhotoStore.delete(_photoPath);

      if (mounted) {
        setState(() => _photoPath = persisted);
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open camera: $error'),
        ),
      );
    }
  }

  Future<void> _submitAttendance() async {
    if (_busy || completed) return;

    final photoPath = _photoPath;

    if (photoPath == null || photoPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Take a quick attendance photo first.',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final fix =
          await widget.trackingController.currentLocation();

      if (fix == null) {
        throw const TrackingUiException(
          'Location is required to record attendance.',
        );
      }

      final kind = checkedIn ? 'out' : 'in';

      if (checkedIn) {
        _session =
            await AppDatabase.instance.checkOut(employeeId);
      } else {
        _session =
            await AppDatabase.instance.checkIn(employeeId);

        // TA/DA travel capture remains independent from attendance.
        await widget.trackingController.ensureAutomatic(
          employeeId,
        );
      }

      final event = <String, dynamic>{
        'kind': kind,
        'latitude': fix.latitude,
        'longitude': fix.longitude,
        'locationName': 'Field work',
        'photoPath': photoPath,
        'createdAt':
            DateTime.now().toUtc().toIso8601String(),
      };

      var sent = false;

      if (widget.controller.isOnline) {
        try {
          await _sendNow(event);
          sent = true;
        } catch (_) {
          await OfflineAttendanceQueue.enqueue(event);
        }
      } else {
        await OfflineAttendanceQueue.enqueue(event);
      }

      if (sent) {
        await LocalPhotoStore.delete(photoPath);
      }

      if (!mounted) return;

      setState(() {
        _photoPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? checkedIn
                    ? 'Checked in.'
                    : 'Attendance recorded.'
                : 'Saved on this phone. It will sync automatically.',
          ),
        ),
      );
    } on TrackingUiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance could not be saved: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendNow(
    Map<String, dynamic> event,
  ) async {
    final api = FieldApi(
      accessToken:
          widget.controller.session!.accessToken,
    );

    final photoPath = event['photoPath']!.toString();
    final photoUrl = await api.uploadPhoto(photoPath);
    final kind = event['kind']!.toString();

    if (kind == 'in') {
      await api.postJson('/api/salesApp/attendance/in', {
        'locationName': event['locationName'],
        'inTimeLatitude': event['latitude'],
        'inTimeLongitude': event['longitude'],
        'inTimeImageUrl': photoUrl,
        'inTimeImageCaptured': true,
      });
    } else {
      await api.patchJson('/api/salesApp/attendance/out', {
        'outTimeLatitude': event['latitude'],
        'outTimeLongitude': event['longitude'],
        'outTimeImageUrl': photoUrl,
        'outTimeImageCaptured': true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = completed
        ? 'Completed'
        : checkedIn
            ? 'Clock out'
            : 'Clock in';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          const SizedBox(height: 5),
          Center(
            child: Text(
              _timeLabel(_now),
              style: const TextStyle(
                color: AppDesign.ink,
                fontSize: 31,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _dateLabel(_now),
              style: const TextStyle(
                color: AppDesign.muted,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 22),
          _PhotoCapture(
            photoPath: _photoPath,
            onTap: completed ? null : _capturePhoto,
          ),
          const SizedBox(height: 21),
          Center(
            child: _ClockButton(
              label: buttonLabel,
              checkedIn: checkedIn,
              completed: completed,
              busy: _busy,
              onPressed:
                  completed || _busy ? null : _submitAttendance,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              completed
                  ? 'Attendance is complete for today.'
                  : _photoPath == null
                      ? 'Take a quick face photo, then tap $buttonLabel.'
                      : 'Photo ready. Tap $buttonLabel when you’re ready.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppDesign.muted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 28),
          _AttendanceFacts(
            session: _session,
            tracking: widget.trackingController,
          ),
          const SizedBox(height: 24),
          const _InfoRow(
            icon: Icons.verified_user_outlined,
            title: 'Photo evidence',
            subtitle:
                'A check-in/check-out photo is stored with the attendance record.',
          ),
          const SizedBox(height: 10),
          const _InfoRow(
            icon: Icons.route_outlined,
            title: 'Travel tracking is separate',
            subtitle:
                'TA/DA travel capture continues automatically and is not controlled by this clock button.',
          ),
        ],
      ),
    );
  }

  static String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0
        ? 12
        : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $suffix';
  }

  static String _dateLabel(DateTime value) {
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

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _PhotoCapture extends StatelessWidget {
  const _PhotoCapture({
    required this.photoPath,
    required this.onTap,
  });

  final String? photoPath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        photoPath != null && File(photoPath!).existsSync();

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(
              side: BorderSide(
                color: AppDesign.line,
                width: 1.5,
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 130,
                height: 130,
                child: hasPhoto
                    ? ClipOval(
                        child: Image.file(
                          File(photoPath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 31,
                          ),
                          SizedBox(height: 7),
                          Text(
                            'Take photo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (hasPhoto)
            Positioned(
              right: -1,
              bottom: 7,
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppDesign.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClockButton extends StatelessWidget {
  const _ClockButton({
    required this.label,
    required this.checkedIn,
    required this.completed,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool checkedIn;
  final bool completed;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? AppDesign.softGray
        : checkedIn
            ? AppDesign.red
            : AppDesign.green;

    final foreground =
        completed ? AppDesign.muted : Colors.white;

    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: completed ? 0 : 2,
      shadowColor: color.withValues(alpha: .22),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 142,
          height: 142,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: foreground,
                  ),
                )
              else
                Icon(
                  checkedIn
                      ? Icons.logout_rounded
                      : Icons.fingerprint_rounded,
                  color: foreground,
                  size: 34,
                ),
              const SizedBox(height: 10),
              Text(
                busy ? 'Saving...' : label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceFacts extends StatelessWidget {
  const _AttendanceFacts({
    required this.session,
    required this.tracking,
  });

  final Map<String, Object?>? session;
  final TrackingController tracking;

  @override
  Widget build(BuildContext context) {
    final inTime = _clock(
      session?['check_in_at']?.toString(),
    );

    final outTime = _clock(
      session?['check_out_at']?.toString(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: _Fact(
                label: 'CLOCK IN',
                value: inTime,
              ),
            ),
            const _FactRule(),
            Expanded(
              child: _Fact(
                label: 'CLOCK OUT',
                value: outTime,
              ),
            ),
            const _FactRule(),
            Expanded(
              child: AnimatedBuilder(
                animation: tracking,
                builder: (_, _) => _Fact(
                  label: 'TRAVEL',
                  value:
                      '${tracking.distanceKm.toStringAsFixed(1)} km',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _clock(String? raw) {
    if (raw == null || raw.isEmpty) return '--';

    try {
      final dt = DateTime.parse(raw).toLocal();
      final hour =
          dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute =
          dt.minute.toString().padLeft(2, '0');
      final suffix = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    } catch (_) {
      return '--';
    }
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppDesign.muted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FactRule extends StatelessWidget {
  const _FactRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      color: AppDesign.line,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesign.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppDesign.softGray,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppDesign.muted,
                    fontSize: 11.5,
                    height: 1.35,
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
