import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../constants/app_constants.dart';
import '../models/download_item.dart';
import '../models/track_item.dart';
import '../storage/media_store_helper.dart';
import '../tagger/id3_tagger.dart';
import '../youtube/track_title_cleaner.dart';
import '../youtube/youtube_search_engine.dart';

typedef DownloadProgressCallback = void Function(List<DownloadItem> items);

class AudioDownloadManager extends ChangeNotifier {
  static final AudioDownloadManager instance = AudioDownloadManager._internal();

  factory AudioDownloadManager() => instance;

  late YoutubeExplode _ytClient;
  late YouTubeSearchEngine _searchEngine;
  final Id3Tagger _tagger;

  AudioDownloadManager._internal({
    YouTubeSearchEngine? searchEngine,
    Id3Tagger? tagger,
    YoutubeExplode? ytClient,
  }) : _tagger = tagger ?? Id3Tagger() {
    _ytClient = ytClient ?? YoutubeExplode();
    _searchEngine = searchEngine ?? YouTubeSearchEngine(yt: _ytClient);
  }

  void _resetYtClient() {
    try {
      _ytClient.close();
    } catch (_) {}
    _ytClient = YoutubeExplode();
    _searchEngine.updateClient(_ytClient);
  }

  final List<DownloadItem> _queue = [];
  bool _isProcessing = false;
  bool _isCancelled = false;
  int _maxConcurrency = 1;
  String _audioFormat = AppConstants.formatMp3;
  String _subFolder = '';

  List<DownloadItem> get queue => List.unmodifiable(_queue);
  bool get isProcessing => _isProcessing;
  int get maxConcurrency => _maxConcurrency;
  String get audioFormat => _audioFormat;
  String get subFolder => _subFolder;

  void configure({
    int? maxConcurrency,
    String? audioFormat,
    String? subFolder,
  }) {
    if (maxConcurrency != null) _maxConcurrency = maxConcurrency.clamp(1, 4);
    if (audioFormat != null) _audioFormat = audioFormat;
    if (subFolder != null) _subFolder = subFolder;
    notifyListeners();
  }

  void addTracks(List<TrackItem> tracks) {
    for (final track in tracks) {
      if (!_queue.any((item) => item.track.id == track.id)) {
        _queue.add(
          DownloadItem(
            track: track,
            status: DownloadStatus.queued,
            statusMessage: 'В очереди',
          ),
        );
      }
    }
    notifyListeners();
    _processQueue();
  }

  void cancelAll() {
    _isCancelled = true;
    for (int i = 0; i < _queue.length; i++) {
      if (!_queue[i].isCompleted) {
        _queue[i] = _queue[i].copyWith(
          status: DownloadStatus.cancelled,
          statusMessage: 'Отменено',
        );
      }
    }
    _isProcessing = false;
    notifyListeners();
  }

  void clearCompleted() {
    _queue.removeWhere((item) => item.isCompleted);
    notifyListeners();
  }

  void retryTrack(TrackItem track) {
    final idx = _queue.indexWhere((q) => q.track.id == track.id);
    if (idx != -1) {
      _queue[idx] = _queue[idx].copyWith(
        status: DownloadStatus.queued,
        statusMessage: 'В очереди (повтор)',
        error: null,
        progress: 0.0,
      );
      notifyListeners();
      _processQueue();
    }
  }

