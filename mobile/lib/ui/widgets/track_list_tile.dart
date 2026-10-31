import 'package:flutter/material.dart';
import '../../core/models/track_item.dart';
import '../theme/spotify_theme.dart';

class TrackListTile extends StatelessWidget {
  final TrackItem track;
  final ValueChanged<bool>? onToggleSelect;

  const TrackListTile({
    Key? key,
    required this.track,
    this.onToggleSelect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SpotifyTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Select Checkbox
          if (onToggleSelect != null)
            Checkbox(
              value: track.isSelected,
              activeColor: SpotifyTheme.spotifyGreen,
              checkColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (val) {
                if (val != null) onToggleSelect!(val);
              },
            )
          else
            SizedBox(
              width: 32,
              child: Text(
                '${track.trackNumber}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SpotifyTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(width: 8),

          // Cover Art Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: track.coverUrl.isNotEmpty
                ? Image.network(
                    track.coverUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _placeholderCover(),
                  )
                : _placeholderCover(),
          ),

          const SizedBox(width: 12),

          // Title & Artist
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SpotifyTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SpotifyTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Duration
          Text(
            track.durationFormatted,
            style: const TextStyle(
              color: SpotifyTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      width: 44,
      height: 44,
      color: SpotifyTheme.surfaceElevated,
      child: const Icon(
        Icons.music_note,
        color: SpotifyTheme.textSecondary,
        size: 24,
      ),
    );
  }
}
