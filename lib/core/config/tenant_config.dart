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

  TenantConfig copyWith({String? code}) => TenantConfig(
        id: id,
        code: code ?? this.code,
        displayName: displayName,
        appName: appName,
        primaryColor: primaryColor,
        surfaceColor: surfaceColor,
        backgroundColor: backgroundColor,
        logoText: logoText,
        supportLabel: supportLabel,
      );

  static const demo = TenantConfig(
    id: 'tenant-demo-cement',
    code: 'companyname',
    displayName: 'Field Ops App',
    appName: 'BRIXTA Field Ops',
    primaryColor: Color(0xFF15803D),
    surfaceColor: Color(0xFFFFFFFF),
    backgroundColor: Color(0xFFF8FAF9),
    logoText: 'B',
  );   
}
