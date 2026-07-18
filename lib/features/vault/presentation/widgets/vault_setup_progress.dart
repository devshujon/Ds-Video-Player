import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Step progress indicator for the vault PIN setup wizard.
class VaultSetupProgress extends StatelessWidget {
  const VaultSetupProgress({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i <= current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: EdgeInsets.only(right: i == total - 1 ? 0 : 8),
          width: active ? 28 : 8,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active
                ? AppColors.brandPrimary
                : scheme.surfaceContainerHighest,
          ),
        );
      }),
    );
  }
}
