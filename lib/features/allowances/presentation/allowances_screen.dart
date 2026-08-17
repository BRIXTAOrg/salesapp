import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
import '../../../core/services/media/local_photo_store.dart';
import '../../../core/session/app_session_controller.dart';
import '../../tracking/domain/tracking_repository.dart';
import '../../tracking/presentation/tracking_controller.dart';

class AllowancesScreen extends StatefulWidget {
  const AllowancesScreen({
    super.key,
    required this.controller,
    required this.trackingController,
  });

  final AppSessionController controller;
  final TrackingController trackingController;

  @override
  State<AllowancesScreen> createState() => _AllowancesScreenState();
}

class _AllowancesScreenState extends State<AllowancesScreen> {
  bool _loading = true;
  bool _submitting = false;
  List<Map<String, dynamic>> _claims = const [];
  List<RoutePoint> _route = const [];
  Map<String, Object?>? _workSession;

  bool get _sessionClosed => _workSession?['status'] == 'completed';
  bool get _sessionActive => _workSession?['status'] == 'active';

  Map<String, dynamic>? get _todayClaim {
    final today = _dateKey(DateTime.now());
    for (final claim in _claims) {
      final raw = claim['billDate'] ?? claim['bill_date'];
      if (raw != null && raw.toString().startsWith(today)) return claim;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);

    List<Map<String, dynamic>> claims = const [];
    List<RoutePoint> route = const [];

    try {
      final response = await FieldApi(
        accessToken: widget.controller.session!.accessToken,
      ).getJson('/api/salesApp/tada-bills');

      final raw = response['data'];
      if (raw is List) {
        claims = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

    route = await widget.trackingController.todayRoute();
    final workSession = await AppDatabase.instance.todayWorkSession(
      widget.controller.session!.user.id,
    );

    if (!mounted) return;
    setState(() {
      _claims = claims;
      _route = route;
      _workSession = workSession;
      _loading = false;
    });
  }

  Future<void> _reviewClaim() async {
    final existing = _todayClaim;
    if (existing != null) {
      final status = (existing['status'] ?? 'PENDING').toString().toUpperCase();
      _message('Today’s claim is already $status.');
      return;
    }

    if (!_sessionClosed) {
      _message(
        _sessionActive
            ? 'Check out first. We will freeze today’s travel evidence before submission.'
            : 'Start and complete attendance before submitting today’s TA / DA.',
      );
      return;
    }

    final draft = await showModalBottomSheet<_ClaimDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ClaimSheet(
        distanceKm: widget.trackingController.distanceKm,
        routePointCount: _route.length,
      ),
    );

    if (draft == null) return;
    await _submitClaim(draft);
  }

  Future<void> _submitClaim(_ClaimDraft draft) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final api = FieldApi(
        accessToken: widget.controller.session!.accessToken,
      );

      final receiptUrls = <String>[];
      for (final path in draft.receiptPaths) {
        receiptUrls.add(await api.uploadPhoto(path));
      }

      final date = _dateKey(DateTime.now());
      final distanceKm = widget.trackingController.distanceKm;

      await api.postJson('/api/salesApp/tada-bills', {
        'billDate': date,
        'fromDate': date,
        'toDate': date,
        'dailyAllowance': draft.dailyAllowance,
        'totalCost': draft.totalCost,
        'remarks': draft.remarks,
        'status': 'PENDING',
        'items': [
          {
            'fromLocation': 'Session start',
            'toLocation': 'Session end',
            'distanceTravelled': distanceKm.toStringAsFixed(2),
            'transportFare': draft.transportFare,
            'lodgingFare': draft.lodgingFare,
            'foodingFare': draft.foodingFare,
            'localConveyance': draft.localConveyance,
            'outOfPocketPaid': draft.outOfPocket,
            'totalBillsAdded': receiptUrls.length,
            'billPhotoUrls': receiptUrls,
            'remarks': draft.remarks,
          },
        ],
      });

      for (final path in draft.receiptPaths) {
        await LocalPhotoStore.delete(path);
      }

      await HapticFeedback.lightImpact();
      if (mounted) _message('Claim submitted for review.');
      await _load();
    } catch (error) {
      if (mounted) {
        _message('Claim could not be submitted yet: $error');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  int get _pendingClaims => _claims.where((claim) {
        return (claim['status'] ?? '')
                .toString()
                .toUpperCase() ==
            'PENDING';
      }).length;

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final distance = widget.trackingController.distanceKm;

    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            children: [
              Text('TA / DA', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(
                'Your travel evidence, expenses and claim status in one place.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              const _SectionLabel('TODAY’S TRAVEL'),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: widget.trackingController,
                builder: (_, _) => _TravelSummary(
                  distanceKm: widget.trackingController.distanceKm,
                  active: widget.trackingController.active,
                  sessionClosed: _sessionClosed,
                  routePointCount: _route.length,
                ),
              ),
              const SizedBox(height: 16),
              _RouteEvidenceCard(
                points: _route,
                offline: widget.controller.isOffline,
              ),
              const SizedBox(height: 48),
              const _SectionLabel('CLAIM'),
              const SizedBox(height: 16),
              _ClaimReadiness(
                sessionClosed: _sessionClosed,
                sessionActive: _sessionActive,
                distanceKm: distance,
                routePointCount: _route.length,
                pendingClaims: _pendingClaims,
                todayClaimStatus: _todayClaim?['status']?.toString(),
                busy: _submitting,
                onReview: _reviewClaim,
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  const Expanded(child: _SectionLabel('HISTORY')),
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_loading && _claims.isEmpty)
                const _NoClaims()
              else
                for (var i = 0; i < _claims.length; i++) ...[
                  _ClaimRow(claim: _claims[i]),
                  if (i != _claims.length - 1) const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelSummary extends StatelessWidget {
  const _TravelSummary({
    required this.distanceKm,
    required this.active,
    required this.sessionClosed,
    required this.routePointCount,
  });

  final double distanceKm;
  final bool active;
  final bool sessionClosed;
  final int routePointCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.route, size: 20, color: AppDesign.muted),
              const Spacer(),
              _StatusTag(
                label: sessionClosed
                    ? 'SESSION CLOSED'
                    : active
                        ? 'RECORDING'
                        : 'STANDBY',
                color: sessionClosed
                    ? AppDesign.softGreen
                    : active
                        ? AppDesign.softBlue
                        : AppDesign.softGray,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '${distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -.64,
              color: AppDesign.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$routePointCount route ${routePointCount == 1 ? 'point' : 'points'} retained as evidence',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RouteEvidenceCard extends StatelessWidget {
  const _RouteEvidenceCard({required this.points, required this.offline});

  final List<RoutePoint> points;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesign.surface,
          border: Border.all(color: AppDesign.line),
          borderRadius: BorderRadius.circular(AppDesign.radius),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.map, size: 20, color: AppDesign.muted),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Your route map will appear here after travel points are recorded.',
                style: TextStyle(fontSize: 14, height: 1.5, color: AppDesign.muted),
              ),
            ),
          ],
        ),
      );
    }

    final coordinates = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDesign.radius - 1),
            ),
            child: SizedBox(
              height: 240,
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.coordinates(
                    coordinates: coordinates,
                    padding: const EdgeInsets.all(32),
                    maxZoom: 16,
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.salesapp',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: coordinates,
                        strokeWidth: 4,
                        color: AppDesign.primary,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: coordinates.first,
                        width: 24,
                        height: 24,
                        child: const _RouteMarker(
                          fill: AppDesign.surface,
                          border: AppDesign.primary,
                        ),
                      ),
                      Marker(
                        point: coordinates.last,
                        width: 24,
                        height: 24,
                        child: const _RouteMarker(
                          fill: AppDesign.primary,
                          border: AppDesign.surface,
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
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Route evidence',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppDesign.ink,
                        ),
                      ),
                    ),
                    Text(
                      offline ? 'Map tiles need internet' : 'OpenStreetMap',
                      style: const TextStyle(fontSize: 11, color: AppDesign.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_time(points.first.recordedAt)} → ${_time(points.last.recordedAt)} · ${points.length} points',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _time(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _RouteMarker extends StatelessWidget {
  const _RouteMarker({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 3),
        ),
      ),
    );
  }
}

