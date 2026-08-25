import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../design/app_design.dart';
import '../session/app_session_controller.dart';
import 'editorial_backdrop.dart';

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

        final tone = online ? AppDesign.primary : AppDesign.amber;

        final icon = online ? LucideIcons.wifi : LucideIcons.wifi_off;

        final title = syncing
            ? 'SYNCING / COMPANY'
            : online
            ? 'LIVE / COMPANY'
            : 'OFFLINE / DEVICE';

        final detail = syncing
            ? pending > 0
                  ? 'Transmitting $pending queued change${pending == 1 ? '' : 's'} and resolving workspace state.'
                  : 'Resolving the latest published workspace.'
            : online
            ? pending > 0
                  ? '$pending change${pending == 1 ? '' : 's'} queued for transmission.'
                  : controller.lastSyncLabel
            : pending > 0
            ? '$pending change${pending == 1 ? '' : 's'} secured locally. Automatic transmission resumes when online.'
            : 'Work continues locally. New records remain secured on this device.';

        return AnimatedContainer(
          duration: AppDesign.editorialDuration,

          curve: AppDesign.editorialCurve,

          decoration: BoxDecoration(
            color: AppDesign.surface.withValues(alpha: .82),
            border: Border.all(color: AppDesign.line, width: 1),
            borderRadius: BorderRadius.circular(AppDesign.radius),
          ),

          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 12 : 16,
                  vertical: compact ? 10 : 14,
                ),

                child: Row(
                  children: [
                    Container(
                      width: compact ? 32 : 38,
                      height: compact ? 32 : 38,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: AppDesign.line),
                        borderRadius: BorderRadius.circular(AppDesign.radius),
                      ),
                      alignment: Alignment.center,
                      child: syncing
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: tone,
                              ),
                            )
                          : Icon(icon, size: 17, color: tone),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(width: 6, height: 6, color: tone),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  title,
                                  style: AppDesign.mono(
                                    size: 9,
                                    color: tone,
                                    weight: FontWeight.w600,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (!compact) ...[
                            const SizedBox(height: 6),
                            Text(
                              detail,
                              style: AppDesign.sans(
                                size: 12,
                                color: AppDesign.muted,
                                height: 1.4,
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
                        child: const Text('SYNC'),
                      ),
                    ],
                  ],
                ),
              ),

              if (syncing) const EditorialScanLine(),
            ],
          ),
        );
      },
    );
  }
}
