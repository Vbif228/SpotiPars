import 'dart:convert';
import 'dart:io';

void main() async {
  print('=== Local Spotify Scraper Live Test ===\n');

  final client = HttpClient();
  client.userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36';

  // 1. Test Track Embed
  try {
    print('Testing Track Embed...');
    final uri = Uri.parse('https://open.spotify.com/embed/track/4cOdK2wGLETKBW3PvgPWqT');
    final req = await client.getUrl(uri);
    req.headers.set('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8');
    final res = await req.close();
    print('Track Embed HTTP Status: ${res.statusCode}');

    final body = await res.transform(utf8.decoder).join();
    final jsonMatch = RegExp(r'<script\s+id=["' "'" r']__NEXT_DATA__["' "'" r']\s+type=["' "'" r']application/json["' "'" r']>([\s\S]*?)</script>')
        .firstMatch(body);

    if (jsonMatch != null) {
      final data = jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
      final entity = data['props']?['pageProps']?['state']?['data']?['entity'];
      print('  ✓ Track Name: "${entity['name']}"');
      final artists = (entity['artists'] as List).map((a) => a['name']).join(', ');
      print('  ✓ Artists: "$artists"');
      print('  ✓ Album: "${entity['album']?['name']}"');
    } else {
      print('  ✗ Failed to find __NEXT_DATA__');
      exit(1);
    }
  } catch (e) {
    print('  ✗ Track Embed Exception: $e');
    exit(1);
  }

  // 2. Test Playlist Embed
  try {
    print('\nTesting Playlist Embed...');
    final uri = Uri.parse('https://open.spotify.com/embed/playlist/37i9dQZF1DXcBWIGoYBM5M');
    final req = await client.getUrl(uri);
    req.headers.set('Accept-Language', 'ru-RU,ru;q=0.9,en-US;q=0.8');
    final res = await req.close();
    print('Playlist Embed HTTP Status: ${res.statusCode}');

    final body = await res.transform(utf8.decoder).join();
    final jsonMatch = RegExp(r'<script\s+id=["' "'" r']__NEXT_DATA__["' "'" r']\s+type=["' "'" r']application/json["' "'" r']>([\s\S]*?)</script>')
        .firstMatch(body);

    if (jsonMatch != null) {
      final data = jsonDecode(jsonMatch.group(1)!) as Map<String, dynamic>;
      final entity = data['props']?['pageProps']?['state']?['data']?['entity'];
      print('  ✓ Playlist Name: "${entity['name']}"');
      final tracks = entity['trackList'] as List? ?? [];
      print('  ✓ Tracks count: ${tracks.length}');
      if (tracks.isNotEmpty) {
        print('  ✓ First track: "${tracks[0]['title']}" by "${tracks[0]['subtitle']}"');
      }
    } else {
      print('  ✗ Failed to find __NEXT_DATA__ in playlist');
      exit(1);
    }
  } catch (e) {
    print('  ✗ Playlist Embed Exception: $e');
    exit(1);
  }

  // 3. Test oEmbed API
  try {
    print('\nTesting oEmbed API...');
    final uri = Uri.parse('https://open.spotify.com/oembed?url=https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
    final req = await client.getUrl(uri);
    final res = await req.close();
    print('oEmbed HTTP Status: ${res.statusCode}');

    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    print('  ✓ Title: "${data['title']}"');
    print('  ✓ Thumbnail: "${data['thumbnail_url']}"');
  } catch (e) {
    print('  ✗ oEmbed Exception: $e');
    exit(1);
  }

  print('\n=== ALL NETWORK ENDPOINTS VERIFIED AND PASSING ===');
  exit(0);
}