class _ClaimReadiness extends StatelessWidget {
  const _ClaimReadiness({
    required this.sessionClosed,
    required this.sessionActive,
    required this.distanceKm,
    required this.routePointCount,
    required this.pendingClaims,
    required this.todayClaimStatus,
    required this.busy,
    required this.onReview,
  });

  final bool sessionClosed;
  final bool sessionActive;
  final double distanceKm;
  final int routePointCount;
  final int pendingClaims;
  final String? todayClaimStatus;
  final bool busy;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final normalizedTodayStatus = todayClaimStatus?.toUpperCase();
    final title = normalizedTodayStatus != null
        ? 'Today’s claim is $normalizedTodayStatus'
        : sessionClosed
            ? 'Today’s claim is ready to review'
            : sessionActive
                ? 'We are still recording today'
                : pendingClaims > 0
                    ? '$pendingClaims earlier claim${pendingClaims == 1 ? '' : 's'} under review'
                    : 'TA / DA starts with attendance';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppDesign.ink,
            ),
          ),
          const SizedBox(height: 16),
          _ClaimFact(label: 'Travel evidence', value: '${distanceKm.toStringAsFixed(1)} km'),
          const SizedBox(height: 8),
          _ClaimFact(label: 'Route points', value: '$routePointCount'),
          const SizedBox(height: 8),
          _ClaimFact(
            label: 'Session',
            value: sessionClosed
                ? 'Closed'
                : sessionActive
                    ? 'Active'
                    : 'Not started',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy || normalizedTodayStatus != null ? null : onReview,
            child: Text(
              normalizedTodayStatus != null
                  ? 'Already submitted'
                  : sessionClosed
                      ? 'Review claim'
                      : 'Review after check-out',
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimFact extends StatelessWidget {
  const _ClaimFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppDesign.ink,
          ),
        ),
      ],
    );
  }
}

