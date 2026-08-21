#!/usr/bin/env python3
from pathlib import Path

path = Path('lib/features/dashboard/presentation/employee_dashboard_screen.dart')
if not path.exists():
    raise SystemExit('Run from the BRIXTAOrg/salesapp repository root.')

text = path.read_text(encoding='utf-8')

# Platform Core no longer has /work-items or the old dynamic submission queue.
old_load = '''  Future<void> _loadWork() async {
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
'''
new_load = '''  Future<void> _loadWork() async {
    final session = widget.controller.session;
    if (session == null) return;

    // Platform Core work is represented by Responsibilities + Workflow state,
    // not the removed /work-items endpoint. Flush queued generic records here;
    // the Work tab itself is generated from the refreshed Responsibilities.
    try {
      if (widget.controller.isOnline) {
        await OfflineRecordQueue.flush(session.accessToken);
      }
    } catch (_) {
      // The queue remains durable and will retry later.
    } finally {
      if (mounted) {
        setState(() {
          _workItems = const [];
          _loadingWork = false;
        });
      }
    }
  }
'''
if old_load not in text:
    raise SystemExit('Could not find the expected _loadWork() block. Repository changed; patch manually.')
text = text.replace(old_load, new_load, 1)

old_open = '''  void _openCapability(MobileCapability capability) {
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
'''
new_open = '''  void _openCapability(MobileCapability capability) {
    late final Widget screen;

    // Admin-authored apps always win, even if their key happens to be the
    // name of an old native module such as "attendance". This is the key
    // Platform Core rule: the Responsibility definition owns the employee UI.
    if (capability.hasGeneratedApp) {
      screen = DynamicCapabilityScreen(
        controller: widget.controller,
        capability: capability,
      );
    } else {
      // Temporary compatibility bridge for old tenants that still have
      // pre-Platform-Core native capabilities without an app definition.
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
    }

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _refreshAll());
  }
'''
if old_open not in text:
    raise SystemExit('Could not find the expected _openCapability() block. Repository changed; patch manually.')
text = text.replace(old_open, new_open, 1)

# Imports used only by the removed /work-items loader can now disappear.
text = text.replace("import '../../../core/config/field_api.dart';\n", '')
text = text.replace("import '../../../core/offline/offline_submission_queue.dart';\n", '')
# Keep OfflineAttendanceQueue because the legacy native Attendance bridge may
# still rely on its screen, but this dashboard no longer needs the import.
text = text.replace("import '../../../core/offline/offline_attendance_queue.dart';\n", '')

model_import = "import '../../../core/models/mobile_capability.dart';\n"
record_import = "import '../../../core/offline/offline_record_queue.dart';\n"
if record_import not in text:
    if model_import not in text:
        raise SystemExit('Could not locate mobile_capability import.')
    text = text.replace(model_import, model_import + record_import, 1)

path.write_text(text, encoding='utf-8')
print('✓ employee_dashboard_screen.dart now prefers generated Responsibility apps')
print('✓ removed dead /api/salesApp/work-items dependency')
