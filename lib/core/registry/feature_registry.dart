import 'package:flutter/material.dart';

import '../../features/allowances/presentation/allowances_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/daily_status/presentation/daily_status_screen.dart';
import '../../features/enquiry/presentation/enquiry_form_screen.dart';
import '../../features/shared/presentation/placeholder_feature_screen.dart';

typedef FeatureScreenBuilder = Widget Function(
  BuildContext context,
  String employeeId,
);

class FeatureDefinition {
  const FeatureDefinition({
    required this.key,
    required this.title,
    required this.icon,
    required this.permission,
    required this.builder,
  });

  final String key;
  final String title;
  final IconData icon;
  final String permission;
  final FeatureScreenBuilder builder;
}

abstract final class FeatureRegistry {
  static final employeeModules = <FeatureDefinition>[
    FeatureDefinition(
      key: 'attendance',
      title: 'Attendance',
      icon: Icons.how_to_reg_outlined,
      permission: 'attendance.self.read',
      builder: (_, employeeId) =>
          AttendanceScreen(employeeId: employeeId),
    ),
    FeatureDefinition(
      key: 'daily_status',
      title: 'Daily Status',
      icon: Icons.assignment_turned_in_outlined,
      permission: 'daily_status.self.write',
      builder: (_, employeeId) =>
          DailyStatusScreen(employeeId: employeeId),
    ),
    FeatureDefinition(
      key: 'enquiry',
      title: 'Enquiry Form',
      icon: Icons.fact_check_outlined,
      permission: 'enquiry.self.create',
      builder: (_, employeeId) =>
          EnquiryFormScreen(employeeId: employeeId),
    ),
    FeatureDefinition(
      key: 'appointments',
      title: "Today's Appts",
      icon: Icons.calendar_month_outlined,
      permission: 'appointments.self.read',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: "Today's Appointments",
        icon: Icons.calendar_month_outlined,
        description: 'Daily dealer and customer appointment schedule.',
      ),
    ),
    FeatureDefinition(
      key: 'targets',
      title: 'Targets',
      icon: Icons.flag_outlined,
      permission: 'targets.self.read',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: 'Targets',
        icon: Icons.flag_outlined,
        description: 'Monthly, weekly and product-wise sales targets.',
      ),
    ),
    FeatureDefinition(
      key: 'history',
      title: 'History',
      icon: Icons.history_rounded,
      permission: 'history.self.read',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: 'History',
        icon: Icons.history_rounded,
        description: 'Historical visits, performance and field activity.',
      ),
    ),
    FeatureDefinition(
      key: 'allowances',
      title: 'Allowances',
      icon: Icons.currency_rupee_rounded,
      permission: 'claim.self.read',
      builder: (_, __) => const AllowancesScreen(),
    ),
    FeatureDefinition(
      key: 'notices',
      title: 'Notices',
      icon: Icons.campaign_outlined,
      permission: 'notices.self.read',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: 'Notices',
        icon: Icons.campaign_outlined,
        description: 'Management notices, circulars and announcements.',
      ),
    ),
    FeatureDefinition(
      key: 'route',
      title: 'Route Plan',
      icon: Icons.route_outlined,
      permission: 'route.self.read',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: 'Route Plan',
        icon: Icons.route_outlined,
        description: 'Assigned route, stops and daily visit sequence.',
      ),
    ),
    FeatureDefinition(
      key: 'leave',
      title: 'Leaves',
      icon: Icons.beach_access_outlined,
      permission: 'leave.self.create',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: 'Leaves',
        icon: Icons.beach_access_outlined,
        description: 'Apply for leave and track approval status.',
      ),
    ),
    FeatureDefinition(
      key: 'resignation',
      title: 'Resignation',
      icon: Icons.logout_rounded,
      permission: 'resignation.self.create',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: 'Resignation Form',
        icon: Icons.logout_rounded,
        description: 'Submit and track a resignation request.',
      ),
    ),
    FeatureDefinition(
      key: 'chat',
      title: 'Chat',
      icon: Icons.chat_bubble_outline_rounded,
      permission: 'chat.self.use',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: 'Chat',
        icon: Icons.chat_bubble_outline_rounded,
        description: 'Internal employee and manager communication.',
      ),
    ),
    FeatureDefinition(
      key: 'help',
      title: 'Help',
      icon: Icons.help_outline_rounded,
      permission: 'help.self.read',
      builder: (_, __) => const PlaceholderFeatureScreen(
        title: 'Help Section',
        icon: Icons.help_outline_rounded,
        description: 'Support requests, FAQs and escalation contacts.',
      ),
    ),
  ];
}
