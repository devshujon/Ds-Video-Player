import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/constants/media_formats.dart';
import '../../domain/entities/media_folder.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/usecases/library_usecases.dart';

enum LibraryStatus { idle, loadingCache, scanning, ready, permissionDenied, error }

enum MediaSort { dateDesc, nameAsc, sizeDesc, durationDesc }

enum LibraryViewMode { list, grid }

class MediaLibraryProvider extends ChangeNotifier {
  MediaLibraryProvider({
    required ScanMediaProgressive scanProgressive,
    required GetMediaByType getByType,
    required GetFolders getFolders,
    required GetFavorites getFavorites,
    required GetRecentlyPlayed getRecentlyPlayed,
    required ToggleFavorite toggleFavorite,
  })  : _scanProgressive = scanProgressive,
        _byType = getByType,
        _folders = getFolders,
        _favs = getFavorites,
        _recent = getRecentlyPlayed,
        _toggleFav = toggleFavorite;

  final ScanMediaProgressive _scanProgressive;
  final GetMediaByType _byType;
  final GetFolders _folders;
  final GetFavorites _favs;
  final GetRecentlyPlayed _recent;
  final ToggleFavorite _toggleFav;

  LibraryStatus status = LibraryStatus.idle;
  String? errorMessage;
  MediaSort sort = MediaSort.dateDesc;
  LibraryViewMode viewMode = LibraryViewMode.list;
  int scannedCount = 0;
  bool _scanRunning = false;
  Future<void>? _cacheFuture;

  List<MediaItem> videos = [];
  List<MediaItem> audios = [];
  List<MediaFolder> folders = [];
  List<MediaItem> favorites = [];
  List<MediaItem> recent = [];

  bool get hasCachedContent =>
      videos.isNotEmpty || recent.isNotEmpty || favorites.isNotEmpty;

  /// Videos with saved resume positions — ordered by last played.
  List<MediaItem> get continueWatching => recent
      .where((m) => m.hasResume && m.type == MediaType.video)
      .take(10)
      .toList(growable: false);

  /// Last played videos regardless of resume position.
  List<MediaItem> get recentlyPlayed => recent
      .where((m) => m.type == MediaType.video)
      .take(12)
      .toList(growable: false);

  /// Newest items in the library by date added.
  List<MediaItem> get recentlyAdded {
    final copy = [...videos];
    copy.sort((a, b) => b.dateAddedMs.compareTo(a.dateAddedMs));
    return copy.take(12).toList(growable: false);
  }

  /// Fast path: read SQLite cache only. Called before navigating to home.
  /// Safe to call multiple times — subsequent callers await the same future.
  Future<void> loadFromCache() =>
      _cacheFuture ??= _loadFromCacheImpl();

  Future<void> _loadFromCacheImpl() async {
    status = LibraryStatus.loadingCache;
    notifyListeners();
    await _refreshFromCache();
    status = hasCachedContent ? LibraryStatus.ready : LibraryStatus.idle;
    notifyListeners();
  }

  /// Starts MediaStore scan without blocking the UI thread.
  void startBackgroundScan() {
    if (_scanRunning) return;
    unawaited(rescan());
  }

  Future<void> bootstrap() async {
    await loadFromCache();
    startBackgroundScan();
  }

  Future<void> rescan({bool force = true}) async {
    if (_scanRunning) return;
    _scanRunning = true;
    status = LibraryStatus.scanning;
    scannedCount = 0;
    notifyListeners();

    try {
      await for (final result in _scanProgressive()) {
        await result.fold(
          (f) async {
            status = f.runtimeType.toString().contains('Permission')
                ? LibraryStatus.permissionDenied
                : LibraryStatus.error;
            errorMessage = f.message;
            notifyListeners();
          },
          (batch) async {
            scannedCount = batch.scannedCount;
            await _refreshFromCache();
            if (batch.done) {
              status = LibraryStatus.ready;
            }
            notifyListeners();
          },
        );
        if (status == LibraryStatus.permissionDenied ||
            status == LibraryStatus.error) {
          break;
        }
      }
    } finally {
      _scanRunning = false;
      if (status == LibraryStatus.scanning) {
        status = LibraryStatus.ready;
      }
      notifyListeners();
    }
  }

  Future<void> _refreshFromCache() async {
    final videoRes = await _byType(MediaType.video);
    final audioRes = await _byType(MediaType.audio);
    final folderRes = await _folders();
    final favRes = await _favs();
    final recentRes = await _recent();

    videos = _sorted(videoRes.valueOrNull ?? videos);
    audios = _sorted(audioRes.valueOrNull ?? audios);
    folders = folderRes.valueOrNull ?? folders;
    favorites = favRes.valueOrNull ?? favorites;
    recent = recentRes.valueOrNull ?? recent;
  }

  void setSort(MediaSort s) {
    sort = s;
    videos = _sorted(videos);
    audios = _sorted(audios);
    notifyListeners();
  }

  void toggleViewMode() {
    viewMode = viewMode == LibraryViewMode.list
        ? LibraryViewMode.grid
        : LibraryViewMode.list;
    notifyListeners();
  }

  List<MediaItem> _sorted(List<MediaItem> list) {
    final copy = [...list];
    switch (sort) {
      case MediaSort.dateDesc:
        copy.sort((a, b) => b.dateAddedMs.compareTo(a.dateAddedMs));
      case MediaSort.nameAsc:
        copy.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case MediaSort.sizeDesc:
        copy.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case MediaSort.durationDesc:
        copy.sort((a, b) => b.durationMs.compareTo(a.durationMs));
    }
    return copy;
  }

  Future<void> toggleFavorite(MediaItem item) async {
    await _toggleFav(item.uri);
    await _refreshFromCache();
    notifyListeners();
  }

  List<MediaItem> itemsInFolder(String path) =>
      videos.where((v) => v.folderPath == path).toList();
}
