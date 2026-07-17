import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/vault_item.dart';

class VaultItemTile extends StatelessWidget {
  const VaultItemTile({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onDelete,
    required this.onExport,
  });

  final VaultItem item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = item.thumbPath;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 56,
          height: 56,
          child: thumb != null && File(thumb).existsSync()
              ? Image.file(File(thumb), fit: BoxFit.cover)
              : ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(_iconFor(item.type), color: scheme.primary),
                ),
        ),
      ),
      title: Text(
        item.originalName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: item.blobAvailable ? null : scheme.error,
        ),
      ),
      subtitle: Text(
        item.blobAvailable
            ? '${Formatters.fileSize(item.displaySizeBytes)}'
                '${item.durationMs > 0 ? ' · ${Formatters.durationMs(item.durationMs)}' : ''}'
            : 'Encrypted file missing — delete this entry',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => switch (v) {
          'restore' => onRestore(),
          'export' => onExport(),
          'delete' => onDelete(),
          _ => null,
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'restore', child: Text('Restore')),
          PopupMenuItem(value: 'export', child: Text('Export')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'video' => Icons.movie_rounded,
        'audio' => Icons.music_note_rounded,
        'image' => Icons.image_rounded,
        _ => Icons.insert_drive_file_rounded,
      };
}
