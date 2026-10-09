import 'package:flutter/material.dart';

import '../core/session/app_session_controller.dart';
import '../core/theme/tenant_theme.dart';
import '../core/widgets/editorial_backdrop.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/employee_dashboard_screen.dart';

class BrixtaApp extends StatefulWidget {
  const BrixtaApp({super.key, required this.controller});

  final AppSessionController controller;

  @override
  State<BrixtaApp> createState() => _BrixtaAppState();
}

class _BrixtaAppState extends State<BrixtaApp> {
  late bool _signedIn;

  @override
  void initState() {
    super.initState();
    _signedIn = widget.controller.session != null;
    widget.controller.addListener(_onSessionChanged);
  }

  void _onSessionChanged() {
    final next = widget.controller.session != null;
    if (next != _signedIn && mounted) {
      setState(() => _signedIn = next);
    }
  }

  @override
  void didUpdateWidget(covariant BrixtaApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onSessionChanged);
      _signedIn = widget.controller.session != null;
      widget.controller.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      restorationScopeId: 'brixta_app',
      debugShowCheckedModeBanner: false,

      title: widget.controller.tenant.appName,

      theme: TenantTheme.build(widget.controller.tenant),

      builder: (context, child) {
        return EditorialBackdrop(child: child ?? const SizedBox.shrink());
      },

      home: !_signedIn
          ? LoginScreen(controller: widget.controller)
          : EmployeeDashboardScreen(controller: widget.controller),
    );
  }
}
