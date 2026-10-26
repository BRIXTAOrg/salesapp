import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/session/app_session_controller.dart';
import '../../field/presentation/field_site_screen.dart';

/// BRIXTA_PJP_MOBILE_V1: published itinerary only, not legacy Responsibilities.
/// Offline reads use a per-tenant/user/date snapshot. Task writes require server ACK.
class PjpHomeTab extends StatefulWidget {
  const PjpHomeTab({super.key, required this.controller});
  final AppSessionController controller;

  @override
  State<PjpHomeTab> createState() => _PjpHomeTabState();
}

class _PjpHomeTabState extends State<PjpHomeTab> {
  Map<String, dynamic>? _plan;
  bool _loading = true;
  bool _cached = false;
  String? _error;
  bool _submitting = false;

  String get _date {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  String get _cacheKey {
    final session = widget.controller.session;
    return 'pjp:today:${session?.tenant.code ?? "unknown"}:${session?.user.id ?? "unknown"}:$_date';
  }

  List<Map<String, dynamic>> get _stops {
    final raw = _plan?['stops'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final session = widget.controller.session;
    if (session == null) {
      if (mounted) setState(() { _loading = false; _error = 'Sign in to view your plan.'; });
      return;
    }
    try {
      final cached = await AppDatabase.instance.getCache(_cacheKey);
      if (mounted && cached is Map) {
        setState(() { _plan = Map<String, dynamic>.from(cached); _cached = true; _loading = false; });
      }
    } catch (_) { /* Cache is optional; server remains authoritative. */ }
    if (!widget.controller.isOnline) {
      if (mounted) setState(() { _loading = false; _cached = _plan != null; _error = _plan == null ? 'Connect once to receive your itinerary.' : null; });
      return;
    }
    try {
      final body = await FieldApi(accessToken: session.accessToken).getJson('/api/salesApp/pjp/today?date=$_date');
      final raw = body['plan'];
      final next = raw is Map ? Map<String, dynamic>.from(raw) : null;
      if (next != null) await AppDatabase.instance.putCache(_cacheKey, next);
      if (!mounted) return;
      setState(() { _plan = next; _cached = false; _loading = false; _error = null; });
    } catch (error) {
      if (mounted) setState(() { _loading = false; _error = _plan == null ? 'Could not load published PJP: $error' : null; _cached = _plan != null; });
    }
  }

  Future<void> _completeTask(Map<String, dynamic> stop) async {
    if (_submitting || _cached || _plan == null || !widget.controller.isOnline) return;
    final session = widget.controller.session;
    if (session == null) return;
    setState(() => _submitting = true);
    try {
      final body = await FieldApi(accessToken: session.accessToken).postJson('/api/salesApp/pjp/task/complete', {
        'date': _date,
        'stopId': stop['id'],
        'expectedRevision': _plan!['revision'],
      });
      final raw = body['plan'];
      if (raw is Map) {
        final latest = Map<String, dynamic>.from(raw);
        await AppDatabase.instance.putCache(_cacheKey, latest);
        if (mounted) setState(() { _plan = latest; _cached = false; });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not marked complete: $error')));
      }
      await _load();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openStop(Map<String, dynamic> stop) async {
    final id = stop['id']?.toString() ?? '';
    if (id.startsWith('site:')) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FieldSiteScreen(
        controller: widget.controller,
        recordId: id.substring(5),
      )));
      if (mounted) unawaited(_load());
      return;
    }
    final p = stop['location'];
    if (p is Map && p['lat'] is num && p['lng'] is num) {
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${p['lat']},${p['lng']}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openRoute() async {
    final positions = _stops.where((s) => s['location'] is Map).take(8).toList();
    if (positions.isEmpty) return;
    final origin = _plan?['origin'];
    if (origin is! Map) return;
    String coords(dynamic point) => '${point['lat']},${point['lng']}';
    final params = <String, String>{
      'api': '1', 'origin': coords(origin),
      'destination': coords(positions.last['location']), 'travelmode': 'driving',
    };
    if (positions.length > 1) params['waypoints'] = positions.take(positions.length - 1).map((s) => coords(s['location'])).join('|');
    await launchUrl(Uri.https('www.google.com', '/maps/dir/', params), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stops = _stops;
    final complete = stops.where((x) => x['doneAt'] != null).length;
    final taskCount = stops.where((x) => x['type'] == 'task').length;
    final siteCount = stops.length - taskCount;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'GOOD MORNING' : hour < 17 ? 'GOOD AFTERNOON' : 'GOOD EVENING';
    final employeeName = widget.controller.session?.user.name.trim() ?? '';
    final designation = widget.controller.session?.user.designation.trim() ?? '';
    final names = employeeName.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    final initials = names.isEmpty ? 'BR' :
        (names.first.substring(0, 1) + (names.length > 1 ? names.last.substring(0, 1) : '')).toUpperCase();
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(DateTime.now());
    return SafeArea(child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 150), children: [
        // BRIXTA_HOME_GREETING_V3: independently show the employee's name,
        // even before the office publishes a PJP for today.
        if (_plan?['homeGreetingEnabled'] != false) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_plan?['homeGreetingStyle'] == 'hello' ? 'HELLO' : greeting,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800, letterSpacing: 2.4)),
              const SizedBox(height: 9),
              Text(employeeName.isEmpty ? 'Your day' : employeeName,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: 36, fontWeight: FontWeight.w800, height: 1.08,
                  letterSpacing: -1.15)),
              if (designation.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(designation, style: theme.textTheme.bodySmall),
              ],
            ])),
            const SizedBox(width: 12),
            CircleAvatar(radius: 27, backgroundColor: const Color(0xFF1D2321),
              child: Text(initials, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          const SizedBox(height: 26),
        ],
        Text(_plan?['homeTitle']?.toString() ?? "TODAY'S JOURNEY",
          style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 2.1)),
        const SizedBox(height: 8),
        Text(dateLabel, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_cached ? 'Saved copy · reconnect to update progress' : 'Published PJP · pull down to refresh', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 22),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: theme.textTheme.bodyMedium)),
        if (_plan == null && !_loading) const Card(child: Padding(
          padding: EdgeInsets.all(22), child: Text('No journey has been published for you today. Your CRM sites remain available in Field.'),
        )),
        if (_plan != null) ...[
          Row(children: [
            Expanded(child: _Counter(value: '$siteCount', label: 'Site visits')),
            const SizedBox(width: 8),
            Expanded(child: _Counter(value: '$taskCount', label: _plan?['taskLabel']?.toString() ?? 'Tasks')),
            const SizedBox(width: 8),
            Expanded(child: _Counter(value: '$complete', label: 'Tasks done')),
          ]),
          const SizedBox(height: 14),
          if (_plan?['homeShowRouteButton'] != false && stops.any((s) => s['location'] is Map)) SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _openRoute, icon: const Icon(Icons.route), label: const Text('OPEN JOURNEY MAP'),
          )),
          const SizedBox(height: 18),
          Text('YOUR STOPS', style: theme.textTheme.labelLarge),
          const SizedBox(height: 10),
          for (var i = 0; i < stops.length; i++) ...[
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 18, child: Text('${i + 1}')),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(stops[i]['title']?.toString() ?? 'Stop', style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(stops[i]['type'] == 'site' ? 'CRM SITE · ${stops[i]['externalKey'] ?? ''}' : 'TASK', style: theme.textTheme.labelSmall),
                if ((stops[i]['note']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4), Text(stops[i]['note'].toString()),
                ],
                const SizedBox(height: 9),
                if (stops[i]['doneAt'] != null)
                  const Text('Completed', style: TextStyle(color: Colors.green))
                else if (stops[i]['type'] == 'task')
                  TextButton.icon(onPressed: _cached || _submitting ? null : () => _completeTask(stops[i]), icon: const Icon(Icons.check_circle_outline), label: const Text('Mark task done'))
                else Text('Verify or update in Field', style: theme.textTheme.bodySmall),
              ])),
              IconButton(icon: Icon(stops[i]['type'] == 'site' ? Icons.open_in_new : Icons.place_outlined),
                onPressed: () => _openStop(stops[i])),
            ]))),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          Text('Site verification stays in Field. Finishing a task never alters CRM data.', style: theme.textTheme.bodySmall),
        ],
      ]),
    ));
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Theme.of(context).colorScheme.surfaceContainerLow),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ]),
  );
}
