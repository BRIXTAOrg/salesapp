// BRIXTA_CRM_ACCESS_UX_V1_20261101
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/config/field_api.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/brixta_feedback.dart';
import '../../../core/session/app_session_controller.dart';
import '../data/field_records_api.dart';
import 'field_site_screen.dart';
import 'field_conflict_inbox.dart';
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

class _FieldSitesTabState extends State<FieldSitesTab>
    with WidgetsBindingObserver {
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
  int _conflicts = 0; // BRIXTA_FIELD_CONFLICT_INBOX_V1

  // Only the most recent Field request may update the visible list.
  int _pageRequestId = 0;

  FieldList? get _list {
    for (final list in _lists) {
      if (list.key == _listKey) return list;
    }
    return _lists.isEmpty ? null : _lists.first;
  }

  FieldListExperience get _experience =>
      _list?.config.experience.list ?? const FieldListExperience();

  List<FieldLens> get _lenses => _experience.lenses;

  String _initialLens(FieldListExperience experience) =>
      experience.preferNotVisitedDefault &&
          experience.lenses.any((lens) => lens.key == 'not_visited')
      ? 'not_visited'
      : experience.defaultLens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _search.addListener(_onSearch);
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check server access when returning to the app after an admin change.
    if (state == AppLifecycleState.resumed && widget.controller.isOnline) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _search.removeListener(_onSearch);
    _search.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    // BRIXTA_FIELD_REVOKED_CACHE_V1_20261102
    // Never show previously granted modules before online ACL revalidation.
    final session = widget.controller.session;
    final scope = session == null ? '' : FieldSectionQueue.scopeFor(session);
    final cached = (scope.isEmpty || widget.controller.isOnline)
        ? <FieldList>[]
        : await FieldRecordsApi.cachedLists(scope);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _lists = cached;
        _listKey ??= cached.first.key;
        if (!_lensChosen) {
          _lens = _initialLens(cached.first.config.experience.list);
        }
      });
      widget.onListsLoaded?.call(cached);
      await _loadCachedPage();
    }
    await _refresh();
    unawaited(_locate());
  }

  void _onSearch() {
    // Invalidate older results immediately while the user types.
    ++_pageRequestId;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
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

      final previous = _origin;
      final moved =
          previous == null ||
          (fix.latitude - previous.lat).abs() > 0.00025 ||
          (fix.longitude - previous.lng).abs() > 0.00025;

      if (moved) {
        setState(() => _origin = FieldPoint(fix.latitude, fix.longitude));
        await _loadPage();
      }
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
        final lists = await FieldRecordsApi(
          session.accessToken,
          cacheScope: FieldSectionQueue.scopeFor(session),
        ).lists();
        if (!mounted) return;
        setState(() {
          _lists = lists;
          if (lists.every((list) => list.key != _listKey)) {
            // Revoke visible cards immediately when the active module disappears.
            ++_pageRequestId;
            _items = const [];
            _counts = const {};
            _loading = true;
            _listKey = lists.isEmpty ? null : lists.first.key;
            if (lists.isNotEmpty) {
              _lens = _initialLens(lists.first.config.experience.list);
              _lensChosen = false;
            }
          } else if (!_lensChosen && lists.isNotEmpty) {
            final active = lists.firstWhere(
              (list) => list.key == _listKey,
              orElse: () => lists.first,
            );
            _lens = _initialLens(active.config.experience.list);
          }
          _error = null;
        });
        widget.onListsLoaded?.call(lists);
      } catch (error) {
        // Fail closed online: stale cached modules must not survive a failed ACL check.
        if (mounted) {
          ++_pageRequestId;
          setState(() {
            _lists = const [];
            _listKey = null;
            _items = const [];
            _counts = const {};
            _loading = false;
            _error =
                'Cannot verify FIELD access online. Check connection and refresh.';
          });
          widget.onListsLoaded?.call(const []);
        }
        return;
      }
    } else {
      final pending = await FieldSectionQueue.pending(session);
      if (mounted) setState(() => _pending = pending);
    }

    try {
      final conflicts = await FieldSectionQueue.conflicts(session);
      if (mounted) setState(() => _conflicts = conflicts);
    } catch (_) {
      // The site list remains available if conflict metadata cannot load.
    }
    await _loadPage();
  }

  Future<void> _loadCachedPage() async {
    // A live connection requires a fresh server authorization check.
    final session = widget.controller.session;
    if (session == null || widget.controller.isOnline) return;
    final list = _list;
    if (list == null) return;

    final listKey = list.key;
    final lens = _lens;
    final requestId = _pageRequestId;

    final cached = await FieldRecordsApi.cachedRecords(
      listKey,
      lens,
      scope: FieldSectionQueue.scopeFor(session),
    );

    if (cached != null &&
        mounted &&
        requestId == _pageRequestId &&
        _list?.key == listKey &&
        _lens == lens) {
      setState(() {
        _items = cached.items;
        _counts = cached.counts;
        _loading = false;
      });
    }
  }

  Future<void> _loadPage() async {
    final requestId = ++_pageRequestId;
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
      final page = await FieldRecordsApi(
        session.accessToken,
        cacheScope: FieldSectionQueue.scopeFor(session),
      ).records(list.key, lens: _lens, origin: _origin, query: _search.text);
      if (!mounted || requestId != _pageRequestId) return;
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
      if (!mounted || requestId != _pageRequestId) return;
      final forbidden =
          error is FieldApiException &&
          (error.statusCode == 403 || error.statusCode == 404);
      if (forbidden) {
        await FieldRecordsApi.clearCachedRecords(
          list.key,
          _lens,
          scope: FieldSectionQueue.scopeFor(session),
        );
        if (mounted)
          setState(() {
            _items = const [];
            _counts = const {};
            _loading = false;
            _error = 'Your CRM access changed. Pull down to refresh.';
          });
        return;
      }
      // Do not fall back to cached records while online (possibly revoked).
      if (mounted) {
        setState(() {
          _items = const [];
          _counts = const {};
          _loading = false;
          _error = 'Cannot verify FIELD records online. Pull down to retry.';
        });
      }
    }
  }

  void _selectLens(String lens) {
    if (lens == _lens) return;
    ++_pageRequestId;
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
    ++_pageRequestId;
    unawaited(BrixtaFeedback.selection());
    final selected = _lists.firstWhere((item) => item.key == key);
    setState(() {
      _listKey = key;
      _lens = _initialLens(selected.config.experience.list);
      _lensChosen = false;
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
          moduleKey: _list!.key,
          initial: item,
          origin: _origin,
        ),
      ),
    );
    if (mounted) unawaited(_refresh());
  }

  Future<void> _showConflicts() async {
    final session = widget.controller.session;
    if (session == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .78,
        child: FieldConflictInbox(scope: FieldSectionQueue.scopeFor(session)),
      ),
    );
    if (!mounted) return;
    final count = await FieldSectionQueue.conflicts(session);
    if (mounted) setState(() => _conflicts = count);
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
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 130),
          itemCount:
              1 + (_items.isEmpty ? _body(context).length : _items.length),
          itemBuilder: (context, index) {
            if (index > 0) {
              if (_items.isEmpty) return _body(context)[index - 1];
              final item = _items[index - 1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                child: _SiteCard(
                  item: item,
                  experience: _experience,
                  onTap: () => _open(item),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                if (_conflicts > 0) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: OutlinedButton.icon(
                      onPressed: _showConflicts,
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: Text('Review $_conflicts saved Field conflicts'),
                    ),
                  ),
                ],
                if (_lists.length > 1) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Text(
                          'YOUR MODULES',
                          style: AppDesign.sans(
                            size: 11,
                            weight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_lists.length} AVAILABLE',
                          style: AppDesign.sans(
                            size: 11,
                            weight: FontWeight.w600,
                            color: const Color(0xFF64716B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        for (final item in _lists) ...[
                          Semantics(
                            button: true,
                            selected: item.key == list?.key,
                            label: 'Open ${item.title}, ${item.total} records',
                            child: InkWell(
                              key: ValueKey('field-module-${item.key}'),
                              onTap: () => _selectList(item.key),
                              borderRadius: BorderRadius.circular(18),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 174,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  14,
                                ),
                                decoration: BoxDecoration(
                                  color: item.key == list?.key
                                      ? const Color(0xFF245F52)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: item.key == list?.key
                                        ? const Color(0xFF245F52)
                                        : const Color(0xFFD5DDD7),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppDesign.sans(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: item.key == list?.key
                                            ? Colors.white
                                            : const Color(0xFF1F2823),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${item.total} SITES',
                                      style: AppDesign.sans(
                                        size: 11,
                                        weight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                        color: item.key == list?.key
                                            ? const Color(0xFFDCECE5)
                                            : const Color(0xFF67776D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (_experience.search) ...[
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_experience.filterControl == 'pills')
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
                  )
                // BRIXTA_FIELD_FILTER_SHEET_20261102: keep category picker off site cards.
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Semantics(
                      button: true,
                      label: 'Choose which sites to show',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          final selected = await showModalBottomSheet<String>(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            showDragHandle: true,
                            backgroundColor: AppDesign.white,
                            builder: (sheetContext) => DraggableScrollableSheet(
                              expand: false,
                              initialChildSize: 0.60,
                              minChildSize: 0.30,
                              maxChildSize: 0.88,
                              builder: (scrollContext, scrollController) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Show sites',
                                          style: AppDesign.sans(
                                            size: 23,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'Choose a category to filter this dataset.',
                                          style: Theme.of(
                                            scrollContext,
                                          ).textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: ListView.separated(
                                      controller: scrollController,
                                      itemCount: _lenses.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(
                                            height: 1,
                                            indent: 24,
                                            endIndent: 24,
                                          ),
                                      itemBuilder: (itemContext, index) {
                                        final option = _lenses[index];
                                        final active = option.key == _lens;
                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 3,
                                              ),
                                          leading: Icon(
                                            active
                                                ? Icons
                                                      .radio_button_checked_rounded
                                                : Icons
                                                      .radio_button_off_rounded,
                                            color: active
                                                ? const Color(0xFF245F52)
                                                : const Color(0xFF77827C),
                                          ),
                                          title: Text(
                                            option.label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppDesign.sans(
                                              size: 16,
                                              weight: active
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          trailing: Text(
                                            '${_counts[option.key] ?? 0}',
                                            style: AppDesign.sans(
                                              size: 14,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                          selected: active,
                                          onTap: () => Navigator.of(
                                            sheetContext,
                                          ).pop(option.key),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                          if (mounted && selected != null)
                            _selectLens(selected);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: AppDesign.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFD5DDD7)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.filter_list_rounded,
                                color: Color(0xFF245F52),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SHOW SITES',
                                      style: AppDesign.sans(
                                        size: 10,
                                        weight: FontWeight.w700,
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_lenses.firstWhere((item) => item.key == _lens, orElse: () => _lenses.first).label} (${_counts[_lens] ?? 0})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppDesign.sans(
                                        size: 15,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (_lists.isEmpty && !_loading) {
      return [
        _EmptyState(
          title: _error == null
              ? 'Nothing sent to the field yet'
              : 'Could not load',
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
          child: _SiteCard(
            item: item,
            experience: _experience,
            onTap: () => _open(item),
          ),
        ),
    ];
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.item,
    required this.experience,
    required this.onTap,
  });

  final FieldRecordSummary item;
  final FieldListExperience experience;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = formatDistance(item.distanceM);
    final footer = <String>[
      if (experience.showAssignee && item.assignedToMe)
        'Assigned to you'
      else if (experience.showAssignee && item.assigneeName != null)
        'Assigned to ${item.assigneeName}',
      if (experience.showFollowUp && item.followUpAt != null && !item.closed)
        'Follow-up ${formatDay(item.followUpAt)}',
      if (experience.showLastActivity && item.lastVisitAt != null)
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
                    FieldStageChip(
                      label: item.stageLabel,
                      tone: item.stageTone,
                    ),
                    if (item.badgeValue != null &&
                        item.badgeValue!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      FieldStageChip(
                        label: item.badgeValue!,
                        tone: item.badgeTone ?? 'neutral',
                      ),
                    ],
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
                    if (experience.showDistance && distance.isNotEmpty)
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
                if (item.cardValues.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    item.cardValues.map((item) => item.value).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesign.sans(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppDesign.ink,
                    ),
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
