import 'package:flutter/material.dart';

import '../core/session/app_session_controller.dart';
import '../core/theme/tenant_theme.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/employee_dashboard_screen.dart';

class BrixtaApp extends StatelessWidget {
  const BrixtaApp({super.key, required this.controller});

  final AppSessionController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: controller.tenant.appName,
          theme: TenantTheme.build(controller.tenant),
          home: controller.session == null
              ? LoginScreen(controller: controller)
              : EmployeeDashboardScreen(controller: controller),
        );
      },
    );
  }
}
