import 'package:flutter/material.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';

/// Onboarding progress: the current dot stretches into a pill.
class PageDots extends StatelessWidget {
  const PageDots({required this.count, required this.index, super.key});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppDurations.medium,
              curve: Curves.easeOutBack,
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
              width: i == index ? 28 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i == index
                    ? context.colors.primary
                    : context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
        ],
      ),
    );
  }
}
