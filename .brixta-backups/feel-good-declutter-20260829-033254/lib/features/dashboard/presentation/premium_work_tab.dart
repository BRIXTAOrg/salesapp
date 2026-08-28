import 'package:flutter/material.dart';

import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/models/mobile_capability.dart';
import '../../../core/session/app_session_controller.dart';

enum _WorkLens { responsibilities, ready, decisions, waiting }

class PremiumWorkTab extends StatefulWidget {
  const PremiumWorkTab({
    super.key,
    required this.controller,
    required this.modules,
    required this.readyWork,
    required this.blockedWork,
    required this.approvals,
    required this.onRefresh,
    required this.onCapabilityTap,
    required this.onReadyTap,
    required this.onApprovalTap,
  });

  final AppSessionController controller;
  final List<MobileCapability> modules;
  final List<Map<String, dynamic>> readyWork;
  final List<Map<String, dynamic>> blockedWork;
  final List<Map<String, dynamic>> approvals;

  final Future<void> Function() onRefresh;

  final ValueChanged<MobileCapability> onCapabilityTap;

  final ValueChanged<Map<String, dynamic>> onReadyTap;

  final ValueChanged<Map<String, dynamic>> onApprovalTap;

  @override
  State<PremiumWorkTab> createState() => _PremiumWorkTabState();
}

class _PremiumWorkTabState extends State<PremiumWorkTab> {
  final TextEditingController _search = TextEditingController();

  late final PageController _pages;

  _WorkLens _lens = _WorkLens.responsibilities;

  @override
  void initState() {
    super.initState();

    _pages = PageController(viewportFraction: .89);

    _search.addListener(_searchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_searchChanged);

    _search.dispose();
    _pages.dispose();

    super.dispose();
  }

  void _searchChanged() {
    setState(() {});

    if (_lens == _WorkLens.responsibilities && _pages.hasClients) {
      _pages.jumpToPage(0);
    }
  }

  String get _query => _search.text.trim().toLowerCase();

  List<MobileCapability> get _visibleModules {
    if (_query.isEmpty) {
      return widget.modules;
    }

    return widget.modules.where((module) {
      final searchable = [
        module.title,
        module.description ?? '',
        module.key,
        module.type,
      ].join(' ').toLowerCase();

      return searchable.contains(_query);
    }).toList();
  }

