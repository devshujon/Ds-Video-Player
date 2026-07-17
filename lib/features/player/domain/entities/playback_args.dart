import '../../../media_library/domain/entities/media_item.dart';

/// Typed navigation argument for the player routes. A queue + start index
/// supports playlists, shuffle and "play all".
class PlaybackArgs {
  const PlaybackArgs({
    required this.queue,
    this.startIndex = 0,
    this.resumePositionMs = 0,
  });

  final List<MediaItem> queue;
  final int startIndex;
  final int resumePositionMs;

  MediaItem get current => queue[startIndex.clamp(0, queue.length - 1)];

  factory PlaybackArgs.single(MediaItem item) =>
      PlaybackArgs(queue: [item], resumePositionMs: item.resumePositionMs);
}
