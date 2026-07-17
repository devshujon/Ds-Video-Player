import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../domain/photo_grouper.dart';

enum GalleryStatus { idle, loading, ready, denied }

/// Albums + photos straight from the device gallery. Thumbnails are loaded
/// lazily by the tile widget (bounded byte cache) to keep RAM low.
class PhotoGalleryProvider extends ChangeNotifier {
  static const PhotoGrouper _grouper = PhotoGrouper();

  GalleryStatus status = GalleryStatus.idle;
  List<AssetPathEntity> albums = [];
  List<AssetEntity> currentAlbumAssets = [];
  AssetPathEntity? selectedAlbum;

  /// [currentAlbumAssets] bucketed into Today / Yesterday / This week /
  /// Earlier this month / "Month Year" sections, newest first.
  List<PhotoSection<AssetEntity>> sections = const [];

  Future<void> load() async {
    status = GalleryStatus.loading;
    notifyListeners();

    final ps = await PhotoManager.requestPermissionExtend();
    if (!(ps.isAuth || ps.hasAccess)) {
      status = GalleryStatus.denied;
      notifyListeners();
      return;
    }

    albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
      ),
    );
    if (albums.isNotEmpty) {
      await selectAlbum(albums.first);
    }
    status = GalleryStatus.ready;
    notifyListeners();
  }

  Future<void> selectAlbum(AssetPathEntity album) async {
    selectedAlbum = album;
    final count = await album.assetCountAsync;
    currentAlbumAssets = await album.getAssetListRange(start: 0, end: count);
    sections = _grouper.group(
      currentAlbumAssets,
      (a) => a.createDateTime.millisecondsSinceEpoch,
    );
    notifyListeners();
  }
}

