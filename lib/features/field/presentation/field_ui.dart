import 'package:flutter/material.dart';

import '../../../core/design/app_design.dart';

// BRIXTA_FIELD_APP_V1 — small pieces shared by the field screens.
// Built only from AppDesign tokens so they match the rest of the app.

class FieldTone {
  const FieldTone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static FieldTone of(String tone) {
    switch (tone) {
      case 'info':
        return const FieldTone(AppDesign.softBlue, Color(0xFF2F4F6B));
      case 'good':
        return const FieldTone(AppDesign.softGreen, AppDesign.greenDark);
      case 'warning':
        return const FieldTone(AppDesign.softAmber, AppDesign.amber);
      case 'danger':
        return const FieldTone(AppDesign.softRed, AppDesign.red);
      default:
        return const FieldTone(AppDesign.softGray, AppDesign.muted);
    }
  }
}

class FieldStageChip extends StatelessWidget {
  const FieldStageChip({super.key, required this.label, required this.tone});

  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final colors = FieldTone.of(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppDesign.pillRadius),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppDesign.mono(
          size: 8,
          color: colors.foreground,
          weight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class FieldEyebrow extends StatelessWidget {
  const FieldEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppDesign.mono(
        size: 9,
        color: AppDesign.muted,
        weight: FontWeight.w600,
        letterSpacing: 1.8,
      ),
    );
  }
}

class FieldCard extends StatelessWidget {
  const FieldCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = AppDesign.white,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: AppDesign.line.withValues(alpha: .8)),
      ),
      child: child,
    );
  }
}

class FieldPill extends StatelessWidget {
  const FieldPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppDesign.ink : AppDesign.white,
      borderRadius: BorderRadius.circular(AppDesign.pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesign.pillRadius),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDesign.pillRadius),
            border: Border.all(
              color: selected ? AppDesign.ink : AppDesign.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppDesign.sans(
                  size: 14,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppDesign.white : AppDesign.ink,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: AppDesign.mono(
                    size: 10,
                    color: selected
                        ? AppDesign.white.withValues(alpha: .7)
                        : AppDesign.muted,
                    weight: FontWeight.w600,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String formatDistance(double? meters) {
  if (meters == null) return '';
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDay(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  final local = date.toLocal();
  final today = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final diff = day.difference(DateTime(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return '${local.day} ${_months[local.month - 1]}';
}

String formatWhen(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  final local = date.toLocal();
  final minutes = DateTime.now().difference(local).inMinutes;
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '$minutes min ago';
  if (minutes < 60 * 24) return '${minutes ~/ 60} h ago';
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_months[local.month - 1]}, $hh:$mm';
}
