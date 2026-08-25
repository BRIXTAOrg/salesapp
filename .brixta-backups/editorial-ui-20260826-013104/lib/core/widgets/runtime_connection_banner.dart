import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../design/app_design.dart';
import '../session/app_session_controller.dart';

/// Prominent, reusable ONLINE/OFFLINE surface.
///
/// This is intentionally not a tiny status icon. Field users should always
/// understand whether changes are going directly to the company or are being
/// held safely on the phone.
class RuntimeConnectionBanner extends StatelessWidget {
  const RuntimeConnectionBanner({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final AppSessionController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final online = controller.isOnline;
        final syncing = controller.isActivelySyncing;
        final pending = controller.pendingChanges;

        final tone = online ? AppDesign.green : AppDesign.amber;
        final background = online ? AppDesign.softGreen : AppDesign.softAmber;
        final icon = online ? LucideIcons.wifi : LucideIcons.wifi_off;

        final title = syncing
            ? 'SYNCING WITH COMPANY'
            : online
                ? 'ONLINE · LIVE WITH COMPANY'
                : 'OFFLINE · WORKING FROM THIS PHONE';

        final detail = syncing
            ? pending > 0
                ? 'Sending $pending saved change${pending == 1 ? '' : 's'} and checking for company updates.'
                : 'Checking for newly published work and workflow changes.'
            : online
                ? pending > 0
                    ? '$pending change${pending == 1 ? '' : 's'} waiting to sync.'
                    : controller.lastSyncLabel
                : pending > 0
                    ? '$pending change${pending == 1 ? '' : 's'} safe on this phone. They will send automatically.'
                    : 'You can keep working. New entries stay on this phone until the connection returns.';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppDesign.radius),
            border: Border.all(color: tone.withValues(alpha: .28)),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 34 : 40,
                height: compact ? 34 : 40,
                decoration: BoxDecoration(
                  color: AppDesign.surface,
                  borderRadius: BorderRadius.circular(AppDesign.controlRadius),
                  border: Border.all(color: tone.withValues(alpha: .24)),
                ),
                alignment: Alignment.center,
                child: syncing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tone,
                        ),
                      )
                    : Icon(icon, size: 19, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tone,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .35,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: AppDesign.muted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (online && !syncing) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: controller.syncNow,
                  child: const Text('Sync'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
