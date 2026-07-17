import 'package:flutter/foundation.dart';

import '../../../../core/constants/media_formats.dart';
import '../../domain/entities/media_folder.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/usecases/library_usecases.dart';

enum LibraryStatus { idle, scanning, ready, permissionDenied, error }

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

  List<MediaItem> videos = [];
  List<MediaItem> audios = [];
  List<MediaFolder> folders = [];
  List<MediaItem> favorites = [];
  List<MediaItem> recent = [];

  Future<void> bootstrap() async {
    await _refreshFromCache();
    await rescan();
  }

  Future<void> rescan({bool force = true}) async {
    status = LibraryStatus.scanning;
    scannedCount = 0;
    notifyListeners();

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
    notifyListeners();
  }

  Future<void> _refreshFromCache() async {
    videos = _sorted((await _byType(MediaType.video)).valueOrNull ?? videos);
    audios = _sorted((await _byType(MediaType.audio)).valueOrNull ?? audios);
    folders = (await _folders()).valueOrNull ?? folders;
    favorites = (await _favs()).valueOrNull ?? favorites;
    recent = (await _recent()).valueOrNull ?? recent;
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
