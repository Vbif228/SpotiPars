import 'package:flutter/material.dart';
import '../../core/downloader/audio_download_manager.dart';
import '../../core/models/playlist_info.dart';
import '../../core/models/track_item.dart';
import '../../services/foreground_download_service.dart';
import '../theme/spotify_theme.dart';
import '../widgets/track_list_tile.dart';

class PreviewScreen extends StatefulWidget {
  final PlaylistInfo playlistInfo;
  final String audioFormat;
  final bool createSubfolder;
  final AudioDownloadManager? downloadManager;

  const PreviewScreen({
    Key? key,
    required this.playlistInfo,
    required this.audioFormat,
    required this.createSubfolder,
    this.downloadManager,
  }) : super(key: key);

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late List<TrackItem> _tracks;

  @override
  void initState() {
    super.initState();
    _tracks = List.from(widget.playlistInfo.tracks);
  }

  bool get _isAllSelected =>
      _tracks.isNotEmpty && _tracks.every((t) => t.isSelected);

  int get _selectedCount => _tracks.where((t) => t.isSelected).length;

  void _toggleSelectAll(bool select) {
    setState(() {
      _tracks = _tracks.map((t) => t.copyWith(isSelected: select)).toList();
    });
  }

  void _toggleTrack(int index, bool selected) {
    setState(() {
      _tracks[index] = _tracks[index].copyWith(isSelected: selected);
    });
  }

  Future<void> _startDownload() async {
    final selected = _tracks.where((t) => t.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы один трек для загрузки'),
          backgroundColor: SpotifyTheme.warning,
        ),
      );
      return;
    }

    final manager = widget.downloadManager;
    if (manager != null) {
      manager.configure(
        audioFormat: widget.audioFormat,
        subFolder: widget.createSubfolder ? widget.playlistInfo.title : '',
      );
      manager.addTracks(selected);

      // Start foreground service for background execution
      await ForegroundDownloadService.startForeground(
        title: 'SpotiPars: Загрузка треков',
        text: 'Скачивание ${selected.length} треков...',
      );
    }

    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Добавлено в очередь: ${selected.length} треков'),
        backgroundColor: SpotifyTheme.spotifyGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.playlistInfo;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          info.type == 'album'
              ? 'Альбом'
              : info.type == 'playlist'
                  ? 'Плейлист'
                  : 'Трек',
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: SpotifyTheme.surface,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: info.coverUrl.isNotEmpty
                      ? Image.network(
                          info.coverUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverFallback(),
                        )
                      : _coverFallback(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SpotifyTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (info.ownerName.isNotEmpty)
                        Text(
                          info.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: SpotifyTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Всего треков: ${info.totalTracksCount} • Формат: ${widget.audioFormat.toUpperCase()}',
                        style: const TextStyle(
                          color: SpotifyTheme.spotifyGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Select All Checkbox Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: SpotifyTheme.borderColor, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _isAllSelected,
                      activeColor: SpotifyTheme.spotifyGreen,
                      checkColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) => _toggleSelectAll(val ?? false),
                    ),
                    const Text(
                      'Выбрать все',
                      style: TextStyle(
                        color: SpotifyTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Выбрано: $_selectedCount из ${_tracks.length}',
                  style: const TextStyle(
                    color: SpotifyTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Track List
          Expanded(
            child: _tracks.isEmpty
                ? const Center(
                    child: Text(
                      'Список треков пуст',
                      style: TextStyle(color: SpotifyTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return TrackListTile(
                        track: track,
                        onToggleSelect: (val) => _toggleTrack(index, val),
                      );
                    },
                  ),
          ),

          // Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: SpotifyTheme.surface,
              border: Border(
                top: BorderSide(color: SpotifyTheme.borderColor, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: _selectedCount > 0 ? _startDownload : null,
                icon: const Icon(Icons.download, color: Colors.black),
                label: Text('Скачать выбранные ($_selectedCount)'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverFallback() {
    return Container(
      width: 80,
      height: 80,
      color: SpotifyTheme.surfaceElevated,
      child: const Icon(
        Icons.album,
        color: SpotifyTheme.textSecondary,
        size: 36,
      ),
    );
  }
}