class _NoClaims extends StatelessWidget {
  const _NoClaims();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Text(
        'No submitted claims yet. Today’s evidence stays here until you review it.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({required this.claim});

  final Map<String, dynamic> claim;

  @override
  Widget build(BuildContext context) {
    final status = (claim['status'] ?? 'PENDING').toString().toUpperCase();
    final amount = claim['totalCost'] ?? claim['total_cost'] ?? '0';
    final date = claim['billDate'] ?? claim['bill_date'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.receipt_text, size: 20, color: AppDesign.muted),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹$amount',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('$date · $status', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const Icon(LucideIcons.chevron_right, size: 18, color: AppDesign.muted),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDesign.controlRadius),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
          color: AppDesign.ink,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: .24,
        color: AppDesign.muted,
      ),
    );
  }
}

class _ClaimDraft {
  const _ClaimDraft({
    required this.transportFare,
    required this.lodgingFare,
    required this.foodingFare,
    required this.localConveyance,
    required this.outOfPocket,
    required this.dailyAllowance,
    required this.remarks,
    required this.receiptPaths,
  });

  final double transportFare;
  final double lodgingFare;
  final double foodingFare;
  final double localConveyance;
  final double outOfPocket;
  final double dailyAllowance;
  final String remarks;
  final List<String> receiptPaths;

  double get totalCost =>
      transportFare +
      lodgingFare +
      foodingFare +
      localConveyance +
      outOfPocket +
      dailyAllowance;
}

class _ClaimSheet extends StatefulWidget {
  const _ClaimSheet({
    required this.distanceKm,
    required this.routePointCount,
  });

  final double distanceKm;
  final int routePointCount;

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final _picker = ImagePicker();
  final transport = TextEditingController(text: '0');
  final lodging = TextEditingController(text: '0');
  final food = TextEditingController(text: '0');
  final local = TextEditingController(text: '0');
  final outOfPocket = TextEditingController(text: '0');
  final daily = TextEditingController(text: '0');
  final remarks = TextEditingController();
  final receiptPaths = <String>[];

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  double get _total =>
      _number(transport) +
      _number(lodging) +
      _number(food) +
      _number(local) +
      _number(outOfPocket) +
      _number(daily);

  @override
  void dispose() {
    for (final controller in [
      transport,
      lodging,
      food,
      local,
      outOfPocket,
      daily,
      remarks,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _addReceipt() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1440,
    );
    if (picked == null) return;

    final path = await LocalPhotoStore.persist(
      picked,
      prefix: 'tada-receipt',
    );
    if (mounted) setState(() => receiptPaths.add(path));
  }

  void _finish() {
    Navigator.of(context).pop(
      _ClaimDraft(
        transportFare: _number(transport),
        lodgingFare: _number(lodging),
        foodingFare: _number(food),
        localConveyance: _number(local),
        outOfPocket: _number(outOfPocket),
        dailyAllowance: _number(daily),
        remarks: remarks.text.trim(),
        receiptPaths: List<String>.from(receiptPaths),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review claim', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Travel is locked from today’s completed work session. Add only expenses you want to claim.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            _LockedEvidence(
              distanceKm: widget.distanceKm,
              routePointCount: widget.routePointCount,
            ),
            const SizedBox(height: 32),
            const _SectionLabel('EXPENSES'),
            const SizedBox(height: 16),
            _MoneyField(label: 'Daily allowance', controller: daily, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            _MoneyField(label: 'Food', controller: food, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            _MoneyField(label: 'Local conveyance', controller: local, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            _MoneyField(label: 'Transport fare', controller: transport, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            _MoneyField(label: 'Lodging', controller: lodging, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            _MoneyField(label: 'Other out-of-pocket', controller: outOfPocket, onChanged: (_) => setState(() {})),
            const SizedBox(height: 32),
            const _SectionLabel('RECEIPTS'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _addReceipt,
              icon: const Icon(LucideIcons.camera, size: 18),
              label: Text(
                receiptPaths.isEmpty
                    ? 'Add receipt photo'
                    : 'Add another receipt (${receiptPaths.length})',
              ),
            ),
            if (receiptPaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: receiptPaths.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesign.controlRadius),
                    child: Image.file(
                      File(receiptPaths[index]),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const _SectionLabel('NOTE'),
            const SizedBox(height: 8),
            TextField(
              controller: remarks,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Optional note'),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Estimated claim',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '₹${_total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppDesign.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _finish,
              child: const Text('Submit for review'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedEvidence extends StatelessWidget {
  const _LockedEvidence({required this.distanceKm, required this.routePointCount});

  final double distanceKm;
  final int routePointCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.softGray,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: AppDesign.line),
      ),
      child: Column(
        children: [
          _ClaimFact(label: 'Tracked distance', value: '${distanceKm.toStringAsFixed(1)} km'),
          const SizedBox(height: 8),
          _ClaimFact(label: 'Route evidence', value: '$routePointCount points'),
          const SizedBox(height: 8),
          const _ClaimFact(label: 'Attendance session', value: 'Closed'),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: .24,
            color: AppDesign.muted,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
      ],
    );
  }
}