  void retryFailed() {
    bool hasAny = false;
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].status == DownloadStatus.failed ||
          _queue[i].status == DownloadStatus.cancelled) {
        _queue[i] = _queue[i].copyWith(
          status: DownloadStatus.queued,
          statusMessage: 'В очереди (повтор)',
          error: null,
          progress: 0.0,
        );
        hasAny = true;
      }
    }
    if (hasAny) {
      notifyListeners();
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _isCancelled = false;

    try {
      while (!_isCancelled) {
        final activeDownloads = _queue
            .where((item) =>
                item.status == DownloadStatus.searching ||
                item.status == DownloadStatus.downloading ||
                item.status == DownloadStatus.tagging)
            .length;

        if (activeDownloads >= _maxConcurrency) {
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }

        final nextIndex = _queue.indexWhere(
          (item) => item.status == DownloadStatus.queued,
        );

        if (nextIndex == -1) {
          if (activeDownloads == 0) {
            break;
          }
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }

        final itemToDownload = _queue[nextIndex];
        // Mark as searching immediately to prevent worker race conditions
        _queue[nextIndex] = itemToDownload.copyWith(
          status: DownloadStatus.searching,
          statusMessage: 'Подготовка к поиску...',
        );
        notifyListeners();

        // Launch download worker
        _downloadTrack(_queue[nextIndex]);

        // Polite delay between launching tasks in queue to avoid rate limits
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _downloadTrack(DownloadItem item) async {
    final track = item.track;

    void updateStatus({
      required DownloadStatus status,
      required String message,
      double? progress,
      String? localPath,
      String? error,
      int? downloaded,
      int? total,
    }) {
      final idx = _queue.indexWhere((q) => q.track.id == track.id);
      if (idx != -1) {
        _queue[idx] = _queue[idx].copyWith(
          status: status,
          statusMessage: message,
          progress: progress,
          localPath: localPath,
          error: error,
          downloadedBytes: downloaded,
          totalBytes: total,
        );
        notifyListeners();
      }
    }

    try {
      // 1. Resolve Target Directory
      final targetDir =
          await MediaStoreHelper.getMusicDirectory(subFolder: _subFolder);

      // 2. Check Deduplication
      final existing = await MediaStoreHelper.findExistingTrackFile(
        directory: targetDir,
        artist: track.artist,
        title: track.title,
        ext: _audioFormat,
      );

      if (existing != null) {
        updateStatus(
          status: DownloadStatus.skipped,
          message: 'Пропущен (уже скачан)',
          progress: 1.0,
          localPath: existing.path,
        );
        return;
      }

      int attempt = 0;
      const maxAttempts = 3;

      while (attempt < maxAttempts) {
        attempt++;
        File? tempFile;

        try {
          if (_isCancelled) {
            updateStatus(status: DownloadStatus.cancelled, message: 'Отменено');
            return;
          }

          // 3. YouTube Cascade Search
          updateStatus(
            status: DownloadStatus.searching,
            message: attempt > 1
                ? 'Повторный поиск аудио на YouTube ($attempt/$maxAttempts)...'
                : 'Поиск лучшего аудио на YouTube...',
          );

          final match = await _searchEngine.findBestAudioStream(
            track,
            onStatusUpdate: (msg) {
              updateStatus(status: DownloadStatus.searching, message: msg);
            },
          );

          if (match == null) {
            updateStatus(
              status: DownloadStatus.failed,
              message: 'Не найден подходящий трек на YouTube',
              error: 'Не удалось найти подходящий аудиопоток для "${track.artist} - ${track.title}"',
            );
            return;
          }

          if (_isCancelled) {
            updateStatus(status: DownloadStatus.cancelled, message: 'Отменено');
            return;
          }

          // 4. Download Stream to Temp File
          updateStatus(
            status: DownloadStatus.downloading,
            message: 'Подключение к аудиопотоку...',
            progress: 0.05,
          );

          final tempDir = await getTemporaryDirectory();
          tempFile = File(p.join(
            tempDir.path,
            'tmp_${track.trackNumber}_${DateTime.now().millisecondsSinceEpoch}.${_audioFormat}',
          ));

          final stream = _ytClient.videos.streamsClient.get(match.streamInfo);
          final fileSink = tempFile.openWrite();

          final totalBytes = match.streamInfo.size.totalBytes;
          int downloadedBytes = 0;
          int lastReportedPercent = -1;
          int lastReportedTime = 0;

          // Apply a 25-second inactivity timeout to prevent frozen downloads
          final streamWithTimeout = stream.timeout(
            const Duration(seconds: 25),
            onTimeout: (sink) {
              sink.addError(
                TimeoutException('Таймаут передачи аудиопотока YouTube (25 сек)'),
              );
            },
          );

          try {
            await for (final chunk in streamWithTimeout) {
              if (_isCancelled) {
                await fileSink.flush();
                await fileSink.close();
                if (await tempFile.exists()) await tempFile.delete();
                updateStatus(
                  status: DownloadStatus.cancelled,
                  message: 'Отменено',
                );
                return;
              }

              fileSink.add(chunk);
              downloadedBytes += chunk.length;

              final double progress = totalBytes > 0
                  ? (downloadedBytes / totalBytes).clamp(0.0, 0.95)
                  : 0.5;

              final percent = (progress * 100).toInt();
              final now = DateTime.now().millisecondsSinceEpoch;

              // Throttle UI progress updates to avoid flooding main isolate (smooth 60/120 FPS)
              if ((percent != lastReportedPercent && (now - lastReportedTime >= 100)) ||
                  percent == 95) {
                lastReportedPercent = percent;
                lastReportedTime = now;
                updateStatus(
                  status: DownloadStatus.downloading,
                  message: 'Скачивание $percent%...',
                  progress: progress,
                  downloaded: downloadedBytes,
                  total: totalBytes,
                );
              }
            }

            await fileSink.flush();
            await fileSink.close();
          } catch (streamErr) {
            await fileSink.flush();
            await fileSink.close();
            if (await tempFile.exists()) await tempFile.delete();
            rethrow;
          }

          // Verify file size
          final finalTempSize = await tempFile.length();
          if (finalTempSize < AppConstants.minValidAudioBytes) {
            if (await tempFile.exists()) await tempFile.delete();
            updateStatus(
              status: DownloadStatus.failed,
              message: 'Файл слишком мал (заглушка)',
              error: 'Stream size < 500 KB',
            );
            return;
          }

          // 5. Ingest ID3v2 Tags and Album Cover
          updateStatus(
            status: DownloadStatus.tagging,
            message: 'Вшивка тегов и обложки...',
            progress: 0.96,
          );

          try {
            await _tagger.tagMp3File(tempFile, track);
          } catch (e) {
            debugPrint('Tagging non-critical warning: $e');
          }

          // 6. Move to Target Music Directory
          final finalFilename = TrackTitleCleaner.buildFilename(
            trackNumber: track.trackNumber,
            artist: track.artist,
            title: track.title,
            ext: _audioFormat,
            includeNumber: true,
            totalTracks: _queue.length,
          );

          final finalTargetFile = File(p.join(targetDir.path, finalFilename));
          if (await finalTargetFile.exists()) {
            await finalTargetFile.delete();
          }
          await tempFile.copy(finalTargetFile.path);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }

          updateStatus(
            status: DownloadStatus.finished,
            message: 'Готово',
            progress: 1.0,
            localPath: finalTargetFile.path,
          );

          // Success - exit retry loop
          return;
        } on RequestLimitExceededException catch (e) {
          if (tempFile != null && await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }

          if (attempt < maxAttempts && !_isCancelled) {
            updateStatus(
              status: DownloadStatus.searching,
              message: 'Лимит YouTube (429). Пауза 8с перед повтором ($attempt/$maxAttempts)...',
            );
            _resetYtClient();
            await Future.delayed(const Duration(seconds: 8));
            continue;
          } else {
            updateStatus(
              status: DownloadStatus.failed,
              message: 'Лимит запросов YouTube (429)',
              error: 'YouTube временно ограничил запросы с вашего IP адреса (Rate Limit / 429).\n\n'
                     'РЕКОМЕНДАЦИИ ДЛЯ РЕШЕНИЯ:\n'
                     '1. Если у вас включен VPN (значок ключа вверху экрана) — обязательно отключите его или смените сервер. Серверы YouTube строго блокируют общедоступные IP-адреса VPN.\n'
                     '2. Подождите 1–2 минуты для сброса счетчика запросов YouTube.\n'
                     '3. Нажмите кнопку «Повторить» или иконку обновления в шапке очереди.\n\n'
                     'Технические данные:\n$e',
            );
            return;
          }
        } catch (e) {
          if (tempFile != null && await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (_) {}
          }

          if (attempt < maxAttempts &&
              (e is TimeoutException ||
                  e.toString().contains('ClientException') ||
                  e.toString().contains('SocketException')) &&
              !_isCancelled) {
            updateStatus(
              status: DownloadStatus.searching,
              message: 'Сбой соединения. Пауза 3с перед повтором ($attempt/$maxAttempts)...',
            );
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }

          updateStatus(
            status: DownloadStatus.failed,
            message: 'Ошибка: $e',
            error: e.toString(),
          );
          return;
        }
      }
    } catch (outerErr) {
      updateStatus(
        status: DownloadStatus.failed,
        message: 'Ошибка: $outerErr',
        error: outerErr.toString(),
      );
    }
  }

  @override
  void dispose() {
    _ytClient.close();
    _searchEngine.close();
    super.dispose();
  }
}
