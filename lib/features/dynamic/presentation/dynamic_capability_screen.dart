import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/field_api.dart';
import '../../../core/database/app_database.dart';
import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/models/mobile_capability.dart';
import '../../../core/offline/offline_submission_queue.dart';
import '../../../core/services/media/local_photo_store.dart';
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
  State<DynamicCapabilityScreen> createState() =>
      _DynamicCapabilityScreenState();
}

class _DynamicCapabilityScreenState extends State<DynamicCapabilityScreen> {
  final _picker = ImagePicker();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _checks = {};
  final Map<String, String> _photos = {};
  final Map<String, String> _selects = {};

  bool _submitting = false;

  List<Map<String, dynamic>> get fields {
    final raw = widget.capability.config['fields'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  bool get _isDealerVisit => widget.capability.key == 'dealer_visit';
  bool get _isInspection =>
      widget.capability.type.toLowerCase() == 'checklist';

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  Future<void> _capturePhoto(String key) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 76,
        maxWidth: 1440,
      );

      if (picked == null) return;

      final persisted = await LocalPhotoStore.persist(
        picked,
        prefix: 'responsibility-$key',
      );

      await LocalPhotoStore.delete(_photos[key]);
      if (mounted) setState(() => _photos[key] = persisted);
    } catch (error) {
      if (!mounted) return;
      _message('Could not open camera: $error');
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final payload = <String, dynamic>{};

      for (final field in fields) {
        final key = _fieldKey(field);
        final type = (field['type'] ?? 'text').toString().toLowerCase();
        final required = field['required'] == true;

        if (_isPhotoType(type)) {
          final path = _photos[key];
          if (required && (path == null || path.isEmpty)) {
            _showRequired(field);
            return;
          }
          if (path != null && path.isNotEmpty) {
            payload[key] = {OfflineSubmissionQueue.localPhotoKey: path};
          }
          continue;
        }

        if (type == 'checkbox' || type == 'boolean') {
          payload[key] = _checks[key] ?? false;
          continue;
        }

        if (type == 'select' || type == 'choice' || type == 'dropdown') {
          final value = _selects[key] ?? '';
          if (required && value.isEmpty) {
            _showRequired(field);
            return;
          }
          payload[key] = value;
          continue;
        }

        final value = _controllerFor(key).text.trim();
        if (required && value.isEmpty) {
          _showRequired(field);
          return;
        }
        payload[key] = value;
      }

      // Session linkage stays invisible to the employee. The backend already
      // stores arbitrary payload JSON, so no new form infrastructure is needed.
      final localSession = await AppDatabase.instance.todayWorkSession(
        widget.controller.session!.user.id,
      );
      if (localSession != null) {
        payload['_workSessionId'] = localSession['id']?.toString();
        payload['_workSessionStatus'] = localSession['status']?.toString();
      }

      final submission = <String, dynamic>{
        'capabilityId': widget.capability.id,
        'clientMutationId': AppDatabase.instance.newId(),
        'status': 'submitted',
        'clientCreatedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': payload,
      };

      var queued = false;

      if (widget.controller.isOffline) {
        await OfflineSubmissionQueue.enqueue(submission);
        queued = true;
      } else {
        try {
          final prepared = await OfflineSubmissionQueue.prepareForUpload(
            widget.controller.session!.accessToken,
            submission,
          );

          await FieldApi(
            accessToken: widget.controller.session!.accessToken,
          ).postJson('/api/salesApp/submissions', prepared);

          for (final path in _photos.values) {
            await LocalPhotoStore.delete(path);
          }
        } catch (_) {
          await OfflineSubmissionQueue.enqueue(submission);
          queued = true;
        }
      }

      await HapticFeedback.lightImpact();
      if (!mounted) return;

      _message(
        queued
            ? 'Safe on this phone. We will send it when you are online.'
            : 'Recorded. Office has it.',
      );

      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showRequired(Map<String, dynamic> field) {
    final label = (field['label'] ?? _fieldKey(field)).toString();
    _message('$label is required.');
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capability = widget.capability;

    return Scaffold(
      appBar: AppBar(title: Text(capability.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 112),
        children: [
          _ResponsibilityIntro(capability: capability, fieldCount: fields.length),
          const SizedBox(height: 48),
          if (fields.isEmpty)
            _EmptyResponsibility(capability: capability)
          else
            ...[
              const _SectionLabel('WHAT YOU NEED TO RECORD'),
              const SizedBox(height: 16),
              for (var i = 0; i < fields.length; i++) ...[
                _buildField(fields[i]),
                if (i != fields.length - 1) const SizedBox(height: 24),
              ],
            ],
        ],
      ),
      bottomNavigationBar: fields.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                decoration: const BoxDecoration(
                  color: AppDesign.surface,
                  border: Border(top: BorderSide(color: AppDesign.line)),
                ),
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isDealerVisit
                              ? 'Record visit'
                              : _isInspection
                                  ? 'Complete inspection'
                                  : 'Record',
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final label = (field['label'] ?? 'Field').toString();
    final key = _fieldKey(field);
    final type = (field['type'] ?? 'text').toString().toLowerCase();
    final required = field['required'] == true;

    if (_isPhotoType(type)) {
      return _PhotoField(
        label: label,
        required: required,
        path: _photos[key],
        onTap: () => _capturePhoto(key),
      );
    }

    if (type == 'checkbox' || type == 'boolean') {
      return Container(
        decoration: BoxDecoration(
          color: AppDesign.surface,
          border: Border.all(color: AppDesign.line),
          borderRadius: BorderRadius.circular(AppDesign.radius),
        ),
        child: CheckboxListTile(
          value: _checks[key] ?? false,
          onChanged: (value) {
            setState(() => _checks[key] = value ?? false);
          },
          title: Text(
            required ? '$label *' : label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      );
    }

    if (type == 'select' || type == 'choice' || type == 'dropdown') {
      final rawOptions = field['options'];
      final options = rawOptions is List
          ? rawOptions.map((value) => value.toString()).toList()
          : <String>[];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selects[key],
            isExpanded: true,
            hint: const Text('Choose one'),
            items: options
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selects[key] = value);
            },
          ),
        ],
      );
    }

