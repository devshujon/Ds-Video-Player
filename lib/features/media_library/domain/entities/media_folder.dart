import 'package:equatable/equatable.dart';

/// An aggregated folder bucket derived from scanned [MediaItem]s.
class MediaFolder extends Equatable {
  const MediaFolder({
    required this.path,
    required this.itemCount,
    required this.isHidden,
    this.thumbPath,
  });

  final String path;
  final int itemCount;
  final bool isHidden;
  final String? thumbPath;

  String get name {
    final parts = path.split('/')..removeWhere((e) => e.isEmpty);
    return parts.isEmpty ? path : parts.last;
  }

  @override
  List<Object?> get props => [path];
}
