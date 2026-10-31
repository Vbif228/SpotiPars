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
  YoutubeExplode _yt;

  YouTubeSearchEngine({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  void updateClient(YoutubeExplode yt) {
    _yt = yt;
  }

  /// Executes cascade search on YouTube and returns the best valid audio stream.
  Future<YouTubeMatchResult?> findBestAudioStream(
    TrackItem track, {
    void Function(String message)? onStatusUpdate,
  }) async {
    final cleanTitle = TrackTitleCleaner.cleanTrackTitle(track.title);
    final artist = track.artist;

    // Prioritized search queries:
    // 1. Lyrics query: user uploads, NO YouTube Topic DRM / PO-Token restriction, original audio
    // 2. Audio query
    // 3. Artist + song
    final queries = [
      '$artist - $cleanTitle lyrics',
      '$artist - $cleanTitle audio',
      '$artist $cleanTitle',
    ];

    if (cleanTitle.toLowerCase() != track.title.toLowerCase()) {
      queries.add('$artist - ${track.title}');
    }

    final visitedVideoIds = <String>{};

    for (int qIdx = 0; qIdx < queries.length; qIdx++) {
      final query = queries[qIdx];
      if (qIdx > 0) {
        // Polite delay between cascade queries to prevent rate-limiting
        await Future.delayed(const Duration(milliseconds: 300));
      }

      onStatusUpdate?.call('Поиск: "$query"...');

      try {
        final searchResults = await _yt.search.search(query);
        final candidates = searchResults.take(3).toList();

        for (int cIdx = 0; cIdx < candidates.length; cIdx++) {
          final video = candidates[cIdx];
          if (visitedVideoIds.contains(video.id.value)) continue;
          visitedVideoIds.add(video.id.value);

          // Verify video duration if track duration is known (avoid 10h loops or snippets)
          if (track.durationMs > 0 && video.duration != null) {
            final trackSec = track.durationMs ~/ 1000;
            final videoSec = video.duration!.inSeconds;
            // Reject if video is shorter than 20s or duration differs by > 50s
            if (videoSec < 20 || (videoSec - trackSec).abs() > 50) {
              continue;
            }
          }

          if (cIdx > 0) {
            await Future.delayed(const Duration(milliseconds: 250));
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
          } on RequestLimitExceededException {
            // Rethrow so the download manager can back off and cool down
            rethrow;
          } catch (_) {
            // Video might have restrictions or DRM, continue cascade
            continue;
          }
        }
      } on RequestLimitExceededException {
        // Rethrow rate limit exception immediately
        rethrow;
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
