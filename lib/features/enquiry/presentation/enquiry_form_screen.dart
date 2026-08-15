import 'package:flutter/material.dart';

class EnquiryFormScreen extends StatefulWidget {
  const EnquiryFormScreen({super.key});

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

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _company.dispose();
    _requirement.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enquiry saved locally and queued for sync.'),
      ),
    );
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
              onChanged: (value) => setState(() => _type = value ?? _type),
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
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 76),
                  child: Icon(Icons.description_outlined),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('SAVE ENQUIRY'),
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
