import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/formatters.dart';
import '../../models/media_index.dart';
import '../../providers/library_provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<LibraryProvider>().loadRecent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Scan now',
            icon: const Icon(Icons.refresh),
            onPressed: lib.isScanning
                ? null
                : context.read<LibraryProvider>().scan,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _ScanCard(lib: lib),
          if (lib.recentlyAdded.isNotEmpty)
            _RecentlyAddedSection(items: lib.recentlyAdded),
        ],
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.lib});
  final LibraryProvider lib;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.library_books, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Incremental scan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Re-scans only what changed since the last pass.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (lib.isScanning) ...[
                // Indeterminate while streaming (total isn't known up-front).
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  '${lib.filesScanned} files scanned · '
                  '${lib.newItemsFound} new · '
                  '${lib.updatedItems} updated',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else if (lib.lastSummary != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: scheme.onPrimaryContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scan complete · ${lib.lastSummary!}',
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: lib.isScanning
                      ? null
                      : () => context.read<LibraryProvider>().scan(),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(lib.isScanning ? 'Scanning…' : 'Scan now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentlyAddedSection extends StatelessWidget {
  const _RecentlyAddedSection({required this.items});
  final List<MediaIndex> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Recently added',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        SizedBox(
          height: 152,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final m = items[i];
              return SizedBox(
                width: 168,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 96,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _iconFor(m.mediaType),
                        color: scheme.primary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${Formatters.fileSize(m.size)}'
                      '${m.durationMs > 0 ? ' · ${Formatters.durationMs(m.durationMs)}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'video' => Icons.movie_outlined,
        'audio' => Icons.music_note_outlined,
        'image' => Icons.image_outlined,
        _ => Icons.insert_drive_file_outlined,
      };
}
