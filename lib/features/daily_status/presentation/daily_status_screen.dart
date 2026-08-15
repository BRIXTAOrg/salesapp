import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

class DailyStatusScreen extends StatefulWidget {
  const DailyStatusScreen({
    super.key,
    required this.employeeId,
  });

  final String employeeId;

  @override
  State<DailyStatusScreen> createState() => _DailyStatusScreenState();
}

class _DailyStatusScreenState extends State<DailyStatusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _dealersVisited = TextEditingController();
  final _orders = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _summary.dispose();
    _dealersVisited.dispose();
    _orders.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);
    try {
      await AppDatabase.instance.saveDailyStatus(
        employeeId: widget.employeeId,
        dealersVisited: int.tryParse(_dealersVisited.text) ?? 0,
        orders: int.tryParse(_orders.text) ?? 0,
        summary: _summary.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Daily status saved locally and queued for backend sync.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Add a short field summary'
                      : null,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'SAVING…' : 'SAVE STATUS'),
            ),
          ],
        ),
      ),
    );
  }
}
