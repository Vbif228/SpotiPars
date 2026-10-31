import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/playlist_info.dart';
import '../models/track_item.dart';

class SpotifyScraper {
  final http.Client _client;

  SpotifyScraper({http.Client? client}) : _client = client ?? http.Client();

  static final RegExp trackRegex = RegExp(
    r'(?:spotify:track:|https?://open\.spotify\.com/(?:[a-zA-Z0-9_-]+/)?track/)([a-zA-Z0-9]{22})',
  );

  static final RegExp playlistRegex = RegExp(
    r'(?:spotify:playlist:|https?://open\.spotify\.com/(?:[a-zA-Z0-9_-]+/)?playlist/)([a-zA-Z0-9]{22})',
  );

  static final RegExp albumRegex = RegExp(
    r'(?:spotify:album:|https?://open\.spotify\.com/(?:[a-zA-Z0-9_-]+/)?album/)([a-zA-Z0-9]{22})',
  );

  /// Identifies the type and ID from an arbitrary input string or URL.
  static ({String type, String id})? parseUrl(String input) {
    final trackMatch = trackRegex.firstMatch(input);
    if (trackMatch != null) {
      return (type: 'track', id: trackMatch.group(1)!);
    }

    final playlistMatch = playlistRegex.firstMatch(input);
    if (playlistMatch != null) {
      return (type: 'playlist', id: playlistMatch.group(1)!);
    }

    final albumMatch = albumRegex.firstMatch(input);
    if (albumMatch != null) {
      return (type: 'album', id: albumMatch.group(1)!);
    }

    return null;
  }

  /// Fetches track, playlist or album information based on parsed URL.
  Future<PlaylistInfo> fetchEntity(String url) async {
    final parsed = parseUrl(url);
    if (parsed == null) {
      throw FormatException('Некорректная ссылка Spotify: $url');
    }

    switch (parsed.type) {
      case 'track':
        final track = await fetchSingleTrack(parsed.id);
        return PlaylistInfo(
          id: track.id,
          type: 'track',
          title: track.title,
          description: track.artist,
          ownerName: track.artist,
          coverUrl: track.coverUrl,
          tracks: [track],
          originalUrl: url,
        );

      case 'playlist':
        return await fetchPlaylistOrAlbum(
          id: parsed.id,
          type: 'playlist',
          originalUrl: url,
        );

      case 'album':
        return await fetchPlaylistOrAlbum(
          id: parsed.id,
          type: 'album',
          originalUrl: url,
        );

      default:
        throw UnsupportedError('Неподдерживаемый тип сущности: ${parsed.type}');
    }
  }

