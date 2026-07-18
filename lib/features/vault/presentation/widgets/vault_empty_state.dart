import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class VaultEmptyState extends StatelessWidget {
  const VaultEmptyState({
    super.key,
    required this.onMoveFiles,
    this.title = 'No private files yet',
    this.subtitle =
        'Move sensitive videos, photos, and documents into your encrypted vault.',
  });

  final VoidCallback onMoveFiles;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 72,
                color: scheme.primary.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onMoveFiles,
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('Move Files'),
            ),
          ],
        ),
      ),
    );
  }
}
