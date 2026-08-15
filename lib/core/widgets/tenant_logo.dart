import 'package:flutter/material.dart';

import '../config/tenant_config.dart';

class TenantLogo extends StatelessWidget {
  const TenantLogo({
    super.key,
    required this.tenant,
    this.size = 104,
  });

  final TenantConfig tenant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tenant.primaryColor,
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            offset: Offset(0, 9),
            color: Color(0x33000000),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tenant.logoText,
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w900,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'BRIXTA',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
