import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/config/field_api.dart';
import '../../../core/session/app_session_controller.dart';

class AllowancesScreen extends StatefulWidget {
  const AllowancesScreen({
    super.key,
    required this.controller,
  });

  final AppSessionController controller;

  @override
  State<AllowancesScreen> createState() => _AllowancesScreenState();
}

class _AllowancesScreenState extends State<AllowancesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _claims = const [];
  double _distanceKm = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = widget.controller.session!;
    final distance = await AppDatabase.instance.todayDistanceKm(session.user.id);
    List<Map<String, dynamic>> claims = [];

    try {
      final response = await FieldApi(accessToken: session.accessToken)
          .getJson('/api/salesApp/tada-bills');
      final data = response['data'];
      if (data is List) {
        claims = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _distanceKm = distance;
      _claims = claims;
      _loading = false;
    });
  }

  Future<void> _newClaim() async {
    final result = await showModalBottomSheet<_ClaimDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ClaimSheet(distanceKm: _distanceKm),
    );

    if (result == null) return;

    final session = widget.controller.session!;
    final today = DateTime.now();
    final date = _dateKey(today);

    try {
      await FieldApi(accessToken: session.accessToken)
          .postJson('/api/salesApp/tada-bills', {
        'billDate': date,
        'fromDate': date,
        'toDate': date,
        'dailyAllowance': result.dailyAllowance,
        'totalCost': result.totalCost,
        'remarks': result.remarks,
        'status': 'PENDING',
        'items': [
          {
            'fromLocation': result.fromLocation,
            'toLocation': result.toLocation,
            'distanceTravelled': _distanceKm.toStringAsFixed(2),
            'transportFare': result.transportFare,
            'lodgingFare': result.lodgingFare,
            'foodingFare': result.foodingFare,
            'localConveyance': result.localConveyance,
            'outOfPocketPaid': result.outOfPocket,
            'totalBillsAdded': 0,
            'remarks': result.remarks,
          }
        ],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TA/DA claim sent for review.')),
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit claim: $error')),
        );
      }
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TA / DA')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _newClaim,
        icon: const Icon(Icons.add_rounded),
        label: const Text('NEW CLAIM'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF303541),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today’s tracked distance',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${_distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Filled automatically from field tracking',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Claims',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ))
            else if (_claims.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No claims yet.'),
                ),
              )
            else
              ..._claims.map(
                (claim) => Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(
                      '₹${claim['totalCost'] ?? claim['total_cost'] ?? '0'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${claim['billDate'] ?? claim['bill_date'] ?? ''} · '
                      '${claim['status'] ?? 'PENDING'}',
                    ),
                  ),
                ),
              ),
          ],
        ),
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
  const _ClaimSheet({required this.distanceKm});
  final double distanceKm;

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final from = TextEditingController();
  final to = TextEditingController();
  final transport = TextEditingController(text: '0');
  final lodging = TextEditingController(text: '0');
  final food = TextEditingController(text: '0');
  final local = TextEditingController(text: '0');
  final oop = TextEditingController(text: '0');
  final da = TextEditingController(text: '0');
  final remarks = TextEditingController();

  double n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  void dispose() {
    for (final c in [from, to, transport, lodging, food, local, oop, da, remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New TA / DA claim',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.distanceKm.toStringAsFixed(1)} km will be attached from today’s GPS tracking.',
              ),
              const SizedBox(height: 18),
              TextField(controller: from, decoration: const InputDecoration(labelText: 'From')),
              const SizedBox(height: 10),
              TextField(controller: to, decoration: const InputDecoration(labelText: 'To')),
              const SizedBox(height: 10),
              ...[
                ('Transport fare', transport),
                ('Lodging', lodging),
                ('Food', food),
                ('Local conveyance', local),
                ('Out of pocket', oop),
                ('Daily allowance', da),
              ].map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: field.$2,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: field.$1, prefixText: '₹ '),
                  ),
                ),
              ),
              TextField(
                controller: remarks,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remarks (optional)'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _ClaimDraft(
                    fromLocation: from.text.trim(),
                    toLocation: to.text.trim(),
                    transportFare: n(transport),
                    lodgingFare: n(lodging),
                    foodingFare: n(food),
                    localConveyance: n(local),
                    outOfPocket: n(oop),
                    dailyAllowance: n(da),
                    remarks: remarks.text.trim(),
                  ),
                ),
                child: const Text('SUBMIT FOR REVIEW'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
