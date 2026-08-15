import 'package:flutter/material.dart';

class DailyStatusScreen extends StatefulWidget {
  const DailyStatusScreen({super.key});

  @override
  State<DailyStatusScreen> createState() => _DailyStatusScreenState();
}

class _DailyStatusScreenState extends State<DailyStatusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _dealersVisited = TextEditingController();
  final _orders = TextEditingController();

  @override
  void dispose() {
    _summary.dispose();
    _dealersVisited.dispose();
    _orders.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Daily status saved locally and queued for sync.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Status')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Today',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Capture the day even when you are offline.',
              style: TextStyle(color: Color(0xFF747985)),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _dealersVisited,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dealers / sites visited',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _orders,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Orders captured',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summary,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Summary / market status',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 92),
                  child: Icon(Icons.notes_rounded),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Add a short field summary';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('SAVE STATUS'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
