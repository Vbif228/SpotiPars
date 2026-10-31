class AppConstants {
  static const String appName = 'SpotiPars';
  static const String appVersion = '1.0.0';

  // Default directories
  static const String defaultMusicDirName = 'Music/SpotiPars';

  // HTTP User Agents
  static const String browserUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';

  static const String crawlerUserAgent =
      'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)';

  // Download thresholds
  static const int minValidAudioBytes = 500 * 1024; // 500 KB to reject preview stubs
  static const int minExistingFileSize = 10 * 1024; // 10 KB for deduplication

  // Supported audio formats
  static const String formatMp3 = 'mp3';
  static const String formatFlac = 'flac';

  // Foreground notification channel
  static const String notificationChannelId = 'spotipars_foreground_channel';
  static const String notificationChannelName = 'SpotiPars Downloads';
  static const String notificationChannelDesc =
      'Ongoing background music downloads notification';
}
