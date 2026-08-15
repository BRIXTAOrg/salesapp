import 'package:flutter/material.dart';
import '../../../core/session/app_session_controller.dart';
import '../../dynamic/presentation/dynamic_capability_screen.dart';

class EmployeeDashboardScreen extends StatelessWidget {
  const EmployeeDashboardScreen({super.key, required this.controller});
  final AppSessionController controller;
  @override
  Widget build(BuildContext context) {
    final s = controller.session!;
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.tenant.appName),
        actions: [
          IconButton(
            onPressed: controller.syncNow,
            icon: const Icon(Icons.sync),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') controller.logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.syncNow,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(s.user.name, style: Theme.of(context).textTheme.headlineSmall),
            Text(
              [
                s.user.department,
                s.user.designation,
              ].whereType<String>().join(' · '),
            ),
            const SizedBox(height: 20),
            const Text(
              'My Responsibilities',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 10),
            if (s.modules.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No responsibilities assigned yet.'),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: s.modules.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (c, i) {
                  final m = s.modules[i];
                  return Card(
                    child: InkWell(
                      onTap: () => Navigator.of(c).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DynamicCapabilityScreen(capability: m),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.extension_outlined),
                            const Spacer(),
                            Text(
                              m.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(m.type, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
