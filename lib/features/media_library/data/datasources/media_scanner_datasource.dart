import 'dart:async';

import 'package:photo_manager/photo_manager.dart';

import '../../../../core/constants/media_formats.dart';
import '../../../../core/services/thumbnail_cache_service.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/scan_batch.dart';

/// Reads Android MediaStore via photo_manager — never walks the filesystem.
/// Yields progressively so the library appears while scanning continues.
class MediaScannerDataSource {
  MediaScannerDataSource(this._thumbnails);

  final ThumbnailCacheService _thumbnails;

  Future<bool> ensurePermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }

  /// Legacy full scan kept for tests and callers that need a complete list.
  Future<List<MediaItem>> scanDevice() async {
    final results = <MediaItem>[];
    await for (final batch in scanDeviceProgressive()) {
      results.addAll(batch.items);
    }
    return results;
  }

  Stream<ScanBatch> scanDeviceProgressive() async* {
    const pageSize = 300;
    var scanned = 0;
    final pending = <MediaItem>[];

    final buckets = <(RequestType, MediaType)>[
      (RequestType.video, MediaType.video),
      (RequestType.audio, MediaType.audio),
      (RequestType.image, MediaType.image),
    ];

    for (final (req, type) in buckets) {
      final paths = await PhotoManager.getAssetPathList(
        type: req,
        onlyAll: true,
      );
      if (paths.isEmpty) continue;

      final album = paths.first;
      final total = await album.assetCountAsync;

      for (var page = 0; page * pageSize < total; page++) {
        final assets =
            await album.getAssetListPaged(page: page, size: pageSize);

        for (final asset in assets) {
          final item = await _assetToItem(asset, type);
          if (item == null) continue;
          pending.add(item);
          scanned++;

          if (pending.length >= 50) {
            yield ScanBatch(
              items: List<MediaItem>.from(pending),
              scannedCount: scanned,
              done: false,
            );
            pending.clear();
            await Future<void>.delayed(Duration.zero);
          }
        }
      }
    }

    yield ScanBatch(
      items: List<MediaItem>.from(pending),
      scannedCount: scanned,
      done: true,
    );
  }

  Future<MediaItem?> _assetToItem(AssetEntity asset, MediaType type) async {
    final file = await asset.originFile;
    if (file == null) return null;

    final path = file.path;
    final slash = path.lastIndexOf('/');
    final folder = slash >= 0 ? path.substring(0, slash) : path;
    final title = asset.title?.trim();
    final sizeBytes = await asset.fileSize;

    String? thumbPath;
    if (type == MediaType.video) {
      thumbPath = await _thumbnails.pathFor(path);
      if (thumbPath == null) {
        unawaited(_generateThumb(asset, path));
      }
    }

    return MediaItem(
      uri: path,
      title: title != null && title.isNotEmpty ? title : path.split('/').last,
      type: type,
      folderPath: folder,
      sizeBytes: sizeBytes,
      durationMs: asset.duration * 1000,
      width: asset.width == 0 ? null : asset.width,
      height: asset.height == 0 ? null : asset.height,
      mimeType: asset.mimeType,
      dateAddedMs: asset.createDateTime.millisecondsSinceEpoch,
      dateModifiedMs: asset.modifiedDateTime.millisecondsSinceEpoch,
      thumbPath: thumbPath,
    );
  }

  Future<void> _generateThumb(AssetEntity asset, String uri) async {
    final bytes = await asset.thumbnailDataWithSize(
      ThumbnailSize(_thumbnails.targetSize, _thumbnails.targetSize),
      quality: 80,
    );
    if (bytes != null) {
      await _thumbnails.save(uri, bytes);
    }
  }
}
