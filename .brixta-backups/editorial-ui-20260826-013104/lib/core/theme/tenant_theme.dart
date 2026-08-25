import 'package:flutter/material.dart';

import '../config/tenant_config.dart';
import '../design/app_design.dart';

abstract final class TenantTheme {
  static ThemeData build(TenantConfig tenant) {
    final base = AppDesign.theme();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: tenant.primaryColor,
      ),
    );
  }
}
