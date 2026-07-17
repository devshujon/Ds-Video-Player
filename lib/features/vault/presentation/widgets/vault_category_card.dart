import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/vault_category.dart';
import 'vault_glass_card.dart';

class VaultCategoryCard extends StatelessWidget {
  const VaultCategoryCard({
    super.key,
    required this.category,
    required this.count,
    required this.onTap,
  });

  final VaultCategory category;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return VaultGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  AppColors.brandPrimary.withValues(alpha: 0.9),
                  AppColors.brandSecondary.withValues(alpha: 0.75),
                ],
              ),
            ),
            child: Icon(_iconFor(category), color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(VaultCategory c) => switch (c) {
        VaultCategory.videos => Icons.play_circle_rounded,
        VaultCategory.images => Icons.photo_library_rounded,
        VaultCategory.audio => Icons.headphones_rounded,
        VaultCategory.documents => Icons.description_rounded,
        VaultCategory.downloads => Icons.download_rounded,
        VaultCategory.folders => Icons.folder_rounded,
      };
}
