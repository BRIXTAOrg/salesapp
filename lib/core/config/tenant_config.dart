import 'package:flutter/material.dart';

class TenantConfig {
  const TenantConfig({
    required this.id,
    required this.code,
    required this.displayName,
    required this.appName,
    required this.primaryColor,
    required this.surfaceColor,
    required this.backgroundColor,
    required this.logoText,
    this.supportLabel = 'BRIXTA Support',
  });

  final String id;
  final String code;
  final String displayName;
  final String appName;
  final Color primaryColor;
  final Color surfaceColor;
  final Color backgroundColor;
  final String logoText;
  final String supportLabel;

  static const demo = TenantConfig(
    id: 'tenant-demo-cement',
    code: 'DEMO_CEMENT',
    displayName: 'BRIXTA Cement',
    appName: 'BRIXTA Field',
    primaryColor: Color(0xFF2563EB),
    surfaceColor: Color(0xFFFFFFFF),
    backgroundColor: Color(0xFFF9FAFB),
    logoText: 'B',
  );
}
