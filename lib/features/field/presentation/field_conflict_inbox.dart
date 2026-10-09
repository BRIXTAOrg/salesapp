import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/database/app_database.dart';

// BRIXTA_FIELD_CONFLICT_INBOX_V1 — review evidence; no automatic replay/deletion.
class FieldConflictInbox extends StatefulWidget {
  const FieldConflictInbox({super.key, required this.scope});
  final String scope;

  @override
  State<FieldConflictInbox> createState() => _FieldConflictInboxState();
}

class _FieldConflictInboxState extends State<FieldConflictInbox> {
  List<Map<String, Object?>> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final rows = await AppDatabase.instance.offlineQueueConflicts(
        queueName: 'field_sections',
        scope: widget.scope,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _copy(String raw) async {
    var content = raw;
    try {
      content = const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      // Malformed offline payload is still copied verbatim.
    }
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved answers copied. Keep this copy safe.'),
      ),
    );
  }

  Future<void> _markReviewed(String id) async {
    await AppDatabase.instance.markOfflineQueueConflictReviewed(
      id: id,
      scope: widget.scope,
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Saved Field conflicts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'These saves were rejected by the server and preserved '
              'on this device. Copy the answers and check the latest site '
              'and App Experience before entering them again. Marking an '
              'item reviewed does not delete it or retry the old save.',
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _rows.isEmpty
                  ? const Center(child: Text('No saved conflicts.'))
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        final raw = row['payload_json']?.toString() ?? '';
                        Map<String, dynamic> data = {};
                        try {
                          final parsed = jsonDecode(raw);
                          if (parsed is Map) {
                            data = Map<String, dynamic>.from(parsed);
                          }
                        } catch (_) {}
                        final id = row['id']?.toString() ?? '';
                        final reviewed = row['reviewed_at'] != null;
                        final section =
                            data['sectionKey']?.toString() ?? 'Unknown step';
                        final recordId =
                            data['recordId']?.toString() ?? 'Unknown record';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                SelectableText('Record: $recordId'),
                                const SizedBox(height: 4),
                                Text(
                                  'HTTP ${row['status_code'] ?? 'local'} '
                                  '· ${reviewed ? 'Reviewed' : 'Needs review'}',
                                ),
                                Text(row['reason']?.toString() ?? ''),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _copy(raw),
                                      icon: const Icon(Icons.copy),
                                      label: const Text('Copy saved answers'),
                                    ),
                                    if (!reviewed && id.isNotEmpty)
                                      TextButton.icon(
                                        onPressed: () => _markReviewed(id),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Mark reviewed'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
