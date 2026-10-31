import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../constants/app_constants.dart';
import '../models/track_item.dart';
import 'track_title_cleaner.dart';

class YouTubeMatchResult {
  final Video video;
  final StreamInfo streamInfo;
  final List<StreamInfo> fallbackStreams;
  final String queryUsed;

  const YouTubeMatchResult({
    required this.video,
    required this.streamInfo,
    this.fallbackStreams = const [],
    required this.queryUsed,
  });

  /// All stream candidates for this video (muxed itag 18 prioritized for 403 bypass, followed by direct audio)
  List<StreamInfo> get allStreams => [streamInfo, ...fallbackStreams];
}

class YouTubeSearchEngine {
  YoutubeExplode _yt;

  YouTubeSearchEngine({YoutubeExplode? yt}) : _yt = yt ?? YoutubeExplode();

  void updateClient(YoutubeExplode yt) {
    _yt = yt;
  }

  /// Validates that a stream is directly downloadable and not an HLS/m3u8 playlist stub.
  bool _isValidDirectStream(StreamInfo stream) {
    if (stream is HlsStreamInfo) return false;
    final containerName = stream.container.name.toLowerCase();
    if (containerName.contains('m3u8') || containerName.contains('hls')) {
      return false;
    }
    if (stream.size.totalBytes < AppConstants.minValidAudioBytes) {
      return false;
    }
    return true;
  }

  /// Executes cascade search on YouTube and returns the best valid audio stream.
  Future<YouTubeMatchResult?> findBestAudioStream(
    TrackItem track, {
    void Function(String message)? onStatusUpdate,
    Set<String>? excludedVideoIds,
  }) async {
    final cleanTitle = TrackTitleCleaner.cleanTrackTitle(track.title);
    final artist = track.artist;

    // Prioritized search queries:
    // 1. Lyrics query: user uploads, no YouTube Topic DRM / PO-Token restriction, original audio
    // 2. Audio query
    // 3. Artist + song
    final queries = [
      '$artist - $cleanTitle lyrics',
      '$artist - $cleanTitle official audio',
      '$artist - $cleanTitle audio',
      '$artist $cleanTitle',
    ];

    if (cleanTitle.toLowerCase() != track.title.toLowerCase()) {
      queries.add('$artist - ${track.title}');
    }

    final visitedVideoIds = <String>{
      if (excludedVideoIds != null) ...excludedVideoIds,
    };

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

            // 1. Muxed streams (itag 18 AAC) are prioritized first because YouTube's
            // adaptive audioOnly streams currently return HTTP 403 Forbidden without PO-Token.
            // Muxed streams bypass 403 blocks and stream immediately.
            final directMuxed = manifest.muxed
                .where(_isValidDirectStream)
                .toList()
              ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

            // 2. Direct audioOnly streams (Opus 160k, AAC 128k) as alternatives
            final directAudio = manifest.audioOnly
                .where(_isValidDirectStream)
                .toList()
              ..sort((a, b) {
                if (a.isThrottled != b.isThrottled) {
                  return a.isThrottled ? 1 : -1;
                }
                return b.bitrate.compareTo(a.bitrate);
              });

            final candidateStreams = <StreamInfo>[...directMuxed, ...directAudio];

            // Deduplicate streams by itag
            final seenTags = <int>{};
            final uniqueStreams = <StreamInfo>[];
            for (final s in candidateStreams) {
              if (seenTags.add(s.tag)) {
                uniqueStreams.add(s);
              }
            }

            if (uniqueStreams.isEmpty) continue;

            return YouTubeMatchResult(
              video: video,
              streamInfo: uniqueStreams.first,
              fallbackStreams: uniqueStreams.sublist(1),
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
