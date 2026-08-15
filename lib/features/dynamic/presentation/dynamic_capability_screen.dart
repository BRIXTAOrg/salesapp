import 'package:flutter/material.dart';

import '../../../core/models/mobile_capability.dart';
import '../../../core/config/field_api.dart';
import '../../../core/session/app_session_controller.dart';

class DynamicCapabilityScreen extends StatefulWidget {
  const DynamicCapabilityScreen({
    super.key,
    required this.controller,
    required this.capability,
  });

  final AppSessionController controller;
  final MobileCapability capability;

  @override
  State<DynamicCapabilityScreen> createState() => _DynamicCapabilityScreenState();
}

class _DynamicCapabilityScreenState extends State<DynamicCapabilityScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _checks = {};
  bool _submitting = false;

  List<Map<String, dynamic>> get fields {
    final raw = widget.capability.config['fields'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController controllerFor(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final payload = <String, dynamic>{};
    for (final field in fields) {
      final key = (field['key'] ?? field['name'] ?? field['label']).toString();
      final type = (field['type'] ?? 'text').toString();

      if (type == 'checkbox') {
        payload[key] = _checks[key] ?? false;
      } else {
        final value = controllerFor(key).text.trim();
        if (field['required'] == true && value.isEmpty) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${field['label'] ?? key} is required.')),
          );
          return;
        }
        payload[key] = value;
      }
    }

    try {
      await FieldApi(
        accessToken: widget.controller.session!.accessToken,
      ).postJson('/api/salesApp/submissions', {
        'capabilityId': widget.capability.id,
        'clientMutationId':
            '${widget.controller.session!.user.id}-${widget.capability.id}-${DateTime.now().microsecondsSinceEpoch}',
        'status': 'submitted',
        'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': payload,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Done. Submitted successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capability = widget.capability;

    return Scaffold(
      appBar: AppBar(title: Text(capability.title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (capability.description != null) ...[
            Text(
              capability.description!,
              style: const TextStyle(color: Color(0xFF646A76)),
            ),
            const SizedBox(height: 16),
          ],
          if (fields.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'This responsibility is assigned to you. '
                  'Management has not added any fields yet.',
                ),
              ),
            )
          else
            ...fields.map(_field),
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                capability.type == 'checklist' ? 'COMPLETE' : 'SUBMIT',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(Map<String, dynamic> field) {
    final label = (field['label'] ?? 'Field').toString();
    final key = (field['key'] ?? field['name'] ?? label).toString();
    final type = (field['type'] ?? 'text').toString();
    final required = field['required'] == true;

    if (type == 'checkbox') {
      return Card(
        child: CheckboxListTile(
          value: _checks[key] ?? false,
          onChanged: (value) => setState(() => _checks[key] = value ?? false),
          title: Text(label),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controllerFor(key),
        keyboardType: type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : type == 'date'
                ? TextInputType.datetime
                : TextInputType.text,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
        ),
      ),
    );
  }
}
