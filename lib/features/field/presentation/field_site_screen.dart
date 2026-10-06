import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_design.dart';
import '../../../core/design/brixta_feedback.dart';
import '../../../core/session/app_session_controller.dart';
import '../data/field_records_api.dart';
import 'field_section_screen.dart';
import 'field_ui.dart';

// BRIXTA_FIELD_APP_V1 — one record (a site): where it is, the steps,
// what came from the import, and everything that happened to it.

class FieldSiteScreen extends StatefulWidget {
  const FieldSiteScreen({
    super.key,
    required this.controller,
    required this.recordId,
    this.initial,
    this.origin,
  });

  final AppSessionController controller;
  final String recordId;
  final FieldRecordSummary? initial;
  final FieldPoint? origin;

  @override
  State<FieldSiteScreen> createState() => _FieldSiteScreenState();
}

class _FieldSiteScreenState extends State<FieldSiteScreen> {
  FieldRecordBundle? _bundle;
  bool _loading = true;
  String? _error;
  bool _showAllInfo = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final cached = await FieldRecordsApi.cachedRecord(widget.recordId);
    if (cached != null && mounted) {
      setState(() {
        _bundle = cached;
        _loading = false;
      });
    }

    final session = widget.controller.session;
    if (session == null || !widget.controller.isOnline) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final fresh = await FieldRecordsApi(session.accessToken).record(widget.recordId);
      if (!mounted) return;
      setState(() {
        _bundle = fresh;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_bundle == null) _error = error.toString();
      });
    }
  }

  FieldPoint? get _point =>
      _bundle?.record.summary.location ?? widget.initial?.location;

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _navigate() async {
    final point = _point;
    if (point == null) return;
    unawaited(BrixtaFeedback.action());
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${point.lat.toStringAsFixed(6)},${point.lng.toStringAsFixed(6)}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) await _copyLocation();
  }

  Future<void> _copyLocation() async {
    final point = _point;
    if (point == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: 'https://www.google.com/maps/search/?api=1&query='
            '${point.lat.toStringAsFixed(6)},${point.lng.toStringAsFixed(6)}',
      ),
    );
    if (mounted) _message('Map link copied.');
  }

  Future<void> _openSection(FieldSection section, FieldRecordDetail record) async {
    final missing = section.requires
        .where((key) => !record.sections.containsKey(key))
        .toList();
    if (missing.isNotEmpty && !record.sections.containsKey(section.key)) {
      final config = _bundle!.list.config;
      final names = missing
          .map((key) => config.section(key)?.title ?? key)
          .join(' and ');
      unawaited(BrixtaFeedback.notice());
      _message('Do $names first.');
      return;
    }

    unawaited(BrixtaFeedback.action());
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => FieldSectionScreen(
          controller: widget.controller,
          recordId: widget.recordId,
          section: section,
          initialValues: record.values,
          sitePoint: record.summary.location,
        ),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final summary = bundle?.record.summary ?? widget.initial;
    final title = summary?.title ?? 'Site';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 48),
          children: [
            if (_point != null) ...[
              _MiniMap(site: _point!, me: widget.origin),
              const SizedBox(height: 18),
            ],
            if (summary != null) _header(context, summary),
            if (_point != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _navigate,
                      icon: const Icon(LucideIcons.navigation, size: 18),
                      label: const Text('NAVIGATE'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyLocation,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('COPY LINK'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            if (bundle == null && _loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (bundle == null)
              FieldCard(
                child: Text(
                  _error ?? 'Open this site once with signal to keep it on your phone.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else ...[
              const FieldEyebrow('Steps'),
              const SizedBox(height: 12),
              for (var i = 0; i < bundle.list.config.sections.length; i++) ...[
                _StepTile(
                  index: i,
                  section: bundle.list.config.sections[i],
                  record: bundle.record,
                  config: bundle.list.config,
                  onTap: () => _openSection(
                    bundle.list.config.sections[i],
                    bundle.record,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (bundle.record.info.isNotEmpty) ...[
                const SizedBox(height: 22),
                const FieldEyebrow('From the import'),
                const SizedBox(height: 12),
                _InfoCard(
                  items: bundle.record.info,
                  showAll: _showAllInfo,
                  onToggle: () => setState(() => _showAllInfo = !_showAllInfo),
                ),
              ],
              if (bundle.timeline.isNotEmpty) ...[
                const SizedBox(height: 28),
                const FieldEyebrow('Timeline'),
                const SizedBox(height: 14),
                _Timeline(items: bundle.timeline),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, FieldRecordSummary summary) {
    final distance = widget.origin != null && summary.location != null
        ? formatDistance(
            _distance(widget.origin!, summary.location!),
          )
        : formatDistance(summary.distanceM);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FieldStageChip(label: summary.stageLabel, tone: summary.stageTone),
            const Spacer(),
            if (distance.isNotEmpty)
              Text(
                '$distance away',
                style: AppDesign.mono(
                  size: 10,
                  color: AppDesign.ink,
                  weight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          summary.title,
          style: AppDesign.sans(
            size: 26,
            weight: FontWeight.w700,
            height: 1.1,
            letterSpacing: -.6,
          ),
        ),
        if (summary.subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            summary.subtitle.join(' · '),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (summary.location != null) ...[
          const SizedBox(height: 8),
          Text(
            '${summary.location!.lat.toStringAsFixed(5)}, '
            '${summary.location!.lng.toStringAsFixed(5)}',
            style: AppDesign.mono(size: 10, letterSpacing: 1),
          ),
        ],
      ],
    );
  }

  double _distance(FieldPoint a, FieldPoint b) {
    final distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      LatLng(a.lat, a.lng),
      LatLng(b.lat, b.lng),
    );
  }
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.site, this.me});

  final FieldPoint site;
  final FieldPoint? me;

  @override
  Widget build(BuildContext context) {
    final sitePoint = LatLng(site.lat, site.lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDesign.radius),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: sitePoint,
            initialZoom: 16.5,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.doubleTapZoom,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.brixta.salesapp',
            ),
            MarkerLayer(
              markers: [
                if (me != null)
                  Marker(
                    point: LatLng(me!.lat, me!.lng),
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppDesign.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppDesign.white, width: 3),
                      ),
                    ),
                  ),
                Marker(
                  point: sitePoint,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppDesign.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppDesign.white, width: 3),
                    ),
                    child: Icon(
                      LucideIcons.map_pin,
                      size: 18,
                      color: AppDesign.white,
                    ),
                  ),
                ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.section,
    required this.record,
    required this.config,
    required this.onTap,
  });

  final int index;
  final FieldSection section;
  final FieldRecordDetail record;
  final FieldListConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = record.sections[section.key];
    final missing = section.requires
        .where((key) => !record.sections.containsKey(key))
        .toList();
    final locked = done == null && missing.isNotEmpty;

    final String detail;
    if (done != null) {
      detail = 'Done ${formatWhen(done.completedAt)}'
          '${done.byName != null ? ' · ${done.byName}' : ''}';
    } else if (locked) {
      detail = 'After ${missing.map((key) => config.section(key)?.title ?? key).join(', ')}';
    } else {
      detail = section.hint ?? '${section.fields.length} questions';
    }

    return BrixtaPressScale(
      child: Material(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppDesign.line.withValues(alpha: .8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: done != null
                        ? AppDesign.green
                        : locked
                        ? AppDesign.softGray
                        : AppDesign.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done != null
                          ? AppDesign.green
                          : locked
                          ? AppDesign.softGray
                          : AppDesign.ink,
                      width: 1.4,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: done != null
                      ? const Icon(Icons.check_rounded, size: 20, color: AppDesign.white)
                      : locked
                      ? const Icon(Icons.lock_outline_rounded, size: 16, color: AppDesign.muted)
                      : Text(
                          '${index + 1}',
                          style: AppDesign.mono(
                            size: 11,
                            color: AppDesign.ink,
                            weight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: AppDesign.sans(
                          size: 16,
                          weight: FontWeight.w600,
                          color: locked ? AppDesign.muted : AppDesign.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  done != null ? Icons.edit_outlined : Icons.chevron_right_rounded,
                  size: 20,
                  color: AppDesign.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.items,
    required this.showAll,
    required this.onToggle,
  });

  final List<FieldInfoItem> items;
  final bool showAll;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visible = showAll ? items : items.take(6).toList();
    return FieldCard(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == visible.length - 1 && items.length <= 6
                    ? null
                    : const Border(bottom: BorderSide(color: AppDesign.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      visible[i].label,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Text(
                      visible[i].value,
                      style: AppDesign.sans(size: 14, weight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          if (items.length > 6)
            TextButton(
              onPressed: onToggle,
              child: Text(showAll ? 'SHOW LESS' : 'SHOW ALL ${items.length}'),
            ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.items});

  final List<FieldTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: i == 0 ? AppDesign.ink : AppDesign.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppDesign.ink, width: 1.4),
                        ),
                      ),
                      if (i < items.length - 1)
                        Expanded(
                          child: Container(width: 1.4, color: AppDesign.line),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].title,
                          style: AppDesign.sans(size: 15, weight: FontWeight.w600),
                        ),
                        if (items[i].detail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            items[i].detail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${formatWhen(items[i].at)}'
                          '${items[i].by != null ? ' · ${items[i].by}' : ''}',
                          style: AppDesign.mono(size: 9, letterSpacing: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
