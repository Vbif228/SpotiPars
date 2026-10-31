import 'track_item.dart';

class PlaylistInfo {
  final String id;
  final String type; // 'playlist', 'album', 'track'
  final String title;
  final String description;
  final String ownerName;
  final String coverUrl;
  final List<TrackItem> tracks;
  final String originalUrl;

  const PlaylistInfo({
    required this.id,
    required this.type,
    required this.title,
    this.description = '',
    this.ownerName = '',
    this.coverUrl = '',
    this.tracks = const [],
    this.originalUrl = '',
  });

  int get totalTracksCount => tracks.length;

  int get selectedTracksCount =>
      tracks.where((track) => track.isSelected).length;

  List<TrackItem> get selectedTracks =>
      tracks.where((track) => track.isSelected).toList();

  PlaylistInfo copyWith({
    String? id,
    String? type,
    String? title,
    String? description,
    String? ownerName,
    String? coverUrl,
    List<TrackItem>? tracks,
    String? originalUrl,
  }) {
    return PlaylistInfo(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      ownerName: ownerName ?? this.ownerName,
      coverUrl: coverUrl ?? this.coverUrl,
      tracks: tracks ?? this.tracks,
      originalUrl: originalUrl ?? this.originalUrl,
    );
  }
}
