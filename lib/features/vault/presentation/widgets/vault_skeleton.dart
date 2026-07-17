import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class VaultSkeleton extends StatelessWidget {
  const VaultSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Shimmer.fromColors(
      baseColor: base.withValues(alpha: 0.45),
      highlightColor: base.withValues(alpha: 0.9),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 88,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }
}
