import 'package:flutter/foundation.dart';

import '../../data/playlist_repository.dart';
import '../../domain/entities/playlist.dart';

/// App-scoped: owns the list of playlists. Per-playlist contents are
/// handled by the route-scoped [PlaylistDetailProvider].
class PlaylistsProvider extends ChangeNotifier {
  PlaylistsProvider(this._repo);
  final PlaylistRepository _repo;

  List<Playlist> playlists = const [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    playlists = await _repo.getAll();
    isLoading = false;
    notifyListeners();
  }

  Future<void> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repo.create(trimmed);
    await load();
  }

  Future<void> rename(Playlist playlist, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repo.rename(playlist.id, trimmed);
    await load();
  }

  Future<void> delete(Playlist playlist) async {
    await _repo.delete(playlist.id);
    await load();
  }

  /// Adds media to a playlist and refreshes counts. Used by the
  /// "add to playlist" entry points.
  Future<void> addToPlaylist(int playlistId, List<String> uris) async {
    await _repo.addItems(playlistId, uris);
    await load();
  }
}