  /// Fetches single track metadata with 3-tier fallback.
  Future<TrackItem> fetchSingleTrack(String trackId) async {
    // --- Tier 1: Embed __NEXT_DATA__ ---
    try {
      final embedUrl = Uri.parse('https://open.spotify.com/embed/track/$trackId');
      final res = await _client.get(embedUrl, headers: {
        'User-Agent': AppConstants.browserUserAgent,
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final track = _parseNextDataSingleTrack(res.body, trackId);
        if (track != null) return track;
      }
    } catch (_) {}

    // --- Tier 2: OpenGraph Crawler fallback ---
    try {
      final trackUrl = Uri.parse('https://open.spotify.com/track/$trackId');
      final res = await _client.get(trackUrl, headers: {
        'User-Agent': AppConstants.crawlerUserAgent,
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final track = _parseOpenGraphTrack(res.body, trackId);
        if (track != null) return track;
      }
    } catch (_) {}

    // --- Tier 3: oEmbed API fallback ---
    try {
      final oeUrl = Uri.parse(
          'https://open.spotify.com/oembed?url=https://open.spotify.com/track/$trackId');
      final res = await _client.get(oeUrl).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawTitle = (data['title'] as String? ?? '').trim();
        final coverUrl = (data['thumbnail_url'] as String? ?? '').trim();

        String artist = 'Spotify Artist';
        String title = rawTitle;
        if (rawTitle.contains(' - ')) {
          final parts = rawTitle.split(' - ');
          artist = parts[0].trim();
          title = parts.sublist(1).join(' - ').trim();
        }

        return TrackItem(
          id: trackId,
          title: title.isNotEmpty ? title : 'Трек $trackId',
          artist: artist,
          coverUrl: coverUrl,
          trackNumber: 1,
        );
      }
    } catch (_) {}

    // Fallback if all attempts fail
    return TrackItem(
      id: trackId,
      title: 'Трек $trackId',
      artist: 'Неизвестный исполнитель',
      trackNumber: 1,
    );
  }

  /// Fetches playlist or album tracks from embed page.
  Future<PlaylistInfo> fetchPlaylistOrAlbum({
    required String id,
    required String type,
    required String originalUrl,
  }) async {
    final embedUrl = Uri.parse('https://open.spotify.com/embed/$type/$id');
    final res = await _client.get(embedUrl, headers: {
      'User-Agent': AppConstants.browserUserAgent,
      'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
    }).timeout(const Duration(seconds: 12));

    if (res.statusCode == 200) {
      final parsed = _parseNextDataCollection(res.body, id, type, originalUrl);
      if (parsed != null && parsed.tracks.isNotEmpty) {
        return parsed;
      }
    }

    // Fallback to oEmbed if embed page didn't yield tracklist
    try {
      final oeUrl = Uri.parse(
          'https://open.spotify.com/oembed?url=https://open.spotify.com/$type/$id');
      final res = await _client.get(oeUrl).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final title = (data['title'] as String? ?? 'Плейлист').trim();
        final coverUrl = (data['thumbnail_url'] as String? ?? '').trim();

        return PlaylistInfo(
          id: id,
          type: type,
          title: title,
          coverUrl: coverUrl,
          tracks: const [],
          originalUrl: originalUrl,
        );
      }
    } catch (_) {}

    return PlaylistInfo(
      id: id,
      type: type,
      title: type == 'album' ? 'Альбом $id' : 'Плейлист $id',
      tracks: const [],
      originalUrl: originalUrl,
    );
  }

  // --- Internal Parsers ---

  TrackItem? _parseNextDataSingleTrack(String html, String trackId) {
    try {
      final jsonString = _extractNextDataJson(html);
      if (jsonString == null) return null;

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final entity = data['props']?['pageProps']?['state']?['data']?['entity']
          as Map<String, dynamic>?;

      if (entity == null) return null;

      final title = (entity['name'] ?? entity['title']) as String?;
      if (title == null || title.isEmpty) return null;

      final artistsList = entity['artists'] as List<dynamic>? ?? [];
      final artists = artistsList
          .map((a) => (a is Map ? a['name'] as String? : null))
          .where((name) => name != null && name.isNotEmpty)
          .join(', ');

      final album = entity['album']?['name'] as String? ?? '';

      // High-res cover art selection
      String coverUrl = '';
      final images = entity['visualIdentity']?['image'] as List<dynamic>? ?? [];
      if (images.isNotEmpty) {
        images.sort((a, b) {
          final wa = (a is Map ? a['maxWidth'] as int? : 0) ?? 0;
          final wb = (b is Map ? b['maxWidth'] as int? : 0) ?? 0;
          return wb.compareTo(wa);
        });
        coverUrl = (images.first as Map)['url'] as String? ?? '';
      }

      final durationMs = (entity['duration'] as int?) ?? 0;

      return TrackItem(
        id: trackId,
        title: title.trim(),
        artist: artists.isNotEmpty ? artists : 'Неизвестный исполнитель',
        album: album.trim(),
        coverUrl: coverUrl,
        durationMs: durationMs,
        trackNumber: 1,
      );
    } catch (_) {
      return null;
    }
  }