  List<Map<String, dynamic>> _filterWork(List<Map<String, dynamic>> source) {
    if (_query.isEmpty) {
      return source;
    }

    return source.where((item) {
      final searchable = [
        item['title'],
        item['reason'],
        item['workflowName'],
        item['actionKey'],
      ].whereType<Object>().join(' ').toLowerCase();

      return searchable.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              child: _WorkHeader(
                online: widget.controller.isOnline,
                refreshing: widget.controller.refreshingWorkspace,
              ),
            ),

            const SizedBox(height: 26),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _PremiumSearch(controller: _search),
            ),

            const SizedBox(height: 22),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  _LensChip(
                    label: 'Responsibilities',
                    count: widget.modules.length,
                    selected: _lens == _WorkLens.responsibilities,
                    onTap: () => _selectLens(_WorkLens.responsibilities),
                  ),

                  const SizedBox(width: 8),

                  _LensChip(
                    label: 'Ready',
                    count: widget.readyWork.length,
                    selected: _lens == _WorkLens.ready,
                    onTap: () => _selectLens(_WorkLens.ready),
                  ),

                  if (widget.approvals.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _LensChip(
                      label: 'Decisions',
                      count: widget.approvals.length,
                      selected: _lens == _WorkLens.decisions,
                      onTap: () => _selectLens(_WorkLens.decisions),
                    ),
                  ],

                  if (widget.blockedWork.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _LensChip(
                      label: 'Waiting',
                      count: widget.blockedWork.length,
                      selected: _lens == _WorkLens.waiting,
                      onTap: () => _selectLens(_WorkLens.waiting),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            _buildLens(context),
          ],
        ),
      ),
    );
  }

  void _selectLens(_WorkLens value) {
    setState(() {
      _lens = value;
    });

    if (value == _WorkLens.responsibilities && _pages.hasClients) {
      _pages.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildLens(BuildContext context) {
    switch (_lens) {
      case _WorkLens.responsibilities:
        return _buildResponsibilities(context);

      case _WorkLens.ready:
        return _WorkQueue(
          eyebrow: 'READY WHEN YOU ARE',
          title: 'Pick up your next step.',
          emptyText: 'Nothing is waiting for you right now.',
          items: _filterWork(widget.readyWork),
          mode: _QueueMode.ready,
          onTap: widget.onReadyTap,
        );

      case _WorkLens.decisions:
        return _WorkQueue(
          eyebrow: 'DECISIONS',
          title: 'Only the choices that need you.',
          emptyText: 'No decisions are waiting.',
          items: _filterWork(widget.approvals),
          mode: _QueueMode.decision,
          onTap: widget.onApprovalTap,
        );

      case _WorkLens.waiting:
        return _WorkQueue(
          eyebrow: 'WAITING',
          title: 'Work that is not actionable yet.',
          emptyText: 'Nothing is blocked.',
          items: _filterWork(widget.blockedWork),
          mode: _QueueMode.waiting,
          onTap: null,
        );
    }
  }

  Widget _buildResponsibilities(BuildContext context) {
    final modules = _visibleModules;

    if (modules.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 22),
        child: _EmptyWorkState(
          title: 'No matching Responsibility',
          description: 'Try another search.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EXPLORE YOUR WORK',
                      style: AppDesign.mono(
                        size: 9,
                        color: AppDesign.muted,
                        weight: FontWeight.w600,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose what you want to do next.',
                      style: AppDesign.sans(
                        size: 24,
                        weight: FontWeight.w700,
                        height: 1.08,
                        letterSpacing: -.55,
                      ),
                    ),
                  ],
                ),
              ),
              Text('Swipe', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: SizedBox(
            // BRIXTA_WORK_NAV_FLOW_V2
            height: (MediaQuery.sizeOf(context).height * .64)
                .clamp(470.0, 620.0)
                .toDouble(),
            child: PageView.builder(
              controller: _pages,
              allowImplicitScrolling: true,
              physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
              padEnds: false,
              itemCount: modules.length,
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pages,
                  builder: (context, child) {
                    var page = 0.0;

                    if (_pages.hasClients &&
                        _pages.position.hasContentDimensions) {
                      page = _pages.page ?? 0;
                    }

                    final delta = (page - index).abs().clamp(0.0, 1.0);

                    final scale = 1 - (delta * .035);

                    return Transform.scale(
                      alignment: Alignment.centerLeft,
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _ResponsibilityHeroCard(
                      module: modules[index],
                      onTap: () => widget.onCapabilityTap(modules[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 14),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            '${modules.length} ${modules.length == 1 ? 'Responsibility' : 'Responsibilities'} available',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _WorkHeader extends StatelessWidget {
  const _WorkHeader({required this.online, required this.refreshing});

  final bool online;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your work',
                style: AppDesign.sans(
                  size: 34,
                  weight: FontWeight.w700,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Everything you need — only when you need it.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: AppDesign.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: AppDesign.line),
          ),
          child: Center(
            child: refreshing
                ? const SizedBox(
                    height: 17,
                    width: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    online
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    size: 19,
                    color: online ? AppDesign.green : AppDesign.muted,
                  ),
          ),
        ),
      ],
    );
  }
}

class _PremiumSearch extends StatelessWidget {
  const _PremiumSearch({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(31),
        border: Border.all(color: AppDesign.line.withValues(alpha: .65)),
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search responsibilities',
          prefixIcon: const Icon(Icons.search_rounded, size: 25),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(7),
            child: Container(
              width: 46,
              decoration: const BoxDecoration(
                color: AppDesign.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 19,
                color: AppDesign.white,
              ),
            ),
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 19),
        ),
      ),
    );
  }
}

