import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../constants/app_constants.dart';
import '../models/track_item.dart';
import 'track_title_cleaner.dart';

class YouTubeMatchResult {
  final Video video;
  final StreamInfo streamInfo;
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
    // 1. Lyrics query: user uploads, no YouTube Topic DRM / PO-Token restriction, original audio
    // 2. Official audio query
    // 3. Audio query
    // 4. Artist + song
    final queries = [
      '$artist - $cleanTitle lyrics',
      '$artist - $cleanTitle official audio',
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
        final searchResults = await _yt.search
            .search(query)
            .timeout(const Duration(seconds: 12));
        final candidates = searchResults.take(4).toList();

        for (int cIdx = 0; cIdx < candidates.length; cIdx++) {
          final video = candidates[cIdx];
          if (visitedVideoIds.contains(video.id.value)) continue;
          visitedVideoIds.add(video.id.value);

          // Verify video duration if track duration is known (avoid 10h loops or snippets)
          if (video.duration != null) {
            final videoSec = video.duration!.inSeconds;
            if (videoSec < 20 || videoSec > 1200) {
              continue;
            }
            if (track.durationMs > 0) {
              final trackSec = track.durationMs ~/ 1000;
              if ((videoSec - trackSec).abs() > 60) {
                continue;
              }
            }
          }

          if (cIdx > 0) {
            await Future.delayed(const Duration(milliseconds: 250));
          }

          try {
            // Uses default androidSdkless client in youtube_explode_dart 3.1.0
            final manifest = await _yt.videos.streamsClient
                .getManifest(video.id)
                .timeout(const Duration(seconds: 12));

            // Filter out HLS/m3u8 stubs and small files (< 500 KB)
            bool isValidStream(StreamInfo s) {
              if (s is HlsAudioStreamInfo ||
                  s is HlsMuxedStreamInfo ||
                  s is HlsVideoStreamInfo) {
                return false;
              }
              final containerName = s.container.name.toLowerCase();
              if (containerName.contains('m3u8') || containerName.contains('hls')) {
                return false;
              }
              if (s.size.totalBytes < AppConstants.minValidAudioBytes) {
                return false;
              }
              return true;
            }

            final validMuxed = manifest.muxed.where(isValidStream);
            final validAudioOnly = manifest.audioOnly.where(isValidStream);

            // 1. Prioritize muxed streams (itag 18 AAC) because YouTube's adaptive
            // audioOnly streams currently return HTTP 403 Forbidden without PO-Token.
            // Muxed streams bypass 403 blocks and stream immediately.
            StreamInfo? bestAudio;
            if (validMuxed.isNotEmpty) {
              bestAudio = validMuxed.withHighestBitrate();
            } else if (validAudioOnly.isNotEmpty) {
              bestAudio = validAudioOnly.withHighestBitrate();
            }

            if (bestAudio == null) continue;

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
