import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../../core/utils/formatters.dart';
import '../../../media_library/presentation/providers/media_library_provider.dart';
import '../../data/storage_analyzer.dart';
import '../providers/storage_cleaner_provider.dart';

class StorageCleanerScreen extends StatelessWidget {
  const StorageCleanerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StorageCleanerProvider(sl<StorageAnalyzer>()),
      child: const _StorageCleanerView(),
    );
  }
}

class _StorageCleanerView extends StatelessWidget {
  const _StorageCleanerView();

  List<MediaFileInfo> _files(BuildContext context) {
    final lib = context.read<MediaLibraryProvider>();
    return [
      for (final m in [...lib.videos, ...lib.audios])
        MediaFileInfo(
          path: m.uri,
          type: m.type == MediaType.audio ? 'audio' : 'video',
          size: m.sizeBytes,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage cleaner')),
      body: Consumer<StorageCleanerProvider>(
        builder: (context, cleaner, _) {
          switch (cleaner.status) {
            case StorageCleanerStatus.idle:
              return _IdleView(
                onAnalyze: () => cleaner.analyze(_files(context)),
              );
            case StorageCleanerStatus.analyzing:
              return const Center(child: CircularProgressIndicator());
            case StorageCleanerStatus.done:
              return _ReportView(cleaner: cleaner);
          }
        },
      ),
      bottomNavigationBar: Consumer<StorageCleanerProvider>(
        builder: (context, cleaner, _) {
          if (cleaner.status != StorageCleanerStatus.done ||
              cleaner.selectedCount == 0) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  'Delete ${cleaner.selectedCount} · '
                  'free ${Formatters.fileSize(cleaner.reclaimableBytes)}',
                ),
                onPressed: () => _confirmDelete(context, cleaner),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    StorageCleanerProvider cleaner,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete files?'),
        content: Text(
          '${cleaner.selectedCount} file(s) will be permanently deleted, '
          'freeing ${Formatters.fileSize(cleaner.reclaimableBytes)}.',
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
    if (ok != true) return;
    final removed = await cleaner.deleteSelected();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $removed file(s)')),
      );
    }
  }
}

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cleaning_services_outlined, size: 56),
          const SizedBox(height: 12),
          const Text('See what is using your storage'),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Analyze'),
            onPressed: onAnalyze,
          ),
        ],
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.cleaner});
  final StorageCleanerProvider cleaner;

  @override
  Widget build(BuildContext context) {
    final report = cleaner.report!;
    return ListView(
      children: [
        _SummaryCard(report: report),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Largest files',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (report.largest.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nothing to clean')),
          )
        else
          ...report.largest.map(
            (f) => CheckboxListTile(
              dense: true,
              value: cleaner.isSelected(f.path),
              onChanged: (_) =>
                  context.read<StorageCleanerProvider>().toggle(f.path),
              secondary: Icon(
                f.type == 'audio'
                    ? Icons.music_note_outlined
                    : Icons.movie_outlined,
              ),
              title: Text(
                f.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(Formatters.fileSize(f.size)),
            ),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});
  final StorageReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final video = report.bytesByType['video'] ?? 0;
    final audio = report.bytesByType['audio'] ?? 0;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formatters.fileSize(report.totalBytes),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
            ),
            Text(
              'across ${report.fileCount} media files',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _TypeBar(
              label: 'Videos',
              bytes: video,
              total: report.totalBytes,
              color: scheme.primary,
            ),
            const SizedBox(height: 6),
            _TypeBar(
              label: 'Audio',
              bytes: audio,
              total: report.totalBytes,
              color: scheme.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeBar extends StatelessWidget {
  const _TypeBar({
    required this.label,
    required this.bytes,
    required this.total,
    required this.color,
  });
  final String label;
  final int bytes;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : bytes / total;
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              color: color,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(Formatters.fileSize(bytes)),
      ],
    );
  }
}