class _LensChip extends StatelessWidget {
  const _LensChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppDesign.ink : AppDesign.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppDesign.ink : AppDesign.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppDesign.sans(
                  size: 13,
                  color: selected ? AppDesign.white : AppDesign.ink,
                  weight: FontWeight.w500,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: AppDesign.mono(
                    size: 8,
                    color: selected
                        ? AppDesign.white.withValues(alpha: .65)
                        : AppDesign.muted,
                    weight: FontWeight.w600,
                    letterSpacing: .4,
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

class _ResponsibilityHeroCard extends StatelessWidget {
  const _ResponsibilityHeroCard({required this.module, required this.onTap});

  final MobileCapability module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(module);

    final media = _asMap(presentation['media']);

    final mediaUrl = media['url']?.toString();

    final eyebrow = presentation['eyebrow']?.toString() ?? 'RESPONSIBILITY';

    final description =
        presentation['subtitle']?.toString() ??
        module.description ??
        'Open this Responsibility when you are ready.';

    final cta = _asMap(presentation['cta']);

    final ctaLabel = cta['label']?.toString() ?? 'Open responsibility';

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesign.heroRadius),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDesign.heroRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _HeroMedia(url: mediaUrl),

                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x09000000),
                        Color(0x24000000),
                        Color(0xE8000000),
                      ],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),

                Positioned(
                  top: 18,
                  right: 18,
                  child: Container(
                    height: 46,
                    width: 46,
                    decoration: BoxDecoration(
                      color: AppDesign.white.withValues(alpha: .92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      AppIcons.forCapability(module),
                      size: 20,
                      color: AppDesign.ink,
                    ),
                  ),
                ),

                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: AppDesign.mono(
                          size: 8,
                          color: AppDesign.white.withValues(alpha: .72),
                          weight: FontWeight.w600,
                          letterSpacing: 1.7,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        module.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesign.sans(
                          size: 29,
                          color: AppDesign.white,
                          weight: FontWeight.w700,
                          height: 1.02,
                          letterSpacing: -.8,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppDesign.sans(
                          size: 13,
                          color: AppDesign.white.withValues(alpha: .75),
                          height: 1.35,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        height: 58,
                        padding: const EdgeInsets.only(left: 20, right: 7),
                        decoration: BoxDecoration(
                          color: AppDesign.ink.withValues(alpha: .84),
                          borderRadius: BorderRadius.circular(29),
                          border: Border.all(
                            color: AppDesign.white.withValues(alpha: .10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ctaLabel,
                                style: AppDesign.sans(
                                  size: 14,
                                  color: AppDesign.white,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),

                            Container(
                              height: 44,
                              width: 44,
                              decoration: const BoxDecoration(
                                color: AppDesign.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: AppDesign.ink,
                                size: 21,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMedia extends StatelessWidget {
  const _HeroMedia({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/brixta_work_hero.jpg',
      fit: BoxFit.cover,
      cacheWidth: 1000,
      filterQuality: FilterQuality.medium,
    );

    if (url == null || !url!.startsWith('http')) {
      return fallback;
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      cacheWidth: 1000,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, synchronous) {
        if (synchronous || frame != null) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: 1,
            child: child,
          );
        }

        return fallback;
      },
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

enum _QueueMode { ready, decision, waiting }

class _WorkQueue extends StatelessWidget {
  const _WorkQueue({
    required this.eyebrow,
    required this.title,
    required this.emptyText,
    required this.items,
    required this.mode,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String emptyText;
  final List<Map<String, dynamic>> items;
  final _QueueMode mode;
  final ValueChanged<Map<String, dynamic>>? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: AppDesign.mono(
              size: 9,
              color: AppDesign.muted,
              weight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            title,
            style: AppDesign.sans(
              size: 25,
              weight: FontWeight.w700,
              height: 1.08,
              letterSpacing: -.5,
            ),
          ),

          const SizedBox(height: 20),

          if (items.isEmpty)
            _EmptyWorkState(
              title: emptyText,
              description: 'Pull down to refresh.',
            )
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _QueueCard(
                  item: item,
                  mode: mode,
                  onTap: onTap == null ? null : () => onTap!(item),
                ),
              ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.item, required this.mode, this.onTap});

  final Map<String, dynamic> item;
  final _QueueMode mode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? _actionLabel(item);

    final subtitle = mode == _QueueMode.waiting
        ? item['reason']?.toString() ?? 'Waiting for an earlier step'
        : mode == _QueueMode.decision
        ? item['workflowName']?.toString() ?? 'Tap to review'
        : _workSubtitle(item);

    final icon = mode == _QueueMode.decision
        ? Icons.verified_user_outlined
        : mode == _QueueMode.waiting
        ? Icons.schedule_rounded
        : Icons.play_arrow_rounded;

    return Material(
      color: AppDesign.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppDesign.line.withValues(alpha: .7)),
          ),
          child: Row(
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: AppDesign.softGreen,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, size: 21, color: AppDesign.green),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesign.sans(size: 15, weight: FontWeight.w600),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Icon(
                onTap == null
                    ? Icons.lock_outline_rounded
                    : Icons.arrow_forward_rounded,
                size: 20,
                color: AppDesign.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkState extends StatelessWidget {
  const _EmptyWorkState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppDesign.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppDesign.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 28,
            color: AppDesign.green,
          ),
          const SizedBox(height: 15),
          Text(title, style: AppDesign.sans(size: 17, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

Map<String, dynamic> _presentation(MobileCapability module) {
  final app = module.appDefinition;

  final appPresentation = _asMap(app['cardPresentation']);

  if (appPresentation.isNotEmpty) {
    return appPresentation;
  }

  final appConfig = _asMap(app['config']);

  final configPresentation = _asMap(appConfig['cardPresentation']);

  if (configPresentation.isNotEmpty) {
    return configPresentation;
  }

  final direct = _asMap(module.config['cardPresentation']);

  if (direct.isNotEmpty) {
    return direct;
  }

  final kernel = module.kernelDefinition;

  final metadata = _asMap(kernel['metadata']);

  final ui = _asMap(metadata['ui']);

  return _asMap(ui['cardPresentation']);
}

Map<String, dynamic> _asMap(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

String _actionLabel(Map<String, dynamic> item) {
  return item['actionLabel']?.toString() ??
      item['actionKey']?.toString() ??
      'Continue';
}

String _workSubtitle(Map<String, dynamic> item) {
  return item['subtitle']?.toString() ??
      item['reason']?.toString() ??
      'Ready to continue';
}