    final isLongText =
        type == 'textarea' || type == 'multiline' || type == 'notes';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        const SizedBox(height: 8),
        TextField(
          controller: _controllerFor(key),
          maxLines: isLongText ? 4 : 1,
          keyboardType: type == 'number'
              ? const TextInputType.numberWithOptions(decimal: true)
              : type == 'date'
                  ? TextInputType.datetime
                  : TextInputType.text,
          decoration: InputDecoration(
            hintText: (field['placeholder'] ?? _defaultHint(label)).toString(),
          ),
        ),
      ],
    );
  }

  String _defaultHint(String label) {
    if (_isDealerVisit && label.toLowerCase().contains('note')) {
      return 'Anything important?';
    }
    return 'Enter $label';
  }

  static String _fieldKey(Map<String, dynamic> field) =>
      (field['key'] ?? field['name'] ?? field['label'] ?? 'field').toString();

  static bool _isPhotoType(String type) =>
      type == 'photo' ||
      type == 'image' ||
      type == 'camera' ||
      type == 'upload_photo';
}

class _ResponsibilityIntro extends StatelessWidget {
  const _ResponsibilityIntro({required this.capability, required this.fieldCount});

  final MobileCapability capability;
  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppDesign.softGray,
            borderRadius: BorderRadius.circular(AppDesign.radius),
            border: Border.all(color: AppDesign.line),
          ),
          alignment: Alignment.center,
          child: Icon(
            AppIcons.forCapability(capability),
            size: 20,
            color: AppDesign.ink,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                capability.description?.trim().isNotEmpty == true
                    ? capability.description!.trim()
                    : _plainDescription(capability),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                fieldCount == 0
                    ? 'No steps configured yet'
                    : '$fieldCount ${fieldCount == 1 ? 'step' : 'steps'} · saves offline',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _plainDescription(MobileCapability capability) {
    switch (capability.key) {
      case 'dealer_visit':
        return 'Record what happened during the visit. We add the employee and session context automatically.';
      case 'leave':
        return 'Send a simple leave request.';
      default:
        return 'Complete the responsibility with only the information the phone cannot know for you.';
    }
  }
}

class _EmptyResponsibility extends StatelessWidget {
  const _EmptyResponsibility({required this.capability});
  final MobileCapability capability;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.settings_2, size: 20, color: AppDesign.muted),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This responsibility is not configured yet.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppDesign.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'When the administrator adds the required steps, they will appear here automatically.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.label,
    required this.required,
    required this.path,
    required this.onTap,
  });

  final String label;
  final bool required;
  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        const SizedBox(height: 8),
        Material(
          color: AppDesign.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radius),
            side: const BorderSide(color: AppDesign.line),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDesign.radius),
            child: SizedBox(
              height: 176,
              width: double.infinity,
              child: path != null && path!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppDesign.radius - 1),
                      child: Image.file(File(path!), fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.camera, size: 28, color: AppDesign.ink),
                        SizedBox(height: 8),
                        Text(
                          'Take photo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppDesign.ink,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.required});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text(
      required ? '${label.toUpperCase()} *' : label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: .24,
        color: AppDesign.muted,
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
