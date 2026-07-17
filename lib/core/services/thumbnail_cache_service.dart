import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../logging/app_log.dart';

/// Disk-backed thumbnail cache keyed by media URI. LRU memory cap and disk
/// byte limit keep storage bounded on large libraries.
class ThumbnailCacheService {
  ThumbnailCacheService({Directory? overrideDir}) : _overrideDir = overrideDir;

  final Directory? _overrideDir;
  Directory? _cacheDir;
  final Map<String, String> _memory = {};
  final List<String> _lru = [];

  Future<Directory> _dir() async {
    final existing = _cacheDir;
    if (existing != null) return existing;
    if (_overrideDir != null) {
      final dir = _overrideDir;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    }
    final base = await getApplicationCacheDirectory();
    final dir = Directory(p.join(base.path, 'thumbnails'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  String _keyFor(String uri) =>
      sha256.convert(uri.codeUnits).toString().substring(0, 24);

  void _touchMemory(String uri) {
    _lru.remove(uri);
    _lru.add(uri);
    while (_lru.length > AppConstants.thumbnailMaxMemoryEntries) {
      final evict = _lru.removeAt(0);
      _memory.remove(evict);
    }
  }

  String? pathInMemory(String uri) => _memory[uri];

  Future<String?> pathFor(String uri) async {
    final hit = _memory[uri];
    if (hit != null && await File(hit).exists()) {
      _touchMemory(uri);
      return hit;
    }

    final file = File(p.join((await _dir()).path, '${_keyFor(uri)}.jpg'));
    if (await file.exists()) {
      _memory[uri] = file.path;
      _touchMemory(uri);
      return file.path;
    }
    return null;
  }

  Future<String?> save(String uri, Uint8List bytes) async {
    try {
      final file = File(p.join((await _dir()).path, '${_keyFor(uri)}.jpg'));
      await file.writeAsBytes(bytes, flush: true);
      _memory[uri] = file.path;
      _touchMemory(uri);
      await _evictDiskIfNeeded();
      return file.path;
    } catch (e, st) {
      AppLog.warn('Thumbnail save failed', e, st);
      return null;
    }
  }

  Future<void> purgeStale() async {
    try {
      final dir = await _dir();
      final cutoff =
          DateTime.now().subtract(AppConstants.thumbnailMaxAge);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
      _memory.removeWhere((_, path) => !File(path).existsSync());
      _lru.removeWhere((uri) => !_memory.containsKey(uri));
      await _evictDiskIfNeeded();
    } catch (e, st) {
      AppLog.warn('Thumbnail purge failed', e, st);
    }
  }

  Future<int> diskUsageBytes() async {
    var total = 0;
    final dir = await _dir();
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> _evictDiskIfNeeded() async {
    final dir = await _dir();
    final files = <File>[];
    await for (final entity in dir.list()) {
      if (entity is File) files.add(entity);
    }
    files.sort(
      (a, b) => a.statSync().accessed.compareTo(b.statSync().accessed),
    );

    var total = 0;
    for (final f in files) {
      total += await f.length();
    }

    while (total > AppConstants.thumbnailMaxDiskBytes && files.isNotEmpty) {
      final oldest = files.removeAt(0);
      total -= await oldest.length();
      await oldest.delete();
    }

    _memory.removeWhere((_, path) => !File(path).existsSync());
    _lru.removeWhere((uri) => !_memory.containsKey(uri));
  }

  int get targetSize => AppConstants.thumbnailSizePx;
}
