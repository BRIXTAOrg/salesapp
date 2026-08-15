import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/field_api.dart';
import '../../../core/design/app_design.dart';
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

class _DynamicCapabilityScreenState
    extends State<DynamicCapabilityScreen> {
  final _picker = ImagePicker();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _checks = {};
  final Map<String, String> _photos = {};

  bool _submitting = false;

  List<Map<String, dynamic>> get fields {
    final raw = widget.capability.config['fields'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(
        key,
        TextEditingController.new,
      );

  Future<void> _capturePhoto(String key) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 76,
      maxWidth: 1440,
    );

    if (picked == null) return;

    final persisted = await LocalPhotoStore.persist(
      picked,
      prefix: 'form-$key',
    );

    await LocalPhotoStore.delete(_photos[key]);

    if (mounted) {
      setState(() => _photos[key] = persisted);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final payload = <String, dynamic>{};

      for (final field in fields) {
        final key = _fieldKey(field);
        final type =
            (field['type'] ?? 'text').toString().toLowerCase();

        if (_isPhotoType(type)) {
          final path = _photos[key];

          if (field['required'] == true &&
              (path == null || path.isEmpty)) {
            _showRequired(field);
            return;
          }

          if (path != null && path.isNotEmpty) {
            payload[key] = {
              OfflineSubmissionQueue.localPhotoKey: path,
            };
          }
          continue;
        }

        if (type == 'checkbox') {
          payload[key] = _checks[key] ?? false;
          continue;
        }

        final value = _controllerFor(key).text.trim();

        if (field['required'] == true && value.isEmpty) {
          _showRequired(field);
          return;
        }

        payload[key] = value;
      }

      final submission = <String, dynamic>{
        'capabilityId': widget.capability.id,
        'clientMutationId':
            '${widget.controller.session!.user.id}-'
            '${widget.capability.id}-'
            '${DateTime.now().microsecondsSinceEpoch}',
        'status': 'submitted',
        'clientCreatedAt':
            DateTime.now().toUtc().toIso8601String(),
        'payload': payload,
      };

      var queued = false;

      if (widget.controller.isOffline) {
        await OfflineSubmissionQueue.enqueue(submission);
        queued = true;
      } else {
        try {
          final prepared =
              await OfflineSubmissionQueue.prepareForUpload(
            widget.controller.session!.accessToken,
            submission,
          );

          await FieldApi(
            accessToken:
                widget.controller.session!.accessToken,
          ).postJson(
            '/api/salesApp/submissions',
            prepared,
          );

          for (final path in _photos.values) {
            await LocalPhotoStore.delete(path);
          }
        } catch (_) {
          await OfflineSubmissionQueue.enqueue(submission);
          queued = true;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Saved offline. It will sync automatically.'
                : 'Submitted.',
          ),
        ),
      );

      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showRequired(Map<String, dynamic> field) {
    if (!mounted) return;

    final label =
        (field['label'] ?? _fieldKey(field)).toString();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is required.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capability = widget.capability;
    final isInspection =
        capability.type.toLowerCase() == 'checklist';

    return Scaffold(
      appBar: AppBar(
        title: Text(capability.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
        children: [
          _FormIntro(
            capability: capability,
            fieldCount: fields.length,
          ),
          const SizedBox(height: 18),
          if (fields.isEmpty)
            const _EmptyFields()
          else
            ...fields.map(_buildField),
        ],
      ),
      bottomNavigationBar: fields.isEmpty
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppDesign.line),
                  ),
                ),
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isInspection
                              ? 'SUBMIT INSPECTION'
                              : 'SUBMIT FORM',
                        ),
                ),
              ),
            ),
    );
  }

  Widget _buildField(Map<String, dynamic> field) {
    final label = (field['label'] ?? 'Field').toString();
    final key = _fieldKey(field);
    final type =
        (field['type'] ?? 'text').toString().toLowerCase();
    final required = field['required'] == true;

    if (_isPhotoType(type)) {
      return _PhotoFieldCard(
        label: label,
        required: required,
        path: _photos[key],
        onTap: () => _capturePhoto(key),
      );
    }

    if (type == 'checkbox') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Card(
          child: CheckboxListTile(
            value: _checks[key] ?? false,
            onChanged: (value) {
              setState(() {
                _checks[key] = value ?? false;
              });
            },
            title: Text(
              required ? '$label *' : label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            controlAffinity:
                ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 3,
            ),
          ),
        ),
      );
    }

    final isLongText =
        type == 'textarea' ||
        type == 'multiline' ||
        type == 'notes';

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppDesign.ink,
            ),
          ),
          const SizedBox(height: 7),
          TextField(
            controller: _controllerFor(key),
            maxLines: isLongText ? 4 : 1,
            keyboardType: type == 'number'
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                  )
                : type == 'date'
                    ? TextInputType.datetime
                    : TextInputType.text,
            decoration: InputDecoration(
              hintText:
                  (field['placeholder'] ?? 'Enter $label')
                      .toString(),
            ),
          ),
        ],
      ),
    );
  }

  static String _fieldKey(Map<String, dynamic> field) =>
      (field['key'] ??
              field['name'] ??
              field['label'] ??
              'field')
          .toString();

  static bool _isPhotoType(String type) =>
      type == 'photo' ||
      type == 'image' ||
      type == 'camera' ||
      type == 'upload_photo';
}

class _FormIntro extends StatelessWidget {
  const _FormIntro({
    required this.capability,
    required this.fieldCount,
  });

  final MobileCapability capability;
  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppDesign.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppDesign.softBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              capability.type == 'checklist'
                  ? Icons.fact_check_outlined
                  : Icons.description_outlined,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  capability.type == 'checklist'
                      ? 'Inspection'
                      : 'Smart form',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppDesign.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  ),
                ),
                const SizedBox(height: 3),
                if (capability.description != null &&
                    capability.description!.trim().isNotEmpty)
                  Text(
                    capability.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  const Text(
                    'Complete the fields below.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  '$fieldCount field${fieldCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppDesign.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoFieldCard extends StatelessWidget {
  const _PhotoFieldCard({
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
    final hasPhoto =
        path != null && File(path!).existsSync();

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppDesign.line),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 155,
                width: double.infinity,
                child: hasPhoto
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(17),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(path!),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withValues(alpha: .72),
                                  borderRadius:
                                      BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                      size: 15,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Retake',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 30,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Take photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Saved offline if needed',
                            style: TextStyle(
                              color: AppDesign.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFields extends StatelessWidget {
  const _EmptyFields();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppDesign.softGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'No fields have been configured for this responsibility.',
        style: TextStyle(
          color: AppDesign.muted,
          fontSize: 13,
        ),
      ),
    );
  }
}
