// BRIXTA_CRM_FIRST_V1
// Staff Work shows published PJP tasks and authorized decisions.
// Legacy Responsibility runtime remains in the backend for historical data,
// but is no longer a discoverable everyday employee workflow.
import 'package:flutter/material.dart';

import '../../../core/models/mobile_capability.dart';
import '../../../core/session/app_session_controller.dart';
import 'pjp_work_tasks.dart';

class PremiumWorkTab extends StatelessWidget {
  const PremiumWorkTab({
    super.key,
    required this.controller,
    required this.modules,
    required this.readyWork,
    required this.blockedWork,
    required this.approvals,
    required this.onRefresh,
    required this.onCapabilityTap,
    required this.onReadyTap,
    required this.onApprovalTap,
  });

  final AppSessionController controller;
  // Retained as API compatibility parameters; the new Work UI no longer shows
  // or starts legacy Responsibility modules.
  final List<MobileCapability> modules;
  final List<Map<String, dynamic>> readyWork;
  final List<Map<String, dynamic>> blockedWork;
  final List<Map<String, dynamic>> approvals;
  final Future<void> Function() onRefresh;
  final ValueChanged<MobileCapability> onCapabilityTap;
  final ValueChanged<Map<String, dynamic>> onReadyTap;
  final ValueChanged<Map<String, dynamic>> onApprovalTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 110),
          children: [
            Text('YOUR WORK', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 2)),
            const SizedBox(height: 9),
            Text('Visits, tasks & approvals', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Today’s itinerary is managed in PJP. Site details and CRM entry live under FIELD.',
              style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: PjpWorkTasks(controller: controller),
              ),
            ),
            const SizedBox(height: 26),
            Row(children: [
              const Icon(Icons.verified_user_outlined, size: 22),
              const SizedBox(width: 10),
              Text('Approvals', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (approvals.isNotEmpty) Text('${approvals.length}', style: theme.textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            if (approvals.isEmpty)
              const Card(child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('No approval requests need your decision right now.'),
              ))
            else
              for (final approval in approvals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(approval['title']?.toString() ?? 'Approval request'),
                      subtitle: Text(approval['workflowName']?.toString() ?? 'Review required'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onApprovalTap(approval),
                    ),
                  ),
                ),
            const SizedBox(height: 16),
            Text('Looking for customers, dealers or construction sites? Open FIELD and select the CRM module.',
              style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
