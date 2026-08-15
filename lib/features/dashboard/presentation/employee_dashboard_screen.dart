import 'package:flutter/material.dart';

import '../../../core/registry/feature_registry.dart';
// import '../../../core/services/connectivity/connectivity_gateway.dart';
import '../../../core/session/app_session_controller.dart';
import '../../../core/widgets/status_pill.dart';

class EmployeeDashboardScreen extends StatelessWidget {
  const EmployeeDashboardScreen({
    super.key,
    required this.controller,
  });

  final AppSessionController controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session!;
    final visibleModules = FeatureRegistry.employeeModules
        .where((module) => session.can(module.permission))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: controller.tenant.primaryColor,
        foregroundColor: Colors.white,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.tenant.appName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              session.user.employeeCode,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed:
                controller.syncSnapshot.isSyncing ? null : controller.syncNow,
            icon: controller.syncSnapshot.isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Icon(Icons.sync_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await controller.logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.syncNow,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            _EmployeeHeader(controller: controller),
            const SizedBox(height: 14),
            _SyncBanner(controller: controller),
            const SizedBox(height: 20),
            Text(
              'Workspace',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: visibleModules.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final module = visibleModules[index];
                return _ModuleTile(
                  module: module,
                  accent: controller.tenant.primaryColor,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeHeader extends StatelessWidget {
  const _EmployeeHeader({required this.controller});

  final AppSessionController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.session!.user;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 20,
            offset: Offset(0, 7),
            color: Color(0x12000000),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: controller.tenant.primaryColor.withValues(
              alpha: 0.11,
            ),
            foregroundColor: controller.tenant.primaryColor,
            child: const Icon(Icons.person_outline_rounded, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.designation,
                  style: const TextStyle(
                    color: Color(0xFF717680),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          StatusPill(
            icon: controller.isOnline
                ? Icons.cloud_done_outlined
                : Icons.cloud_off_outlined,
            label: controller.isOnline ? 'Online' : 'Offline',
            tone: controller.isOnline
                ? const Color(0xFF15803D)
                : const Color(0xFFB45309),
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.controller});

  final AppSessionController controller;

  @override
  Widget build(BuildContext context) {
    final sync = controller.syncSnapshot;

    String label;
    IconData icon;

    if (!controller.isOnline) {
      label = '${sync.pendingCount} change(s) saved on device';
      icon = Icons.cloud_off_outlined;
    } else if (sync.isSyncing) {
      label = 'Synchronizing field data…';
      icon = Icons.sync_rounded;
    } else if (sync.conflictCount > 0) {
      label = '${sync.conflictCount} sync conflict(s) need attention';
      icon = Icons.warning_amber_rounded;
    } else if (sync.pendingCount > 0) {
      label = '${sync.pendingCount} change(s) waiting to sync';
      icon = Icons.cloud_upload_outlined;
    } else {
      label = 'Everything is synchronized';
      icon = Icons.cloud_done_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF3B4556)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF3B4556),
              ),
            ),
          ),
          if (controller.isOnline &&
              sync.pendingCount > 0 &&
              !sync.isSyncing)
            TextButton(
              onPressed: controller.syncNow,
              child: const Text('SYNC'),
            ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.accent,
  });

  final FeatureDefinition module;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: module.builder,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6E8EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: Icon(module.icon, color: accent, size: 27),
              ),
              const Spacer(),
              Text(
                module.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF313641),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
