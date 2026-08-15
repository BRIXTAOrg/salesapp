import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/field_api.dart';
import '../../../core/design/app_design.dart';
import '../../../core/session/app_session_controller.dart';
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
  State<AllowancesScreen> createState() =>
      _AllowancesScreenState();
}

class _AllowancesScreenState extends State<AllowancesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _claims = const [];

  @override
  void initState() {
    super.initState();

    widget.trackingController.ensureAutomatic(
      widget.controller.session!.user.id,
    );

    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> claims = const [];

    try {
      final response = await FieldApi(
        accessToken:
            widget.controller.session!.accessToken,
      ).getJson('/api/salesApp/tada-bills');

      final raw = response['data'];

      if (raw is List) {
        claims = raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _claims = claims;
      _loading = false;
    });
  }

  Future<void> _newClaim() async {
    final draft = await showModalBottomSheet<_ClaimDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppDesign.canvas,
      builder: (_) => _ClaimSheet(
        distanceKm:
            widget.trackingController.distanceKm,
      ),
    );

    if (draft == null) return;

    final date = _dateKey(DateTime.now());

    try {
      await FieldApi(
        accessToken:
            widget.controller.session!.accessToken,
      ).postJson('/api/salesApp/tada-bills', {
        'billDate': date,
        'fromDate': date,
        'toDate': date,
        'dailyAllowance': draft.dailyAllowance,
        'totalCost': draft.totalCost,
        'remarks': draft.remarks,
        'status': 'PENDING',
        'items': [
          {
            'fromLocation': draft.fromLocation,
            'toLocation': draft.toLocation,
            'distanceTravelled': widget
                .trackingController.distanceKm
                .toStringAsFixed(2),
            'transportFare': draft.transportFare,
            'lodgingFare': draft.lodgingFare,
            'foodingFare': draft.foodingFare,
            'localConveyance': draft.localConveyance,
            'outOfPocketPaid': draft.outOfPocket,
            'totalBillsAdded': 0,
            'remarks': draft.remarks,
          },
        ],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim sent for review.'),
          ),
        );
      }

      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Claim could not be sent yet: $error',
            ),
          ),
        );
      }
    }
  }

  int get _pendingClaims => _claims
      .where(
        (claim) =>
            (claim['status'] ?? '')
                .toString()
                .toUpperCase() ==
            'PENDING',
      )
      .length;

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              24,
              18,
              100,
            ),
            children: [
              Text(
                'TA / DA',
                style:
                    Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Travel is captured automatically. Review, add expenses and submit.',
                style: TextStyle(color: AppDesign.muted),
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: widget.trackingController,
                builder: (_, _) => _TravelCard(
                  distanceKm:
                      widget.trackingController.distanceKm,
                  active:
                      widget.trackingController.active,
                  pendingClaims: _pendingClaims,
                ),
              ),
              const SizedBox(height: 16),
              const _AutoCaptureList(),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text(
                    'Claims',
                    style:
                        Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed:
                        _loading ? null : _newClaim,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                    ),
                    label: const Text('New claim'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                )
              else if (_claims.isEmpty)
                const _NoClaims()
              else
                for (final claim in _claims) ...[
                  _ClaimRow(claim: claim),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelCard extends StatelessWidget {
  const _TravelCard({
    required this.distanceKm,
    required this.active,
    required this.pendingClaims,
  });

  final double distanceKm;
  final bool active;
  final int pendingClaims;

  @override
  Widget build(BuildContext context) {
    final visualProgress =
        math.min(distanceKm / 40, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF2F8FF),
            Color(0xFFF7F3FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFDDE5F5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TinyPill(
                text: active
                    ? 'AUTO CAPTURE ON'
                    : 'AUTO CAPTURE STANDBY',
                color: Colors.white,
              ),
              const Spacer(),
              const Icon(
                Icons.route_rounded,
                size: 29,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'captured today',
            style: TextStyle(
              color: AppDesign.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 19),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: visualProgress,
              minHeight: 9,
              backgroundColor:
                  Colors.white.withValues(alpha: .8),
              valueColor: const AlwaysStoppedAnimation(
                AppDesign.ink,
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Route points are saved offline first.',
                  style: TextStyle(
                    color: AppDesign.muted,
                    fontSize: 11.5,
                  ),
                ),
              ),
              if (pendingClaims > 0)
                _TinyPill(
                  text: '$pendingClaims pending',
                  color: AppDesign.softAmber,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: .45,
        ),
      ),
    );
  }
}

class _AutoCaptureList extends StatelessWidget {
  const _AutoCaptureList();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: const [
          _MiniRow(
            icon: Icons.route_outlined,
            title: 'Distance',
            value: 'Automatic',
          ),
          Divider(height: 1, indent: 54),
          _MiniRow(
            icon: Icons.cloud_done_outlined,
            title: 'Offline saving',
            value: 'On',
          ),
          Divider(height: 1, indent: 54),
          _MiniRow(
            icon: Icons.receipt_long_outlined,
            title: 'Claim',
            value: 'Review only',
          ),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: AppDesign.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppDesign.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoClaims extends StatelessWidget {
  const _NoClaims();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppDesign.softGreen,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.check_rounded,
              color: AppDesign.green,
              size: 19,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No claims yet. Travel capture can keep running in the background.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({required this.claim});

  final Map<String, dynamic> claim;

  @override
  Widget build(BuildContext context) {
    final status =
        (claim['status'] ?? 'PENDING').toString();
    final amount =
        claim['totalCost'] ?? claim['total_cost'] ?? '0';
    final date =
        claim['billDate'] ?? claim['bill_date'] ?? '';

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppDesign.softBlue,
          child: Icon(
            Icons.receipt_long_outlined,
            color: AppDesign.ink,
          ),
        ),
        title: Text(
          '₹$amount',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text('$date • $status'),
        trailing:
            const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _ClaimDraft {
  const _ClaimDraft({
    required this.fromLocation,
    required this.toLocation,
    required this.transportFare,
    required this.lodgingFare,
    required this.foodingFare,
    required this.localConveyance,
    required this.outOfPocket,
    required this.dailyAllowance,
    required this.remarks,
  });

  final String fromLocation;
  final String toLocation;
  final double transportFare;
  final double lodgingFare;
  final double foodingFare;
  final double localConveyance;
  final double outOfPocket;
  final double dailyAllowance;
  final String remarks;

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
  });

  final double distanceKm;

  @override
  State<_ClaimSheet> createState() =>
      _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final from = TextEditingController();
  final to = TextEditingController();
  final transport = TextEditingController(text: '0');
  final lodging = TextEditingController(text: '0');
  final food = TextEditingController(text: '0');
  final local = TextEditingController(text: '0');
  final outOfPocket =
      TextEditingController(text: '0');
  final daily = TextEditingController(text: '0');
  final remarks = TextEditingController();

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  @override
  void dispose() {
    for (final controller in [
      from,
      to,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        20,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Review claim',
              style:
                  Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.distanceKm.toStringAsFixed(1)} km has already been captured automatically.',
              style:
                  const TextStyle(color: AppDesign.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: from,
              decoration:
                  const InputDecoration(labelText: 'From'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: to,
              decoration:
                  const InputDecoration(labelText: 'To'),
            ),
            const SizedBox(height: 10),
            for (final field in [
              ('Transport fare', transport),
              ('Lodging', lodging),
              ('Food', food),
              ('Local conveyance', local),
              ('Out of pocket', outOfPocket),
              ('Daily allowance', daily),
            ]) ...[
              TextField(
                controller: field.$2,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: field.$1,
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: remarks,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _ClaimDraft(
                    fromLocation: from.text.trim(),
                    toLocation: to.text.trim(),
                    transportFare: _number(transport),
                    lodgingFare: _number(lodging),
                    foodingFare: _number(food),
                    localConveyance: _number(local),
                    outOfPocket: _number(outOfPocket),
                    dailyAllowance: _number(daily),
                    remarks: remarks.text.trim(),
                  ),
                );
              },
              child: const Text('SUBMIT FOR REVIEW'),
            ),
          ],
        ),
      ),
    );
  }
}
