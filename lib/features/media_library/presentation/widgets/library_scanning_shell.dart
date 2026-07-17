import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Placeholder shell shown during first scan when the SQLite cache is empty.
/// Keeps the home layout visible instead of a blank spinner.
class LibraryScanningShell extends StatelessWidget {
  const LibraryScanningShell({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Building your library…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
        for (final title in ['Continue watching', 'Recent videos', 'Recently added'])
          SliverToBoxAdapter(
            child: _SkeletonSection(title: title, scheme: scheme),
          ),
      ],
    );
  }
}

class _SkeletonSection extends StatelessWidget {
  const _SkeletonSection({required this.title, required this.scheme});
  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: title == 'Continue watching' ? 168 : 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: scheme.surfaceContainerHighest,
                highlightColor: scheme.surfaceContainerHigh,
                child: Container(
                  width: title == 'Continue watching' ? 200 : 160,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
