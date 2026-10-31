import 'dart:io';
import '../lib/core/youtube/track_title_cleaner.dart';

void main() {
  print('=== Running SpotiPars Core Unit Tests ===\n');

  int passed = 0;
  int failed = 0;

  void test(String name, void Function() body) {
    try {
      body();
      print('  [PASS] $name');
      passed++;
    } catch (e) {
      print('  [FAIL] $name');
      print('    Error: $e');
      failed++;
    }
  }

  void expect(dynamic actual, dynamic expected, [String? reason]) {
    if (actual != expected) {
      throw Exception(
        'Expected "$expected" but got "$actual"${reason != null ? " ($reason)" : ""}',
      );
    }
  }

  // --- Title Cleaner Tests ---
  print('[1] TrackTitleCleaner Tests:');

  test('cleans "- 2007 Remaster"', () {
    final result = TrackTitleCleaner.cleanTrackTitle('Bone Machine - 2007 Remaster');
    expect(result, 'Bone Machine');
  });

  test('cleans "(Remastered 2021)"', () {
    final result = TrackTitleCleaner.cleanTrackTitle('Where Is My Mind? (Remastered 2021)');
    expect(result, 'Where Is My Mind');
  });

  test('cleans "[2011 Remaster]"', () {
    final result = TrackTitleCleaner.cleanTrackTitle('Time [2011 Remaster]');
    expect(result, 'Time');
  });

  test('cleans "(Deluxe Edition)"', () {
    final result = TrackTitleCleaner.cleanTrackTitle('Paranoid Android (Deluxe Edition)');
    expect(result, 'Paranoid Android');
  });

  test('cleans "- Single Version"', () {
    final result = TrackTitleCleaner.cleanTrackTitle('In The End - Single Version');
    expect(result, 'In The End');
  });

  test('strips question and exclamation marks', () {
    final result = TrackTitleCleaner.cleanTrackTitle("Why Won't They Talk To Me?!");
    expect(result, "Why Won't They Talk To Me");
  });

  test('sanitizes filename from illegal characters', () {
    final result = TrackTitleCleaner.sanitizeFilename('AC/DC: Who Made Who? <1986>');
    expect(result, 'ACDC Who Made Who 1986');
  });

  test('builds padded filename', () {
    final result = TrackTitleCleaner.buildFilename(
      trackNumber: 5,
      artist: 'Pink Floyd',
      title: 'Time',
      ext: 'mp3',
      totalTracks: 12,
    );
    expect(result, '05. Pink Floyd - Time.mp3');
  });

  // --- Regex URL Tests ---
  print('\n[2] Spotify URL Regex Tests:');

  final trackRegex = RegExp(
    r'(?:spotify:track:|https?://open\.spotify\.com/(?:[a-zA-Z0-9_-]+/)?track/)([a-zA-Z0-9]{22})',
  );

  final playlistRegex = RegExp(
    r'(?:spotify:playlist:|https?://open\.spotify\.com/(?:[a-zA-Z0-9_-]+/)?playlist/)([a-zA-Z0-9]{22})',
  );

  final albumRegex = RegExp(
    r'(?:spotify:album:|https?://open\.spotify\.com/(?:[a-zA-Z0-9_-]+/)?album/)([a-zA-Z0-9]{22})',
  );

  test('matches standard track URL', () {
    final match = trackRegex.firstMatch('https://open.spotify.com/track/4cOdK2wGLETKBW3PvgPWqT');
    expect(match?.group(1), '4cOdK2wGLETKBW3PvgPWqT');
  });

  test('matches track URL with localized prefix and query params', () {
    final match = trackRegex.firstMatch('https://open.spotify.com/intl-ru/track/4cOdK2wGLETKBW3PvgPWqT?si=abc123xyz');
    expect(match?.group(1), '4cOdK2wGLETKBW3PvgPWqT');
  });

  test('matches playlist URL', () {
    final match = playlistRegex.firstMatch('https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M');
    expect(match?.group(1), '37i9dQZF1DXcBWIGoYBM5M');
  });

  test('matches album URL', () {
    final match = albumRegex.firstMatch('https://open.spotify.com/album/4LH4d3cOWNNXdurMd0v71w?si=xyz');
    expect(match?.group(1), '4LH4d3cOWNNXdurMd0v71w');
  });

  test('matches spotify URI notation', () {
    final match = trackRegex.firstMatch('spotify:track:4cOdK2wGLETKBW3PvgPWqT');
    expect(match?.group(1), '4cOdK2wGLETKBW3PvgPWqT');
  });

  print('\n----------------------------------------');
  print('Summary: $passed passed, $failed failed.');
  if (failed > 0) {
    exit(1);
  }
}
