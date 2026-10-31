import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../constants/app_constants.dart';
import '../models/track_item.dart';
import 'track_title_cleaner.dart';

class YouTubeMatchResult {
  final Video video;
  final AudioOnlyStreamInfo streamInfo;
  final String queryUsed;

  const YouTubeMatchResult({
    required this.video,
    required this.streamInfo,
    required this.queryUsed,
  });
}

class YouTubeSearchEngine {
  final YoutubeExplode _yt;

  YouTubeSearchEngine({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  /// Executes cascade search on YouTube and returns the best valid audio stream.
  Future<YouTubeMatchResult?> findBestAudioStream(
    TrackItem track, {
    void Function(String message)? onStatusUpdate,
  }) async {
    final cleanTitle = TrackTitleCleaner.cleanTrackTitle(track.title);
    final artist = track.artist;

    // Prioritized search queries
    final queries = [
      '$artist - $cleanTitle official audio',
      '$artist - $cleanTitle lyrics', // Bypass Topic DRM & PO-Token
      '$artist - $cleanTitle audio',
      '$artist $cleanTitle song',
    ];

    if (cleanTitle.toLowerCase() != track.title.toLowerCase()) {
      queries.add('$artist - ${track.title}');
    }

    final visitedVideoIds = <String>{};

    for (final query in queries) {
      onStatusUpdate?.call('Поиск: "$query"...');

      try {
        final searchResults = await _yt.search.search(query);
        final candidates = searchResults.take(3).toList();

        for (final video in candidates) {
          if (visitedVideoIds.contains(video.id.value)) continue;
          visitedVideoIds.add(video.id.value);

          // Verify video duration if track duration is known (avoid 10h loops or 15s snippets)
          if (track.durationMs > 0 && video.duration != null) {
            final trackSec = track.durationMs ~/ 1000;
            final videoSec = video.duration!.inSeconds;
            // Reject if video is shorter than 20s or more than 2 minutes longer
            if (videoSec < 20 || (videoSec - trackSec).abs() > 120) {
              continue;
            }
          }

          try {
            final manifest =
                await _yt.videos.streamsClient.getManifest(video.id);
            final audioStreams = manifest.audioOnly;
            if (audioStreams.isEmpty) continue;

            final bestAudio = audioStreams.withHighestBitrate();

            // Filter out stubs / broken streams (< 500 KB)
            if (bestAudio.size.totalBytes < AppConstants.minValidAudioBytes) {
              continue;
            }

            return YouTubeMatchResult(
              video: video,
              streamInfo: bestAudio,
              queryUsed: query,
            );
          } catch (_) {
            // Video might have restrictions, continue cascade
            continue;
          }
        }
      } catch (_) {
        // Query failed, proceed to next query in cascade
        continue;
      }
    }

    return null;
  }

  void close() {
    _yt.close();
  }
}
