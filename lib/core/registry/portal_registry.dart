import 'package:flutter/material.dart';

class PortalDefinition {
  const PortalDefinition({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.roleCode,
    required this.icon,
    this.enabled = true,
  });

  final String key;
  final String label;
  final String subtitle;
  final String roleCode;
  final IconData icon;
  final bool enabled;
}

abstract final class PortalRegistry {
  static const all = <PortalDefinition>[
    PortalDefinition(
      key: 'employee',
      label: 'Employee Login',
      subtitle: 'Field sales and operations',
      roleCode: 'EMPLOYEE',
      icon: Icons.badge_outlined,
    ),

    // Integration-first:
    // Enable any portal by setting enabled: true.
    // The generic LoginScreen already knows how to consume PortalDefinition.
    PortalDefinition(
      key: 'asm',
      label: 'ASM Login',
      subtitle: 'Area Sales Manager',
      roleCode: 'ASM',
      icon: Icons.manage_accounts_outlined,
      enabled: false,
    ),
    PortalDefinition(
      key: 'distributor',
      label: 'Distributor Login',
      subtitle: 'Channel partner',
      roleCode: 'DISTRIBUTOR',
      icon: Icons.storefront_outlined,
      enabled: false,
    ),
    PortalDefinition(
      key: 'super_stockist',
      label: 'Super Stockist Login',
      subtitle: 'Primary channel partner',
      roleCode: 'SUPER_STOCKIST',
      icon: Icons.warehouse_outlined,
      enabled: false,
    ),
    PortalDefinition(
      key: 'admin',
      label: 'Admin Login',
      subtitle: 'Tenant administration',
      roleCode: 'ADMIN',
      icon: Icons.admin_panel_settings_outlined,
      enabled: false,
    ),
  ];

  static List<PortalDefinition> get enabledForInitialRelease =>
      all.where((portal) => portal.enabled).toList(growable: false);
}
