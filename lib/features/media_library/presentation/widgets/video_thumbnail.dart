import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/constants/media_formats.dart';
import '../../../../core/services/thumbnail_cache_service.dart';
import '../../domain/entities/media_item.dart';

/// Async thumbnail tile — never blocks scroll. Checks disk cache first,
/// then generates from MediaStore in the background.
class VideoThumbnail extends StatefulWidget {
  const VideoThumbnail({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.iconSize = 36,
  });

  final MediaItem item;
  final double? width;
  final double? height;
  final double borderRadius;
  final double iconSize;

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  String? _path;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.uri != widget.item.uri) {
      _path = null;
      _loading = true;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final cache = sl<ThumbnailCacheService>();
    final cached = widget.item.thumbPath ?? await cache.pathFor(widget.item.uri);
    if (cached != null && await File(cached).exists()) {
      if (mounted) {
        setState(() {
          _path = cached;
          _loading = false;
        });
      }
      return;
    }

    if (widget.item.type == MediaType.video) {
      final entity = await _findAsset(widget.item.uri);
      if (entity != null) {
        final bytes = await entity.thumbnailDataWithSize(
          ThumbnailSize(cache.targetSize, cache.targetSize),
          quality: 80,
        );
        if (bytes != null) {
          final saved = await cache.save(widget.item.uri, bytes);
          if (mounted) {
            setState(() {
              _path = saved;
              _loading = false;
            });
          }
          return;
        }
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<AssetEntity?> _findAsset(String path) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );
    if (paths.isEmpty) return null;
    final album = paths.first;
    final total = await album.assetCountAsync;
    const page = 200;
    for (var i = 0; i * page < total; i++) {
      final assets = await album.getAssetListPaged(page: i, size: page);
      for (final a in assets) {
        final file = await a.originFile;
        if (file?.path == path) return a;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = widget.width ?? double.infinity;
    final h = widget.height ?? 96.0;

    Widget child;
    if (_path != null) {
      child = Image.file(
        File(_path!),
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _placeholder(scheme),
      );
    } else if (_loading) {
      child = Shimmer.fromColors(
        baseColor: scheme.surfaceContainerHighest,
        highlightColor: scheme.surfaceContainerHigh,
        child: Container(width: w, height: h, color: scheme.surfaceContainerHighest),
      );
    } else {
      child = _placeholder(scheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(width: w, height: h, child: child),
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        widget.item.type == MediaType.video
            ? Icons.movie_outlined
            : widget.item.type == MediaType.audio
                ? Icons.music_note_outlined
                : Icons.image_outlined,
        color: scheme.primary,
        size: widget.iconSize,
      ),
    );
  }
}
