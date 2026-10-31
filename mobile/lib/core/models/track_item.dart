class TrackItem {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final int durationMs;
  final int trackNumber;
  final bool isSelected;

  const TrackItem({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.coverUrl = '',
    this.durationMs = 0,
    this.trackNumber = 1,
    this.isSelected = true,
  });

  TrackItem copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? coverUrl,
    int? durationMs,
    int? trackNumber,
    bool? isSelected,
  }) {
    return TrackItem(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      coverUrl: coverUrl ?? this.coverUrl,
      durationMs: durationMs ?? this.durationMs,
      trackNumber: trackNumber ?? this.trackNumber,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'coverUrl': coverUrl,
        'durationMs': durationMs,
        'trackNumber': trackNumber,
        'isSelected': isSelected,
      };

  factory TrackItem.fromJson(Map<String, dynamic> json) => TrackItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown Title',
        artist: json['artist'] as String? ?? 'Unknown Artist',
        album: json['album'] as String? ?? '',
        coverUrl: json['coverUrl'] as String? ?? '',
        durationMs: json['durationMs'] as int? ?? 0,
        trackNumber: json['trackNumber'] as int? ?? 1,
        isSelected: json['isSelected'] as bool? ?? true,
      );

  String get durationFormatted {
    if (durationMs <= 0) return '--:--';
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
