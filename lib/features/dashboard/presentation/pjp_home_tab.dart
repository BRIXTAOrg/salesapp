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
    final employeeName = widget.controller.session?.user.name.trim() ?? '';
    final designation = widget.controller.session?.user.designation.trim() ?? '';
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(DateTime.now());
    return SafeArea(child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 150), children: [
        // BRIXTA_PJP_EXPERIENCE_V5: branded, CMS-configurable employee Home.
        _JourneyHero(
          plan: _plan,
          employeeName: employeeName,
          designation: designation,
          dateLabel: dateLabel,
          stops: stops,
        ),
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


// BRIXTA_PJP_EXPERIENCE_V5: versioned, CMS-controlled mobile Home art direction.
// All content is sourced from the authenticated employee or published PJP snapshot.
class _JourneyHero extends StatelessWidget {
  const _JourneyHero({
    required this.plan,
    required this.employeeName,
    required this.designation,
    required this.dateLabel,
    required this.stops,
  });

  final Map<String, dynamic>? plan;
  final String employeeName;
  final String designation;
  final String dateLabel;
  final List<Map<String, dynamic>> stops;

  @override
  Widget build(BuildContext context) {
    final style = plan?['homeHeroStyle']?.toString() ?? 'aurora';
    final light = style == 'minimal';
    const forest = Color(0xFF1E3431);
    const paper = Color(0xFFF7F7F3);
    final textColor = light ? const Color(0xFF1D2321) : Colors.white;
    final subtitleColor = light ? const Color(0xFF66716D) : const Color(0xFFE0E5E2);
    final today = DateTime.now();
    final greeting = plan?['homeGreetingStyle'] == 'hello'
        ? 'HELLO'
        : today.hour < 12 ? 'GOOD MORNING' : today.hour < 17 ? 'GOOD AFTERNOON' : 'GOOD EVENING';
    final rawName = employeeName.trim();
    final names = rawName.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final initials = names.isEmpty ? 'BR' :
        '${names.first.substring(0, 1)}${names.length > 1 ? names.last.substring(0, 1) : ''}'.toUpperCase();
    final next = stops.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s?['doneAt'] == null, orElse: () => null);
    final completedTasks = stops.where((s) => s['type'] == 'task' && s['doneAt'] != null).length;
    final tasks = stops.where((s) => s['type'] == 'task').length;
    final eyebrow = plan?['homeHeroEyebrow']?.toString().trim();
    final subline = plan?['homeHeroSubline']?.toString().trim();
    final showName = plan?['homeGreetingEnabled'] != false;
    final showNext = plan?['homeShowNextStop'] != false;
    final gradient = style == 'ink'
        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF49635D), Color(0xFF233D36), Color(0xFF172421)])
        : style == 'minimal'
            ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [paper, Color(0xFFEDEFEA)])
            : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                stops: [0.0, 0.44, 0.78, 1],
                colors: [Color(0xFFA4C8D8), Color(0xFFC3A9A2), Color(0xFFBD866B), Color(0xFF172122)]);

    return Container(
      constraints: const BoxConstraints(minHeight: 330),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: gradient,
        border: Border.all(color: light ? const Color(0xFFDDE2DA) : const Color(0x225F6F6C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        if (style == 'aurora') ...[
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: RadialGradient(center: const Alignment(0.25, 0.16), radius: 0.94,
              colors: [const Color(0xEFFF9D3E), const Color(0x80FBC57D), Colors.transparent],
              stops: const [0, 0.48, 1]),
          ))),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              stops: const [0, 0.36, 0.77, 1],
              colors: [const Color(0x330A1820), const Color(0x220A1820), const Color(0x88101618), const Color(0xF1172022)]),
          ))),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 23, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(
                (eyebrow?.isNotEmpty ?? false) ? eyebrow!.toUpperCase() : 'YOUR DAY, YOUR ROUTE',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.6),
              )),
              const SizedBox(width: 9),
              Container(
                width: 45, height: 45,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: light ? forest : const Color(0xEEFFFFFF)),
                child: Text(initials, style: TextStyle(color: light ? Colors.white : forest, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 76),
            if (showName) ...[
              Text(greeting, style: TextStyle(color: textColor.withValues(alpha: .83),
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
              const SizedBox(height: 9),
              Text(rawName.isEmpty ? 'Welcome.' : '$rawName.', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 39, fontWeight: FontWeight.w800,
                  letterSpacing: -1.45, height: 1.04)),
              if (designation.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(designation, style: TextStyle(color: subtitleColor, fontSize: 12)),
              ],
            ] else ...[
              Text(plan?['homeTitle']?.toString() ?? "Today's journey", maxLines: 2,
                style: TextStyle(color: textColor, fontSize: 29, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 12),
            Text((subline?.isNotEmpty ?? false) ? subline! : 'A good day starts with a clear plan.',
              style: TextStyle(color: subtitleColor, fontSize: 13, height: 1.4)),
            const SizedBox(height: 19),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: light ? const Color(0xFFF0F2EE) : const Color(0x260A1514),
                border: Border.all(color: light ? const Color(0xFFDDE1DA) : const Color(0x33FFFFFF)),
              ),
              child: Row(children: [
                Icon(next == null ? Icons.check_circle_outline : Icons.route_outlined,
                  color: textColor, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(showNext && next != null ? 'FIRST PLANNED STOP  ·  $dateLabel' : 'TODAY  ·  $dateLabel',
                    style: TextStyle(color: subtitleColor, fontSize: 10,
                      letterSpacing: 1.1, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(showNext && next != null ? (next['title']?.toString() ?? 'Next visit')
                      : '$completedTasks of $tasks tasks complete',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14)),
                ])),
                Icon(Icons.arrow_forward_rounded, size: 18, color: textColor),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
