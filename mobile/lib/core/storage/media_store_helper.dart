import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../youtube/track_title_cleaner.dart';

class MediaStoreHelper {
  /// Resolves the default target directory for downloaded tracks.
  /// On Android, resolves to `/storage/emulated/0/Music/SpotiPars`.
  static Future<Directory> getMusicDirectory({String subFolder = ''}) async {
    Directory baseDir;

    if (Platform.isAndroid) {
      final standardMusicDir = Directory('/storage/emulated/0/Music');
      if (await standardMusicDir.exists()) {
        baseDir = standardMusicDir;
      } else {
        final extDir = await getExternalStorageDirectory();
        baseDir = extDir ?? await getApplicationDocumentsDirectory();
      }
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    String fullPath = p.join(baseDir.path, 'SpotiPars');
    if (subFolder.isNotEmpty) {
      final safeSub = TrackTitleCleaner.sanitizeFilename(subFolder, maxLength: 60);
      fullPath = p.join(fullPath, safeSub);
    }

    final targetDir = Directory(fullPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  /// Checks if track is already downloaded and valid in target directory.
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
    final targetSuffix = '$safeArtist - $safeTitle.$cleanExt';

    try {
      final entities = directory.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final filename = p.basename(entity.path).toLowerCase();
          if (filename.endsWith(targetSuffix) ||
              filename == '$safeArtist - $safeTitle.$cleanExt') {
            final length = await entity.length();
            if (length > AppConstants.minExistingFileSize) {
              return entity;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
