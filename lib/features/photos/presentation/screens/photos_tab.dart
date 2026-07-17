import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/route_names.dart';
import '../providers/photo_gallery_provider.dart';
import 'photo_viewer_screen.dart';

class PhotosTab extends StatefulWidget {
  const PhotosTab({super.key});

  @override
  State<PhotosTab> createState() => _PhotosTabState();
}

class _PhotosTabState extends State<PhotosTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PhotoGalleryProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PhotoGalleryProvider>(
      builder: (context, g, _) {
        if (g.status == GalleryStatus.loading ||
            g.status == GalleryStatus.idle) {
          return const Center(child: CircularProgressIndicator());
        }
        if (g.status == GalleryStatus.denied) {
          return const Center(child: Text('Photo permission required'));
        }
        if (g.sections.isEmpty) {
          return const Center(child: Text('No photos found'));
        }

        // Flat, section-ordered list so the viewer can swipe the whole album.
        final flat = <AssetEntity>[
          for (final section in g.sections) ...section.items,
        ];

        final slivers = <Widget>[];
        var offset = 0;
        for (final section in g.sections) {
          final sectionStart = offset;
          slivers.add(
            SliverToBoxAdapter(
              child: _SectionHeader(
                label: section.label,
                count: section.items.length,
              ),
            ),
          );
          slivers.add(
            SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final asset = section.items[i];
                  final globalIndex = sectionStart + i;
                  return RepaintBoundary(
                    child: _PhotoCell(
                      asset: asset,
                      onTap: () => Navigator.pushNamed(
                        context,
                        Routes.photoViewer,
                        arguments: PhotoViewerArgs(
                          assets: flat,
                          index: globalIndex,
                        ),
                      ),
                    ),
                  );
                },
                childCount: section.items.length,
              ),
            ),
          );
          offset += section.items.length;
        }

        return CustomScrollView(
          slivers: [
            ...slivers,
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.asset, required this.onTap});
  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder(
        future: asset.thumbnailDataWithSize(
          const ThumbnailSize.square(256),
        ),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            );
          }
          return Image.memory(
            snap.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        },
      ),
    );
  }
}
