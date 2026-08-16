import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
import '../../../core/offline/offline_attendance_queue.dart';
import '../../../core/services/media/local_photo_store.dart';
import '../../../core/session/app_session_controller.dart';
import '../../tracking/domain/tracking_repository.dart';
import '../../tracking/presentation/tracking_controller.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.controller,
    required this.trackingController,
    this.onReviewTaDa,
  });

  final AppSessionController controller;
  final TrackingController trackingController;
  final VoidCallback? onReviewTaDa;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _picker = ImagePicker();

  Map<String, Object?>? _session;
  Timer? _clock;
  DateTime _now = DateTime.now();
  String? _photoPath;
  CurrentLocationFix? _lastFix;
  bool _busy = true;

  String get employeeId => widget.controller.session!.user.id;
  bool get checkedIn => _session?['status'] == 'active';
  bool get completed => _session?['status'] == 'completed';

  @override
  void initState() {
    super.initState();
    _load();

    _clock = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (mounted) setState(() => _now = DateTime.now());
      },
    );

    if (widget.controller.isOnline) {
      unawaited(
        OfflineAttendanceQueue.flush(
          widget.controller.session!.accessToken,
        ),
      );
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await AppDatabase.instance.todayWorkSession(employeeId);
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
      if (mounted) setState(() => _photoPath = persisted);
    } catch (error) {
      if (!mounted) return;
      _message('Could not open camera: $error');
    }
  }

  Future<void> _submitAttendance() async {
    if (_busy || completed) return;

    final photoPath = _photoPath;
    if (photoPath == null || photoPath.isEmpty) {
      _message('Take a quick face photo first.');
      return;
    }

    setState(() => _busy = true);

    try {
      final fix = await widget.trackingController.currentLocation();
      if (fix == null) {
        throw const TrackingUiException(
          'Location is required to record attendance.',
        );
      }

      final wasCheckedIn = checkedIn;
      final kind = wasCheckedIn ? 'out' : 'in';

      if (wasCheckedIn) {
        _session = await AppDatabase.instance.checkOut(employeeId);
      } else {
        _session = await AppDatabase.instance.checkIn(employeeId);
      }

      final attendanceId = _session!['id']!.toString();
      final event = <String, dynamic>{
        'attendanceId': attendanceId,
        'kind': kind,
        'latitude': fix.latitude,
        'longitude': fix.longitude,
        'locationName': 'Field work',
        'photoPath': photoPath,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
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

      if (sent) await LocalPhotoStore.delete(photoPath);

      // The attendance row is the work-session envelope.
      if (wasCheckedIn) {
        await widget.trackingController.stop();
      } else {
        await widget.trackingController.ensureAutomatic(employeeId);
      }

      await HapticFeedback.lightImpact();

      if (!mounted) return;
      setState(() {
        _photoPath = null;
        _lastFix = fix;
      });

      _message(
        sent
            ? wasCheckedIn
                ? 'Day recorded. Attendance and travel session are closed.'
                : 'Checked in. Your work session is now active.'
            : 'Safe on this phone. It will sync automatically.',
      );
    } on TrackingUiException catch (error) {
      if (mounted) _message(error.message);
    } catch (error) {
      if (mounted) _message('Attendance could not be saved: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendNow(Map<String, dynamic> event) async {
    final api = FieldApi(
      accessToken: widget.controller.session!.accessToken,
    );

    final photoPath = event['photoPath']!.toString();
    final photoUrl = await api.uploadPhoto(photoPath);
    final kind = event['kind']!.toString();
    final attendanceId = event['attendanceId']!.toString();

    if (kind == 'in') {
      await api.postJson('/api/salesApp/attendance/in', {
        'id': attendanceId,
        'locationName': event['locationName'],
        'inTimeLatitude': event['latitude'],
        'inTimeLongitude': event['longitude'],
        'inTimeImageUrl': photoUrl,
        'inTimeImageCaptured': true,
      });
    } else {
      await api.patchJson('/api/salesApp/attendance/out', {
        'id': attendanceId,
        'outTimeLatitude': event['latitude'],
        'outTimeLongitude': event['longitude'],
        'outTimeImageUrl': photoUrl,
        'outTimeImageCaptured': true,
      });
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = completed
        ? 'Day complete'
        : checkedIn
            ? 'Check out'
            : 'Check in';

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(
        padding: AppDesign.pageInset,
        children: [
          const _Eyebrow('ATTENDANCE'),
          const SizedBox(height: 8),
          Text(
            actionLabel,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${_dateLabel(_now)} · ${_timeLabel(_now)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          _PhotoCapture(
            photoPath: _photoPath,
            completed: completed,
            onTap: completed ? null : _capturePhoto,
          ),
          const SizedBox(height: 24),
          _EvidenceRow(
            icon: LucideIcons.map_pin,
            label: 'Location',
            value: _lastFix == null
                ? 'Captured when you submit'
                : '${_lastFix!.latitude.toStringAsFixed(5)}, '
                    '${_lastFix!.longitude.toStringAsFixed(5)}',
          ),
          const Divider(height: 32),
          _EvidenceRow(
            icon: LucideIcons.shield_check,
            label: 'Record keeping',
            value: widget.controller.isOffline
                ? 'Safe on this phone'
                : 'Ready to sync with office',
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: completed || _busy ? null : _submitAttendance,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(actionLabel),
          ),
          if (!completed) ...[
            const SizedBox(height: 8),
            Text(
              _photoPath == null
                  ? 'Take a face photo first. We add time and location automatically.'
                  : 'Photo ready. One tap records the rest.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (completed) ...[
            const SizedBox(height: 48),
            const _CompletedSessionCard(),
            if (widget.onReviewTaDa != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: widget.onReviewTaDa,
                icon: const Icon(LucideIcons.wallet_cards, size: 18),
                label: const Text('Review TA / DA'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _timeLabel(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _dateLabel(DateTime value) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppDesign.muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: .24,
      ),
    );
  }
}

class _PhotoCapture extends StatelessWidget {
  const _PhotoCapture({
    required this.photoPath,
    required this.completed,
    required this.onTap,
  });

  final String? photoPath;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;

    return Material(
      color: AppDesign.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radius),
        side: const BorderSide(color: AppDesign.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        child: SizedBox(
          height: 248,
          child: path != null && path.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppDesign.radius - 1),
                  child: Image.file(
                    File(path),
                    width: double.infinity,
                    height: 248,
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      completed ? LucideIcons.circle_check : LucideIcons.camera,
                      size: 32,
                      color: completed ? AppDesign.green : AppDesign.ink,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      completed ? 'Attendance complete' : 'Take face photo',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppDesign.ink,
                      ),
                    ),
                    if (!completed) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Front camera',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppDesign.muted,
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppDesign.muted),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: .24,
                  color: AppDesign.muted,
                ),
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
      ],
    );
  }
}

class _CompletedSessionCard extends StatelessWidget {
  const _CompletedSessionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.softGreen,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circle_check, size: 20, color: AppDesign.green),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day recorded',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppDesign.ink,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Attendance is closed. Your travel evidence is ready for TA / DA review.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppDesign.muted,
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
