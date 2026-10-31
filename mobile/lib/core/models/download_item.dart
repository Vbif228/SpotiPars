import 'track_item.dart';

enum DownloadStatus {
  queued,
  searching,
  downloading,
  tagging,
  finished,
  failed,
  skipped,
  cancelled,
}

class DownloadItem {
  final TrackItem track;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String statusMessage;
  final String? localPath;
  final String? error;
  final int downloadedBytes;
  final int totalBytes;

  const DownloadItem({
    required this.track,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.statusMessage = 'В очереди',
    this.localPath,
    this.error,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
  });

  bool get isCompleted =>
      status == DownloadStatus.finished ||
      status == DownloadStatus.skipped ||
      status == DownloadStatus.failed ||
      status == DownloadStatus.cancelled;

  DownloadItem copyWith({
    TrackItem? track,
    DownloadStatus? status,
    double? progress,
    String? statusMessage,
    String? localPath,
    String? error,
    int? downloadedBytes,
    int? totalBytes,
  }) {
    return DownloadItem(
      track: track ?? this.track,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}
