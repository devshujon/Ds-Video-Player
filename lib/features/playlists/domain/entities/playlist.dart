import 'package:equatable/equatable.dart';

/// A user-created playlist. The ordered media live in `playlist_items`;
/// [itemCount] is a denormalised convenience filled by the repository.
class Playlist extends Equatable {
  const Playlist({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int itemCount;
  final int createdAt;
  final int updatedAt;

  Playlist copyWith({String? name, int? itemCount, int? updatedAt}) =>
      Playlist(
        id: id,
        name: name ?? this.name,
        itemCount: itemCount ?? this.itemCount,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [id];
}
