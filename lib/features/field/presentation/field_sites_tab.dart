import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/brixta_feedback.dart';
import '../../../core/session/app_session_controller.dart';
import '../data/field_records_api.dart';
import 'field_site_screen.dart';
import 'field_ui.dart';

// BRIXTA_FIELD_APP_V1 — the field list tab ("Sites"), nearest first.

class FieldSitesTab extends StatefulWidget {
  const FieldSitesTab({
    super.key,
    required this.controller,
    this.onListsLoaded,
  });

  final AppSessionController controller;
  final ValueChanged<List<FieldList>>? onListsLoaded;

  @override
  State<FieldSitesTab> createState() => _FieldSitesTabState();
}

class _Lens {
  const _Lens(this.key, this.label);

  final String key;
  final String label;
}

const _lenses = [
  _Lens('mine', 'Mine'),
  _Lens('todo', 'To visit'),
  _Lens('active', 'In progress'),
  _Lens('followups', 'Follow-ups'),
  _Lens('closed', 'Closed'),
];

class _FieldSitesTabState extends State<FieldSitesTab> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  List<FieldList> _lists = const [];
  String? _listKey;
  // Start on "Mine"; fall back to "To visit" when nothing is assigned.
  String _lens = 'mine';
  bool _lensChosen = false;
  List<FieldRecordSummary> _items = const [];
  Map<String, int> _counts = const {};
  FieldPoint? _origin;
  bool _locating = false;
  bool _loading = true;
  String? _error;
  int _pending = 0;

  FieldList? get _list {
    for (final list in _lists) {
      if (list.key == _listKey) return list;
    }
    return _lists.isEmpty ? null : _lists.first;
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearch);
    unawaited(_start());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final cached = await FieldRecordsApi.cachedLists();
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _lists = cached;
        _listKey ??= cached.first.key;
      });
      widget.onListsLoaded?.call(cached);
      await _loadCachedPage();
    }
    await _refresh();
    unawaited(_locate());
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_loadPage());
    });
  }

  Future<void> _locate() async {
    if (_locating || !mounted) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted && _origin == null) {
        setState(() => _origin = FieldPoint(last.latitude, last.longitude));
        unawaited(_loadPage());
      }
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() => _origin = FieldPoint(fix.latitude, fix.longitude));
      await _loadPage();
    } catch (_) {
      // Distance is a nice-to-have; the list still works by priority.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _refresh() async {
    final session = widget.controller.session;
    if (session == null) return;

    if (widget.controller.isOnline) {
      try {
        final pending = await FieldSectionQueue.flush(session);
        if (mounted) setState(() => _pending = pending);
      } catch (_) {}

      try {
        final lists = await FieldRecordsApi(session.accessToken).lists();
        if (!mounted) return;
        setState(() {
          _lists = lists;
          if (lists.every((list) => list.key != _listKey)) {
            _listKey = lists.isEmpty ? null : lists.first.key;
          }
          _error = null;
        });
        widget.onListsLoaded?.call(lists);
      } catch (error) {
        if (mounted && _lists.isEmpty) setState(() => _error = error.toString());
      }
    } else {
      final pending = await FieldSectionQueue.pending(session);
      if (mounted) setState(() => _pending = pending);
    }

    await _loadPage();
  }

  Future<void> _loadCachedPage() async {
    final list = _list;
    if (list == null) return;
    final cached = await FieldRecordsApi.cachedRecords(list.key, _lens);
    if (cached != null && mounted) {
      setState(() {
        _items = cached.items;
        _counts = cached.counts;
        _loading = false;
      });
    }
  }

  Future<void> _loadPage() async {
    final session = widget.controller.session;
    final list = _list;
    if (session == null || list == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!widget.controller.isOnline) {
      await _loadCachedPage();
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final page = await FieldRecordsApi(session.accessToken).records(
        list.key,
        lens: _lens,
        origin: _origin,
        query: _search.text,
      );
      if (!mounted) return;
      if (!_lensChosen &&
          _lens == 'mine' &&
          page.items.isEmpty &&
          _search.text.trim().isEmpty) {
        setState(() => _lens = 'todo');
        await _loadPage();
        return;
      }
      setState(() {
        _items = page.items;
        _counts = page.counts;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      await _loadCachedPage();
      if (mounted) {
        setState(() {
          _loading = false;
          if (_items.isEmpty) _error = error.toString();
        });
      }
    }
  }

  void _selectLens(String lens) {
    if (lens == _lens) return;
    unawaited(BrixtaFeedback.selection());
    setState(() {
      _lensChosen = true;
      _lens = lens;
      _items = const [];
      _loading = true;
    });
    unawaited(_loadCachedPage().then((_) => _loadPage()));
  }

  void _selectList(String key) {
    if (key == _listKey) return;
    unawaited(BrixtaFeedback.selection());
    setState(() {
      _listKey = key;
      _items = const [];
      _loading = true;
    });
    unawaited(_loadCachedPage().then((_) => _loadPage()));
  }

  Future<void> _open(FieldRecordSummary item) async {
    unawaited(BrixtaFeedback.action());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FieldSiteScreen(
          controller: widget.controller,
          recordId: item.id,
          initial: item,
          origin: _origin,
        ),
      ),
    );
    if (mounted) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final title = list?.title ?? 'Field';

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await _refresh();
          unawaited(_locate());
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 130),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppDesign.sans(
                            size: 34,
                            weight: FontWeight.w700,
                            height: 1,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _origin != null
                              ? 'Nearest first.'
                              : _locating
                              ? 'Finding where you are…'
                              : 'Location is off — sorted by priority.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _SyncBadge(
                    online: widget.controller.isOnline,
                    pending: _pending,
                  ),
                ],
              ),
            ),
            if (_lists.length > 1) ...[
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    for (final item in _lists) ...[
                      FieldPill(
                        label: item.title,
                        selected: item.key == list?.key,
                        onTap: () => _selectList(item.key),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: AppDesign.white,
                  borderRadius: BorderRadius.circular(29),
                  border: Border.all(
                    color: AppDesign.line.withValues(alpha: .65),
                  ),
                ),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search $title',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  for (final lens in _lenses) ...[
                    FieldPill(
                      label: lens.label,
                      count: _counts[lens.key],
                      selected: lens.key == _lens,
                      onTap: () => _selectLens(lens.key),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            ..._body(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (_lists.isEmpty && !_loading) {
      return [
        _EmptyState(
          title: _error == null ? 'Nothing sent to the field yet' : 'Could not load',
          body: _error == null
              ? 'When the office sends a list to the field app, it shows up here.'
              : 'Pull down to try again.',
        ),
      ];
    }

    if (_loading && _items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ];
    }

    if (_items.isEmpty) {
      return [
        _EmptyState(
          title: _search.text.trim().isNotEmpty ? 'No match' : 'All clear',
          body: _search.text.trim().isNotEmpty
              ? 'Try another search.'
              : 'Nothing here right now.',
        ),
      ];
    }

    return [
      for (final item in _items)
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: _SiteCard(item: item, onTap: () => _open(item)),
        ),
    ];
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({required this.item, required this.onTap});

  final FieldRecordSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = formatDistance(item.distanceM);
    final footer = <String>[
      if (item.assignedToMe)
        'Assigned to you'
      else if (item.assigneeName != null)
        'Assigned to ${item.assigneeName}',
      if (item.followUpAt != null && !item.closed)
        'Follow-up ${formatDay(item.followUpAt)}',
      if (item.lastVisitAt != null)
        'Last update ${formatWhen(item.lastVisitAt)}'
            '${item.lastVisitBy != null ? ' · ${item.lastVisitBy}' : ''}',
    ];

    return BrixtaPressScale(
      child: Material(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesign.radius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDesign.radius),
              border: Border.all(color: AppDesign.line.withValues(alpha: .8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FieldStageChip(label: item.stageLabel, tone: item.stageTone),
                    if (item.priority != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'P${item.priority!.round()}',
                        style: AppDesign.mono(
                          size: 9,
                          color: AppDesign.muted,
                          weight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (distance.isNotEmpty)
                      Text(
                        distance,
                        style: AppDesign.sans(
                          size: 20,
                          weight: FontWeight.w700,
                          letterSpacing: -.4,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesign.sans(
                    size: 17,
                    weight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (footer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        item.followUpAt != null && !item.closed
                            ? AppIcons.clock
                            : AppIcons.check,
                        size: 14,
                        color: AppDesign.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          footer.join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.online, required this.pending});

  final bool online;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      constraints: const BoxConstraints(minWidth: 46),
      padding: EdgeInsets.symmetric(horizontal: pending > 0 ? 14 : 0),
      decoration: BoxDecoration(
        color: pending > 0 ? AppDesign.softAmber : AppDesign.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: AppDesign.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            online ? AppIcons.cloud : AppIcons.cloudOff,
            size: 18,
            color: pending > 0
                ? AppDesign.amber
                : online
                ? AppDesign.green
                : AppDesign.muted,
          ),
          if (pending > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$pending waiting',
              style: AppDesign.mono(
                size: 9,
                color: AppDesign.amber,
                weight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
      child: FieldCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.mapPin, color: AppDesign.muted),
            const SizedBox(height: 14),
            Text(
              title,
              style: AppDesign.sans(size: 20, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
