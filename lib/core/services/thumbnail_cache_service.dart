import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// Disk-backed thumbnail cache keyed by media URI. Keeps scrolling smooth by
/// never blocking the UI thread on generation — callers write asynchronously.
class ThumbnailCacheService {
  ThumbnailCacheService();

  Directory? _cacheDir;
  final Map<String, String> _memory = {};

  Future<Directory> _dir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationCacheDirectory();
    _cacheDir = Directory(p.join(base.path, 'thumbnails'));
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  String _keyFor(String uri) =>
      sha256.convert(uri.codeUnits).toString().substring(0, 24);

  String? pathInMemory(String uri) => _memory[uri];

  Future<String?> pathFor(String uri) async {
    final hit = _memory[uri];
    if (hit != null && await File(hit).exists()) return hit;

    final file = File(p.join((await _dir()).path, '${_keyFor(uri)}.jpg'));
    if (await file.exists()) {
      _memory[uri] = file.path;
      return file.path;
    }
    return null;
  }

  Future<String?> save(String uri, Uint8List bytes) async {
    final file = File(p.join((await _dir()).path, '${_keyFor(uri)}.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    _memory[uri] = file.path;
    return file.path;
  }

  int get targetSize => AppConstants.thumbnailSizePx;
}
