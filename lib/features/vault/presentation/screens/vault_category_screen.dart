import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/vault_category.dart';
import '../../domain/entities/vault_item.dart';
import '../providers/vault_provider.dart';
import '../widgets/vault_empty_state.dart';
import '../widgets/vault_item_tile.dart';

class VaultCategoryScreen extends StatelessWidget {
  const VaultCategoryScreen({super.key, required this.category});

  final VaultCategory category;

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final items = vault.itemsForCategory(category);

    return Scaffold(
      appBar: AppBar(title: Text(category.title)),
      body: items.isEmpty
          ? VaultEmptyState(
              title: 'No ${category.title.toLowerCase()}',
              subtitle: 'Files you lock will appear here instantly.',
              onMoveFiles: () => Navigator.pop(context),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => VaultItemTile(
                item: items[i],
                onRestore: () => _restore(context, items[i]),
                onExport: () => _export(context, items[i]),
                onDelete: () => _delete(context, items[i]),
              ),
            ),
    );
  }

  Future<void> _restore(BuildContext context, VaultItem item) async {
    final out = await context.read<VaultProvider>().restoreItem(item);
    if (out != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored to ${out.path}')),
      );
    }
  }

  Future<void> _export(BuildContext context, VaultItem item) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = File(p.join(dir.path, 'exports', item.originalName));
    if (!context.mounted) return;
    final out = await context.read<VaultProvider>().exportFile(item, dest);
    if (out != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to ${out.path}')),
      );
    }
  }

  Future<void> _delete(BuildContext context, VaultItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete from vault?'),
        content: Text('"${item.originalName}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<VaultProvider>().delete(item);
    }
  }
}
