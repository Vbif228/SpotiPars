class TrackTitleCleaner {
  static final RegExp _remasterDash = RegExp(
    r'\s*[-–—]\s*(?:\d{4}\s*)?Remaster(?:ed)?.*',
    caseSensitive: false,
  );

  static final RegExp _remasterParen = RegExp(
    r'\s*[\(\[].*?Remaster(?:ed)?.*?[\)\]]',
    caseSensitive: false,
  );

  static final RegExp _deluxeParen = RegExp(
    r'\s*[\(\[].*?Deluxe.*?[\)\]]',
    caseSensitive: false,
  );

  static final RegExp _singleParen = RegExp(
    r'\s*[-–—]\s*Single\s*Version.*|\s*[\(\[].*?Single\s*Version.*?[\)\]]',
    caseSensitive: false,
  );

  static final RegExp _punctuation = RegExp(r'[?!]');

  static final RegExp _invalidFilenameChars = RegExp(r'[\\/*?:"<>|]');

  /// Cleans track title by stripping remaster tags, deluxe mentions, and confusing punctuation.
  static String cleanTrackTitle(String title) {
    if (title.isEmpty) return '';

    String cleaned = title;
    cleaned = cleaned.replaceAll(_remasterDash, '');
    cleaned = cleaned.replaceAll(_remasterParen, '');
    cleaned = cleaned.replaceAll(_deluxeParen, '');
    cleaned = cleaned.replaceAll(_singleParen, '');
    cleaned = cleaned.replaceAll(_punctuation, '');
    cleaned = cleaned.trim();

    return cleaned.isNotEmpty ? cleaned : title;
  }

  /// Sanitizes string for safe file naming on Android filesystem.
  static String sanitizeFilename(String name, {int maxLength = 90}) {
    if (name.isEmpty) return 'Track';

    var clean = name.replaceAll(_invalidFilenameChars, '');
    clean = clean.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    clean = clean.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');

    if (clean.isEmpty) clean = 'Track';

    if (clean.length > maxLength) {
      clean = clean.substring(0, maxLength).trim();
    }
    return clean;
  }

  /// Builds a complete safe filename.
  static String buildFilename({
    required int trackNumber,
    required String artist,
    required String title,
    required String ext,
    bool includeNumber = true,
    int totalTracks = 0,
  }) {
    final safeArtist = sanitizeFilename(artist, maxLength: 50);
    final safeTitle = sanitizeFilename(title, maxLength: 70);
    final cleanExt = ext.replaceAll('.', '').toLowerCase();

    final padWidth = totalTracks > 99 ? 3 : 2;
    final numStr = trackNumber.toString().padLeft(padWidth, '0');

    if (includeNumber) {
      return '$numStr. $safeArtist - $safeTitle.$cleanExt';
    }
    return '$safeArtist - $safeTitle.$cleanExt';
  }
}
