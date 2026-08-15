import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';

class EnquiryFormScreen extends StatefulWidget {
  const EnquiryFormScreen({
    super.key,
    required this.employeeId,
  });

  final String employeeId;

  @override
  State<EnquiryFormScreen> createState() => _EnquiryFormScreenState();
}

class _EnquiryFormScreenState extends State<EnquiryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _requirement = TextEditingController();

  String _type = 'Dealer';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _company.dispose();
    _requirement.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);
    try {
      await AppDatabase.instance.saveEnquiry(
        employeeId: widget.employeeId,
        enquiryType: _type,
        contactPerson: _name.text.trim(),
        phone: _phone.text.trim(),
        company: _company.text.trim(),
        requirement: _requirement.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enquiry saved on this device. It is queued for backend sync.',
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
      appBar: AppBar(title: const Text('New Enquiry')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Enquiry type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Dealer', child: Text('Dealer')),
                DropdownMenuItem(
                  value: 'Contractor',
                  child: Text('Contractor'),
                ),
                DropdownMenuItem(value: 'Builder', child: Text('Builder')),
                DropdownMenuItem(
                  value: 'Institutional',
                  child: Text('Institutional'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Contact person',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _company,
              decoration: const InputDecoration(
                labelText: 'Firm / company / site',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _requirement,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Requirement / notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.add_task_rounded),
              label: Text(_saving ? 'SAVING…' : 'SAVE ENQUIRY'),
            ),
          ],
        ),
      ),
    );
  }
}
