import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/device/device_identity.dart';
import '../../../core/services/runtime/responsibility_runtime_api.dart';
import '../../../core/session/app_session_controller.dart';
import '../../../core/widgets/runtime_connection_banner.dart';
import '../../tracking/presentation/tracking_controller.dart';

class EmployeeProfileTab extends StatefulWidget {
  const EmployeeProfileTab({
    super.key,
    required this.controller,
    required this.tracker,
    required this.workSession,
  });

  final AppSessionController controller;
  final TrackingController tracker;
  final Map<String, Object?>? workSession;

  @override
  State<EmployeeProfileTab> createState() => _EmployeeProfileTabState();
}

class _EmployeeProfileTabState extends State<EmployeeProfileTab> {
  Map<String, dynamic>? _runtime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.controller.session == null) return;
    if (mounted) setState(() => _loading = true);

    if (widget.controller.isOnline) {
      try {
        final body = await ResponsibilityRuntimeApi(
          accessToken: widget.controller.session!.accessToken,
        ).profileRuntime();
        if (mounted) setState(() => _runtime = body);
      } catch (_) {}
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session!;
    final devices = _mapList(_runtime?['devices']);
    final currentDeviceId =
        _runtime?['currentDeviceId']?.toString() ??
        AppDeviceIdentity.instance.deviceId;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: AppDesign.pageInset,
          children: [
            Text('Me', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'Your account, connection and company devices.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            RuntimeConnectionBanner(controller: widget.controller),
            const SizedBox(height: 32),
            const _SectionLabel('EMPLOYEE'),
            const SizedBox(height: 12),
            _Card(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppDesign.softGreen,
                      borderRadius: BorderRadius.circular(AppDesign.radius),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      AppIcons.profile,
                      color: AppDesign.green,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.user.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${session.user.designation} · ${session.user.employeeCode}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (session.user.department?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 2),
                          Text(
                            session.user.department!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppDesign.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const _SectionLabel('TODAY'),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                children: [
                  _FactRow(
                    icon: AppIcons.attendance,
                    label: 'Work session',
                    value: _sessionLabel(widget.workSession),
                  ),
                  const Divider(height: 24),
                  AnimatedBuilder(
                    animation: widget.tracker,
                    builder: (_, _) => _FactRow(
                      icon: AppIcons.journey,
                      label: 'Travel meter',
                      value: widget.tracker.active
                          ? '${widget.tracker.distanceKm.toStringAsFixed(1)} km · Active'
                          : '${widget.tracker.distanceKm.toStringAsFixed(1)} km · Standby',
                    ),
                  ),
                  const Divider(height: 24),
                  _FactRow(
                    icon: LucideIcons.refresh_cw,
                    label: 'Workspace',
                    value: widget.controller.lastSyncLabel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                const Expanded(child: _SectionLabel('COMPANY DEVICES')),
                if (_loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This company account records the devices used to sign in, their app version, and when they last connected or synced.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              _DeviceCard(
                device: {
                  'deviceId': AppDeviceIdentity.instance.deviceId,
                  'platform': AppDeviceIdentity.instance.platform,
                  'appVersion': AppDeviceIdentity.appVersion,
                  'lastSeenAt': null,
                },
                current: true,
              )
            else
              for (var i = 0; i < devices.length; i++) ...[
                _DeviceCard(
                  device: devices[i],
                  current:
                      devices[i]['deviceId']?.toString() == currentDeviceId,
                ),
                if (i != devices.length - 1) const SizedBox(height: 10),
              ],
            const SizedBox(height: 36),
            OutlinedButton.icon(
              onPressed: widget.controller.logout,
              icon: Icon(AppIcons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }

  static String _sessionLabel(Map<String, Object?>? value) {
    switch (value?['status']) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Complete';
      default:
        return 'Not started';
    }
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.current});

  final Map<String, dynamic> device;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final platform = device['platform']?.toString() ?? 'device';
    final version = device['appVersion']?.toString() ?? 'unknown';
    final seen = _relativeTime(device['lastSeenAt']);
    final synced = _relativeTime(device['lastSyncAt']);
    final metadata = _map(device['metadata']);
    final osVersion = metadata['osVersion']?.toString();

    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: current ? AppDesign.softGreen : AppDesign.softGray,
              borderRadius: BorderRadius.circular(AppDesign.controlRadius),
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.smartphone,
              color: current ? AppDesign.green : AppDesign.muted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _titleCase(platform),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (current)
                      const _Pill(label: 'THIS DEVICE', tone: AppDesign.green),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  'BRIXTA $version${osVersion == null || osVersion.isEmpty ? '' : ' · $osVersion'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Seen $seen',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppDesign.muted,
                      ),
                    ),
                    if (device['lastSyncAt'] != null)
                      Text(
                        'Synced $synced',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppDesign.muted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppDesign.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppDesign.muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppDesign.surface,
        border: Border.all(color: AppDesign.line),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});
  final String label;
  final Color tone;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppDesign.radius),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
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
        color: AppDesign.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .5,
      ),
    );
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : <Map<String, dynamic>>[];

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _relativeTime(dynamic raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (parsed == null) return 'recently';
  final diff = DateTime.now().difference(parsed);
  if (diff.inSeconds < 30) return 'now';
  if (diff.inMinutes < 1) return '<1 min ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${diff.inDays} d ago';
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
