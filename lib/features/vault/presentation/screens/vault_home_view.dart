import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/vault_category.dart';
import '../providers/vault_provider.dart';
import '../widgets/vault_category_card.dart';
import '../widgets/vault_empty_state.dart';
import '../widgets/vault_skeleton.dart';

class VaultHomeView extends StatelessWidget {
  const VaultHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();

    if (vault.isLoading) {
      return const VaultSkeleton();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: vault.totalItemCount == 0
          ? VaultEmptyState(
              key: const ValueKey('empty'),
              onMoveFiles: () => _showMoveHint(context),
            )
          : ListView.separated(
              key: const ValueKey('categories'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: VaultCategory.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final category = VaultCategory.values[i];
                final count = vault.categoryCounts[category.id] ?? 0;
                return VaultCategoryCard(
                  category: category,
                  count: count,
                  onTap: () => Navigator.of(context).pushNamed(
                    Routes.vaultCategory,
                    arguments: category,
                  ),
                );
              },
            ),
    );
  }

  static void _showMoveHint(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Move files to vault',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Long-press any video, photo, or audio in your library, then choose '
              '"Move to Private Vault". You can also import files with the button below.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                pickAndImport(context);
              },
              child: const Text('Import files'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> pickAndImport(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (res == null || !context.mounted) return;

    for (final f in res.files) {
      final path = f.path;
      if (path == null) continue;
      if (!context.mounted) return;
      await context.read<VaultProvider>().importFile(File(path));
    }
  }
}
