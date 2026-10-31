import 'package:flutter/material.dart';
import '../../core/models/download_item.dart';
import '../theme/spotify_theme.dart';

class DownloadProgressBar extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onRetry;

  const DownloadProgressBar({
    Key? key,
    required this.item,
    this.onRetry,
  }) : super(key: key);

  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpotifyTheme.surface,
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: SpotifyTheme.error, size: 22),
            SizedBox(width: 8),
            Text('Диагностика загрузки', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.track.artist} — ${item.track.title}',
              style: const TextStyle(
                color: SpotifyTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Статус: ${item.statusMessage}',
              style: const TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
            ),
            if (item.error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SpotifyTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SpotifyTheme.borderColor, width: 0.5),
                ),
                child: SelectableText(
                  item.error!,
                  style: const TextStyle(
                    color: SpotifyTheme.error,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Если загрузка не удалась, это может быть вызвано ограничением YouTube или отсутствием связи.',
              style: TextStyle(color: SpotifyTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          if (onRetry != null &&
              (item.status == DownloadStatus.failed ||
                  item.status == DownloadStatus.cancelled))
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onRetry!();
              },
              child: const Text('Повторить'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: SpotifyTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _borderColorForStatus(item.status),
          width: 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showErrorDialog(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: item.track.coverUrl.isNotEmpty
                        ? Image.network(
                            item.track.coverUrl,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackCover(),
                          )
                        : _fallbackCover(),
                  ),
                  const SizedBox(width: 12),

                  // Title & Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Status Badge
                  _buildStatusBadge(item.status),
                ],
              ),

              const SizedBox(height: 10),

              // Progress indicator & status message
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.progress > 0 ? item.progress : null,
                        minHeight: 5,
                        backgroundColor: SpotifyTheme.surfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _progressColorForStatus(item.status),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(item.progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: SpotifyTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Detailed Status Text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.statusMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textColorForStatus(item.status),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (item.status == DownloadStatus.failed)
                    const Text(
                      'Нажмите для деталей',
                      style: TextStyle(color: SpotifyTheme.warning, fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DownloadStatus status) {
    String label;
    Color bg;
    Color fg;

    switch (status) {
      case DownloadStatus.queued:
        label = 'В очереди';
        bg = SpotifyTheme.surfaceElevated;
        fg = SpotifyTheme.textSecondary;
        break;
      case DownloadStatus.searching:
        label = 'Поиск';
        bg = Colors.amber.withOpacity(0.2);
        fg = Colors.amberAccent;
        break;
      case DownloadStatus.downloading:
        label = 'Скачивание';
        bg = Colors.blue.withOpacity(0.2);
        fg = Colors.lightBlueAccent;
        break;
      case DownloadStatus.tagging:
        label = 'Тегирование';
        bg = Colors.purple.withOpacity(0.2);
        fg = Colors.purpleAccent;
        break;
      case DownloadStatus.finished:
        label = 'Готово';
        bg = SpotifyTheme.spotifyGreen.withOpacity(0.2);
        fg = SpotifyTheme.spotifyGreen;
        break;
      case DownloadStatus.skipped:
        label = 'Пропущен';
        bg = Colors.grey.withOpacity(0.2);
        fg = Colors.white70;
        break;
      case DownloadStatus.failed:
        label = 'Ошибка';
        bg = SpotifyTheme.error.withOpacity(0.2);
        fg = SpotifyTheme.error;
        break;
      case DownloadStatus.cancelled:
        label = 'Отменено';
        bg = Colors.grey.withOpacity(0.2);
        fg = Colors.white60;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _borderColorForStatus(DownloadStatus status) {
    if (status == DownloadStatus.finished) {
      return SpotifyTheme.spotifyGreen.withOpacity(0.3);
    }
    if (status == DownloadStatus.failed) {
      return SpotifyTheme.error.withOpacity(0.3);
    }
    return SpotifyTheme.borderColor;
  }

  Color _progressColorForStatus(DownloadStatus status) {
    if (status == DownloadStatus.finished) return SpotifyTheme.spotifyGreen;
    if (status == DownloadStatus.failed) return SpotifyTheme.error;
    if (status == DownloadStatus.skipped) return Colors.grey;
    return SpotifyTheme.spotifyGreen;
  }

  Color _textColorForStatus(DownloadStatus status) {
    if (status == DownloadStatus.failed) return SpotifyTheme.error;
    if (status == DownloadStatus.finished) return SpotifyTheme.spotifyGreen;
    return SpotifyTheme.textSecondary;
  }

  Widget _fallbackCover() {
    return Container(
      width: 42,
      height: 42,
      color: SpotifyTheme.surfaceElevated,
      child: const Icon(
        Icons.music_note,
        color: SpotifyTheme.textSecondary,
        size: 20,
      ),
    );
  }
}
