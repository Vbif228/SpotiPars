import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../youtube/track_title_cleaner.dart';

class MediaStoreHelper {
  static const MethodChannel _mediaScannerChannel =
      MethodChannel('com.vbif228.spotipars/media_scanner');

  static const String defaultMusicPath = '/storage/emulated/0/Music/SpotiPars';
  static const List<String> folderPresets = [
    '/storage/emulated/0/Music/SpotiPars',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download/SpotiPars',
    '/storage/emulated/0/Download',
  ];

  static String? _cachedBasePath;

  /// Loads the persisted custom base directory from local settings,
  /// or returns the standard default Music/SpotiPars folder.
  static Future<String> getMusicBasePath() async {
    if (_cachedBasePath != null) return _cachedBasePath!;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final settingsFile = File(p.join(docDir.path, 'storage_settings.json'));
      if (await settingsFile.exists()) {
        final content = await settingsFile.readAsString();
        final data = json.decode(content);
        if (data is Map && data['basePath'] is String) {
          final saved = data['basePath'] as String;
          if (saved.isNotEmpty) {
            _cachedBasePath = saved;
            return saved;
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading storage settings: $e');
    }

    _cachedBasePath = defaultMusicPath;
    return defaultMusicPath;
  }

  /// Sets and persists a custom music base directory.
  static Future<void> setMusicBasePath(String path) async {
    _cachedBasePath = path;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final settingsFile = File(p.join(docDir.path, 'storage_settings.json'));
      final data = {'basePath': path};
      await settingsFile.writeAsString(json.encode(data), flush: true);
    } catch (e) {
      debugPrint('Error saving storage settings: $e');
    }
  }

  /// Resolves the target directory for downloaded tracks.
  static Future<Directory> getMusicDirectory({String subFolder = ''}) async {
    final basePath = await getMusicBasePath();
    Directory baseDir;

    if (Platform.isAndroid) {
      try {
        final targetDir = Directory(basePath);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        baseDir = targetDir;
      } catch (e) {
        debugPrint('Fallback storage used due to: $e');
        final extDir = await getExternalStorageDirectory();
        baseDir = extDir ?? await getApplicationDocumentsDirectory();
      }
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    String fullPath = baseDir.path;
    if (subFolder.isNotEmpty) {
      final safeSub = TrackTitleCleaner.sanitizeFilename(subFolder, maxLength: 60);
      fullPath = p.join(fullPath, safeSub);
    }

    final finalDir = Directory(fullPath);
    if (!await finalDir.exists()) {
      await finalDir.create(recursive: true);
    }
    return finalDir;
  }

  /// Scans an audio file into Android MediaStore so that Samsung Music,
  /// Poweramp, YouTube Music, and other native media players detect it immediately.
  static Future<void> scanAudioFile(File file, {String? mimeType}) async {
    if (!Platform.isAndroid) return;
    try {
      final extension = p.extension(file.path).toLowerCase();
      final resolvedMime = mimeType ??
          (extension == '.m4a' || extension == '.mp4'
              ? 'audio/mp4'
              : extension == '.flac'
                  ? 'audio/flac'
                  : extension == '.opus' || extension == '.ogg'
                      ? 'audio/ogg'
                      : 'audio/mpeg');

      await _mediaScannerChannel.invokeMethod('scanFile', {
        'path': file.path,
        'mimeType': resolvedMime,
      });
      debugPrint('MediaStore scanned: ${file.path} ($resolvedMime)');
    } catch (e) {
      debugPrint('MediaStore scan warning (non-fatal): $e');
    }
  }

  /// Checks if track is already downloaded and valid in target directory.
  /// Checks for both .m4a and .mp3 (and current ext) to avoid duplicates.
  static Future<File?> findExistingTrackFile({
    required Directory directory,
    required String artist,
    required String title,
    required String ext,
  }) async {
    if (!await directory.exists()) return null;

    final safeArtist = TrackTitleCleaner.sanitizeFilename(artist, maxLength: 50).toLowerCase();
    final safeTitle = TrackTitleCleaner.sanitizeFilename(title, maxLength: 70).toLowerCase();
    final cleanExt = ext.replaceAll('.', '').toLowerCase();

    // Check primary requested extension, plus standard .m4a / .mp3 alternatives
    final candidateExtensions = {cleanExt, 'm4a', 'mp3', 'flac'};

    try {
      final entities = directory.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final filename = p.basename(entity.path).toLowerCase();
          for (final cExt in candidateExtensions) {
            final targetSuffix = '$safeArtist - $safeTitle.$cExt';
            if (filename.endsWith(targetSuffix) ||
                filename == targetSuffix) {
              final length = await entity.length();
              if (length > AppConstants.minExistingFileSize) {
                return entity;
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
