import 'package:flutter/material.dart';

class AllowancesScreen extends StatelessWidget {
  const AllowancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allowances • TA/DA')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New claim form plugs in here next.'),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('NEW CLAIM'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
        children: const [
          _AmountSummary(),
          SizedBox(height: 18),
          Text(
            'Recent claims',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          _ClaimCard(
            number: 'TA-2026-0812',
            period: '01 Aug – 07 Aug',
            amount: '₹3,850',
            status: 'Manager Review',
          ),
          SizedBox(height: 10),
          _ClaimCard(
            number: 'TA-2026-0731',
            period: '24 Jul – 31 Jul',
            amount: '₹2,430',
            status: 'Approved',
          ),
        ],
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  const _AmountSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: const Color(0xFF303541),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current month',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 7),
          Text(
            '₹6,280',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 3),
          Text(
            '₹2,430 approved • ₹3,850 pending',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.number,
    required this.period,
    required this.amount,
    required this.status,
  });

  final String number;
  final String period;
  final String amount;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            child: Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  period,
                  style: const TextStyle(
                    color: Color(0xFF747985),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
