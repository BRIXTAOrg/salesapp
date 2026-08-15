import 'package:flutter/material.dart';

import '../../../core/registry/portal_registry.dart';
import '../../../core/session/app_session_controller.dart';
import '../../../core/widgets/tenant_logo.dart';
import 'login_screen.dart';

class PortalGatewayScreen extends StatelessWidget {
  const PortalGatewayScreen({
    super.key,
    required this.controller,
  });

  final AppSessionController controller;

  @override
  Widget build(BuildContext context) {
    final portals = PortalRegistry.enabledForInitialRelease;

    return Scaffold(
      backgroundColor: controller.tenant.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  Text(
                    'Welcome to ${controller.tenant.displayName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: 110,
                    height: 2,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 54),
                  TenantLogo(tenant: controller.tenant),
                  const SizedBox(height: 58),
                  ...portals.map(
                    (portal) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PortalButton(
                        portal: portal,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LoginScreen(
                                controller: controller,
                                portal: portal,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalButton extends StatelessWidget {
  const _PortalButton({
    required this.portal,
    required this.onTap,
  });

  final PortalDefinition portal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF484D5B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(portal.icon, color: Colors.white, size: 29),
              const SizedBox(width: 16),
              Container(width: 1, height: 40, color: Colors.white70),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  portal.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