  PlaylistInfo? _parseNextDataCollection(
    String html,
    String id,
    String type,
    String originalUrl,
  ) {
    try {
      final jsonString = _extractNextDataJson(html);
      if (jsonString == null) return null;

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final entity = data['props']?['pageProps']?['state']?['data']?['entity']
          as Map<String, dynamic>?;

      if (entity == null) return null;

      final title = (entity['name'] ?? entity['title'] ?? 'Коллекция') as String;
      final description = (entity['description'] ?? '') as String;
      final owner = (entity['owner']?['name'] ?? entity['creator']?['name'] ?? '') as String;

      // Extract cover image
      String coverUrl = '';
      final images = entity['visualIdentity']?['image'] as List<dynamic>? ?? [];
      if (images.isNotEmpty) {
        images.sort((a, b) {
          final wa = (a is Map ? a['maxWidth'] as int? : 0) ?? 0;
          final wb = (b is Map ? b['maxWidth'] as int? : 0) ?? 0;
          return wb.compareTo(wa);
        });
        coverUrl = (images.first as Map)['url'] as String? ?? '';
      }

      final trackListRaw = (entity['trackList'] as List<dynamic>?) ?? [];
      final List<TrackItem> tracks = [];

      for (int i = 0; i < trackListRaw.length; i++) {
        final item = trackListRaw[i] as Map<String, dynamic>;
        final trackTitle = (item['title'] ?? item['name'] ?? '') as String;
        if (trackTitle.isEmpty) continue;

        final trackSubtitle = (item['subtitle'] ?? '') as String;
        final trackDuration = (item['duration'] as int?) ?? 0;

        // Try extracting Spotify track ID from item uri (e.g. spotify:track:...)
        final uri = item['uri'] as String? ?? '';
        final trackIdMatch = RegExp(r'track:([a-zA-Z0-9]{22})').firstMatch(uri);
        final trackId = trackIdMatch?.group(1) ?? 'track_${id}_${i + 1}';

        tracks.add(
          TrackItem(
            id: trackId,
            title: trackTitle.trim(),
            artist: trackSubtitle.isNotEmpty ? trackSubtitle : 'Spotify Track',
            album: title,
            coverUrl: coverUrl,
            durationMs: trackDuration,
            trackNumber: i + 1,
            isSelected: true,
          ),
        );
      }

      return PlaylistInfo(
        id: id,
        type: type,
        title: title.trim(),
        description: description.trim(),
        ownerName: owner.trim(),
        coverUrl: coverUrl,
        tracks: tracks,
        originalUrl: originalUrl,
      );
    } catch (_) {
      return null;
    }
  }

  TrackItem? _parseOpenGraphTrack(String html, String trackId) {
    try {
      final titleMatch = RegExp(
        r'<meta\s+property=["' "'" r']og:title["' "'" r']\s+content=["' "'" r']([^"' "'" r']*)["' "'" r']',
        caseSensitive: false,
      ).firstMatch(html);

      final descMatch = RegExp(
        r'<meta\s+property=["' "'" r']og:description["' "'" r']\s+content=["' "'" r']([^"' "'" r']*)["' "'" r']',
        caseSensitive: false,
      ).firstMatch(html);

      final imageMatch = RegExp(
        r'<meta\s+property=["' "'" r']og:image["' "'" r']\s+content=["' "'" r']([^"' "'" r']*)["' "'" r']',
        caseSensitive: false,
      ).firstMatch(html);

      final title = titleMatch?.group(1)?.trim() ?? '';
      if (title.isEmpty) return null;

      final desc = descMatch?.group(1)?.trim() ?? '';
      final coverUrl = imageMatch?.group(1)?.trim() ?? '';

      String artist = 'Неизвестный исполнитель';
      String album = '';

      if (desc.isNotEmpty) {
        final parts = desc.contains(' · ') ? desc.split(' · ') : desc.split(' - ');
        if (parts.isNotEmpty) artist = parts[0].trim();
        if (parts.length > 1) album = parts[1].trim();
      }

      return TrackItem(
        id: trackId,
        title: title,
        artist: artist,
        album: album,
        coverUrl: coverUrl,
        trackNumber: 1,
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractNextDataJson(String html) {
    final scriptRegex = RegExp(
      r'<script\s+id=["' "'" r']__NEXT_DATA__["' "'" r']\s+type=["' "'" r']application/json["' "'" r']>([\s\S]*?)</script>',
      caseSensitive: false,
    );
    final match = scriptRegex.firstMatch(html);
    return match?.group(1)?.trim();
  }
}
