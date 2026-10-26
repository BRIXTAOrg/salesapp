import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session/app_session_controller.dart';

/// BRIXTA_PJP_WORK_V3
/// Work mirrors the employee's published PJP tasks. Completion is confirmed
/// by the authenticated server and does not change CRM site verification.
/// The legacy Responsibility carousel below this board is left intact.
class PjpWorkTasks extends StatefulWidget {
  const PjpWorkTasks({super.key, required this.controller, this.query = ''});

  final AppSessionController controller;
  final String query;

  @override
  State<PjpWorkTasks> createState() => _PjpWorkTasksState();
}

class _PjpWorkTasksState extends State<PjpWorkTasks> {
  Map<String, dynamic>? _plan;
  bool _loading = true;
  bool _cached = false;
  bool _saving = false;
  bool _expanded = false;
  String? _error;

  String get _date {
    final now = DateTime.now();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  String get _cacheKey {
    final session = widget.controller.session;
    return 'pjp:today:${session?.tenant.code ?? "unknown"}:${session?.user.id ?? "unknown"}:$_date';
  }

  List<Map<String, dynamic>> get _tasks {
    final raw = _plan?['stops'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['type'] == 'task')
        .toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final session = widget.controller.session;
    if (session == null) {
      if (mounted) setState(() { _loading = false; _error = 'Sign in to see your tasks.'; });
      return;
    }
    try {
      final cached = await AppDatabase.instance.getCache(_cacheKey);
      if (mounted && cached is Map) {
        setState(() {
          _plan = Map<String, dynamic>.from(cached);
          _cached = true;
          _loading = false;
        });
      }
    } catch (_) { /* Cached reading is optional. */ }

    if (!widget.controller.isOnline) {
      if (mounted) setState(() { _loading = false; _cached = _plan != null; });
      return;
    }
    try {
      final result = await FieldApi(accessToken: session.accessToken)
          .getJson('/api/salesApp/pjp/today?date=$_date');
      final raw = result['plan'];
      final next = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (next != null) await AppDatabase.instance.putCache(_cacheKey, next);
      if (mounted) {
        setState(() { _plan = next; _cached = false; _loading = false; _error = null; });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _plan == null ? 'Cannot load your published tasks right now.' : null;
          _cached = _plan != null;
        });
      }
    }
  }

  Future<void> _complete(Map<String, dynamic> task) async {
    if (_saving || _cached || !widget.controller.isOnline || _plan == null) return;
    final session = widget.controller.session;
    if (session == null) return;
    setState(() => _saving = true);
    try {
      final response = await FieldApi(accessToken: session.accessToken)
          .postJson('/api/salesApp/pjp/task/complete', {
        'date': _date,
        'stopId': task['id'],
        'expectedRevision': _plan!['revision'],
      });
      final raw = response['plan'];
      if (raw is Map) {
        final next = Map<String, dynamic>.from(raw);
        await AppDatabase.instance.putCache(_cacheKey, next);
        if (mounted) setState(() { _plan = next; _cached = false; });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete the task: $error')),
        );
      }
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _navigate(Map<String, dynamic> task) async {
    final point = task['location'];
    if (point is! Map) return;
    final lat = point['lat'];
    final lng = point['lng'];
    if (lat is! num || lng is! num || lat.abs() > 90 || lng.abs() > 180) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1', 'query': '$lat,$lng',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null || plan['workTasksEnabled'] == false) {
      // No assigned tasks: keep the original, visually rich Work screen.
      return const SizedBox.shrink();
    }
    final all = _tasks;
    if (all.isEmpty) return const SizedBox.shrink();
    final needle = widget.query.trim().toLowerCase();
    final filtered = needle.isEmpty ? all : all.where((task) {
      return [task['title'], task['note']]
          .whereType<Object>().join(' ').toLowerCase().contains(needle);
    }).toList();
    final done = all.where((task) => task['doneAt'] != null).length;
    final display = needle.isNotEmpty || _expanded ? filtered : filtered.take(3).toList();
    final colors = Theme.of(context).colorScheme;
    final title = (plan['workTasksTitle']?.toString().trim().isNotEmpty ?? false)
        ? plan['workTasksTitle'].toString()
        : 'Your scheduled tasks';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.65)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.route_outlined, color: Color(0xFF28776E), size: 18),
            const SizedBox(width: 8),
            Text('TODAY\'S PJP', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2,
              color: colors.onSurfaceVariant,
            )),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh scheduled tasks',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              onPressed: _saving || _loading ? null : _load,
            ),
          ]),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.7,
          )),
          const SizedBox(height: 6),
          Text('$done of ${all.length} completed${_cached ? ' · Saved offline' : ''}',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: all.isEmpty ? 0.0 : done / all.length,
            minHeight: 5, backgroundColor: colors.surfaceContainerHighest,
            color: const Color(0xFF28776E),
          )),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: colors.error, fontSize: 12)),
          ),
          if (filtered.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No matching PJP tasks.', style: TextStyle(color: colors.onSurfaceVariant)))
          else
            for (var index = 0; index < display.length; index++) ...[
              _taskCard(display[index], colors),
              if (index < display.length - 1) const SizedBox(height: 10),
            ],
          if (needle.isEmpty && all.length > 3) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded ? 'Show fewer tasks' : 'See all ${all.length} tasks'),
            ),
          ],
          if (_cached) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Reconnect before completing a task.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
          ),
        ]),
      ),
    );
  }

  Widget _taskCard(Map<String, dynamic> task, ColorScheme colors) {
    final completed = task['doneAt'] != null;
    final hasLocation = task['location'] is Map;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: const Color(0xFF28776E), size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(task['title']?.toString() ?? 'Task',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              decoration: completed ? TextDecoration.lineThrough : null)),
          if ((task['note']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(task['note'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
          ],
          const SizedBox(height: 8),
          if (completed)
            const Text('Completed', style: TextStyle(
              fontSize: 12, color: Color(0xFF28776E), fontWeight: FontWeight.w700))
          else
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: _saving || _cached ? null : () => _complete(task),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Mark done'),
            ),
        ])),
        if (hasLocation) IconButton(
          tooltip: 'Open task location',
          icon: const Icon(Icons.near_me_outlined, size: 20),
          onPressed: () => _navigate(task),
        ),
      ]),
    );
  }
}
