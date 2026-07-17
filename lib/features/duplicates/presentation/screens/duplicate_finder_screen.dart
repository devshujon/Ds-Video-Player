import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/utils/formatters.dart';
import '../../../media_library/presentation/providers/media_library_provider.dart';
import '../../data/duplicate_finder.dart';
import '../providers/duplicates_provider.dart';

class DuplicateFinderScreen extends StatelessWidget {
  const DuplicateFinderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DuplicatesProvider(sl<DuplicateFinder>()),
      child: const _DuplicateFinderView(),
    );
  }
}

class _DuplicateFinderView extends StatelessWidget {
  const _DuplicateFinderView();

  List<FileRef> _libraryFiles(BuildContext context) {
    final lib = context.read<MediaLibraryProvider>();
    return [
      for (final m in [...lib.videos, ...lib.audios])
        FileRef(path: m.uri, size: m.sizeBytes),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicate finder')),
      body: Consumer<DuplicatesProvider>(
        builder: (context, dup, _) {
          switch (dup.status) {
            case DuplicatesStatus.idle:
              return _IdleView(
                onScan: () =>
                    dup.scan(_libraryFiles(context)),
              );
            case DuplicatesStatus.scanning:
              return _ScanningView(progress: dup.progress);
            case DuplicatesStatus.done:
              return _ResultsView(dup: dup);
          }
        },
      ),
      bottomNavigationBar: Consumer<DuplicatesProvider>(
        builder: (context, dup, _) {
          if (dup.status != DuplicatesStatus.done ||
              dup.selectedCount == 0) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  'Delete ${dup.selectedCount} · '
                  'free ${Formatters.fileSize(dup.reclaimableBytes)}',
                ),
                onPressed: () => _confirmDelete(context, dup),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    DuplicatesProvider dup,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete duplicates?'),
        content: Text(
          '${dup.selectedCount} file(s) will be permanently deleted, '
          'freeing ${Formatters.fileSize(dup.reclaimableBytes)}.',
        ),
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
    if (confirm != true) return;
    final removed = await dup.deleteSelected();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $removed file(s)')),
      );
    }
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.file_copy_outlined, size: 56),
          const SizedBox(height: 12),
          const Text('Find duplicate videos & audio'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Compares files by size, then by a content fingerprint.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Scan now'),
            onPressed: onScan,
          ),
        ],
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              value: progress == 0 ? null : progress,
            ),
          ),
          const SizedBox(height: 12),
          Text('${(progress * 100).round()}%'),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({required this.dup});
  final DuplicatesProvider dup;

  @override
  Widget build(BuildContext context) {
    if (dup.groups.isEmpty) {
      return const Center(child: Text('No duplicates found 🎉'));
    }
    return ListView.builder(
      itemCount: dup.groups.length,
      itemBuilder: (context, i) {
        final group = dup.groups[i];
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '${group.paths.length} copies · '
                  '${Formatters.fileSize(group.sizeBytes)} each · '
                  'save ${Formatters.fileSize(group.reclaimableBytes)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ...group.paths.map(
                (path) => CheckboxListTile(
                  dense: true,
                  value: dup.isSelected(path),
                  onChanged: (_) =>
                      context.read<DuplicatesProvider>().toggle(path),
                  title: Text(
                    path.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
