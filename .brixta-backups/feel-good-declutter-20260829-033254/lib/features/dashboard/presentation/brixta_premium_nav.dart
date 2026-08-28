import 'package:flutter/material.dart';

import '../../../core/design/app_design.dart';
import '../../../core/design/app_icons.dart';

class BrixtaPremiumNav extends StatelessWidget {
  const BrixtaPremiumNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['HOME', 'WORK', 'ME'];

    final icons = [AppIcons.home, AppIcons.work, AppIcons.profile];

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Material(
        color: AppDesign.ink,
        borderRadius: BorderRadius.circular(34),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = index == selectedIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(index),
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
                        color: selected ? AppDesign.white : Colors.transparent,
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
              );
            }),
          ),
        ),
      ),
    );
  }
}
