import 'package:flutter/material.dart';

import '../config/tenant_config.dart';
import '../design/app_design.dart';

abstract final class TenantTheme {
  static ThemeData build(TenantConfig tenant) {
    // Tenant identity remains available to logos/content.
    //
    // The runtime UI itself deliberately uses the BRIXTA editorial
    // system so every company gets one coherent professional product.
    return AppDesign.theme();
  }
}
