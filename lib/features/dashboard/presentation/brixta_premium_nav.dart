import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/design/brixta_feedback.dart';

class BrixtaPremiumNav extends StatelessWidget {
  const BrixtaPremiumNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    this.labels,
    this.icons,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  // BRIXTA_FIELD_APP_V1: the dashboard can add tabs (e.g. SITES).
  final List<String>? labels;
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final labels = this.labels ?? const ['HOME', 'WORK', 'ME'];

    final icons =
        this.icons ?? [AppIcons.home, AppIcons.work, AppIcons.profile];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Material(
        color: AppDesign.ink,
        borderRadius: BorderRadius.circular(34),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = index == selectedIndex;

              return Expanded(
                child: BrixtaPressScale(
                  scale: .94,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () async {
                      if (index == selectedIndex) {
                        return;
                      }

                      unawaited(BrixtaFeedback.selection());

                      onChanged(index);
                    },
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        height: 48,
                        constraints: const BoxConstraints(minWidth: 48),
                        padding: EdgeInsets.symmetric(
                          horizontal: selected ? 16 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppDesign.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icons[index],
                              size: 20,
                              color: selected
                                  ? AppDesign.ink
                                  : AppDesign.white.withValues(alpha: .72),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 9),
                              Text(
                                labels[index],
                                style: AppDesign.mono(
                                  size: 8,
                                  color: AppDesign.ink,
                                  weight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
