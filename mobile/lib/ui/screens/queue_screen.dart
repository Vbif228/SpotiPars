import 'package:flutter/material.dart';
import '../../core/downloader/audio_download_manager.dart';
import '../../core/models/download_item.dart';
import '../theme/spotify_theme.dart';
import '../widgets/download_progress_bar.dart';

class QueueScreen extends StatelessWidget {
  final AudioDownloadManager downloadManager;

  const QueueScreen({Key? key, required this.downloadManager})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: downloadManager,
      builder: (context, _) {
        final queue = downloadManager.queue;
        final finishedCount = queue
            .where((i) =>
                i.status == DownloadStatus.finished ||
                i.status == DownloadStatus.skipped)
            .length;
        final activeCount = queue
            .where((i) =>
                i.status == DownloadStatus.downloading ||
                i.status == DownloadStatus.searching ||
                i.status == DownloadStatus.tagging)
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Очередь загрузок'),
            actions: [
              if (queue.isNotEmpty) ...[
                if (queue.any((i) =>
                    i.status == DownloadStatus.failed ||
                    i.status == DownloadStatus.cancelled))
                  IconButton(
                    tooltip: 'Повторить все ошибки',
                    icon: const Icon(Icons.refresh, color: SpotifyTheme.spotifyGreen),
                    onPressed: () => downloadManager.retryFailed(),
                  ),
                IconButton(
                  tooltip: 'Очистить завершенные',
                  icon: const Icon(Icons.cleaning_services_outlined),
                  onPressed: () => downloadManager.clearCompleted(),
                ),
                IconButton(
                  tooltip: 'Отменить все',
                  icon: const Icon(Icons.cancel_outlined, color: SpotifyTheme.error),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: SpotifyTheme.surface,
                        title: const Text('Отменить загрузки?'),
                        content: const Text(
                          'Все незавершенные загрузки в очереди будут остановлены.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Назад'),
                          ),
                          TextButton(
                            onPressed: () {
                              downloadManager.cancelAll();
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Отменить все',
                              style: TextStyle(color: SpotifyTheme.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          body: queue.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: SpotifyTheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_done,
                          color: SpotifyTheme.textSecondary,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Очередь загрузок пуста',
                        style: TextStyle(
                          color: SpotifyTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Добавьте треки или плейлист на главном экране',
                        style: TextStyle(
                          color: SpotifyTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Status Summary Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: SpotifyTheme.surface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (activeCount > 0) ...[
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: SpotifyTheme.spotifyGreen,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Активно: $activeCount',
                                  style: const TextStyle(
                                    color: SpotifyTheme.spotifyGreen,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ] else ...[
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: SpotifyTheme.spotifyGreen,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Очередь завершена',
                                  style: TextStyle(
                                    color: SpotifyTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Готово: $finishedCount из ${queue.length}',
                            style: const TextStyle(
                              color: SpotifyTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items list
                    Expanded(
                      child: ListView.builder(
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final item = queue[index];
                          return DownloadProgressBar(
                            item: item,
                            onRetry: () => downloadManager.retryTrack(item.track),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
