import 'package:flutter/foundation.dart';

import '../../data/playlist_repository.dart';

/// Route-scoped: owns one playlist's ordered item URIs. Created at the
/// [PlaylistDetailScreen]; the screen resolves URIs to media for display.
class PlaylistDetailProvider extends ChangeNotifier {
  PlaylistDetailProvider(this._repo, this.playlistId);

  final PlaylistRepository _repo;
  final int playlistId;

  // M1 — lifecycle guard: load()/reorder() can resolve after route pop.
  bool _disposed = false;

  List<String> uris = const [];
  bool isLoading = true;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    uris = await _repo.itemUris(playlistId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> addItems(List<String> newUris) async {
    await _repo.addItems(playlistId, newUris);
    await load();
  }

  Future<void> removeItem(String uri) async {
    await _repo.removeItem(playlistId, uri);
    uris = uris.where((u) => u != uri).toList(growable: false);
    notifyListeners();
  }

  /// Applies a drag-reorder optimistically, then persists the new order.
  /// Indices come from ReorderableListView's `onReorderItem` callback,
  /// which delivers a newIndex that's already adjusted for the removal
  /// at oldIndex — no manual `target -= 1` step needed.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...uris];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    uris = list;
    notifyListeners();
    await _repo.reorder(playlistId, list);
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
