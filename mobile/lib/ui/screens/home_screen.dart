import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/downloader/audio_download_manager.dart';
import '../../core/spotify/spotify_scraper.dart';
import '../theme/spotify_theme.dart';
import '../widgets/format_selector_chips.dart';
import 'preview_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final AudioDownloadManager? downloadManager;
  final VoidCallback? onNavigateToQueue;

  const HomeScreen({
    Key? key,
    this.downloadManager,
    this.onNavigateToQueue,
  }) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final SpotifyScraper _scraper = SpotifyScraper();

  bool _isLoading = false;
  String _selectedFormat = AppConstants.formatMp3;
  bool _createSubfolder = true;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
        _errorMessage = null;
      });
      _parseAndNavigate();
    }
  }

  Future<void> _parseAndNavigate() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Вставьте ссылку на трек или плейлист');
      return;
    }

    final parsed = SpotifyScraper.parseUrl(input);
    if (parsed == null) {
      setState(() => _errorMessage = 'Некорректная ссылка Spotify');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final playlistInfo = await _scraper.fetchEntity(input);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            playlistInfo: playlistInfo,
            audioFormat: _selectedFormat,
            createSubfolder: _createSubfolder,
            downloadManager: widget.downloadManager ?? AudioDownloadManager.instance,
            onStartDownload: widget.onNavigateToQueue,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      setState(() {
        _errorMessage = 'Сбой: $errorStr';
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SpotifyTheme.surface,
          title: Row(
            children: const [
              Icon(Icons.error_outline, color: SpotifyTheme.error, size: 24),
              SizedBox(width: 8),
              Text(
                'Сбой загрузки данных',
                style: TextStyle(color: SpotifyTheme.textPrimary, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Не удалось получить метаданные по ссылке Spotify.',
                style: TextStyle(color: SpotifyTheme.textSecondary, fontSize: 13),
              ),
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
                  errorStr,
                  style: const TextStyle(
                    color: SpotifyTheme.error,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Рекомендации:\n'
                '• Убедитесь, что интернет работает на телефоне\n'
                '• Если Spotify блокируется оператором, включите VPN\n'
                '• Проверьте, что ссылка не из приватного плейлиста',
                style: TextStyle(
                  color: SpotifyTheme.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Понятно', style: TextStyle(color: SpotifyTheme.spotifyGreen)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SpotifyTheme.spotifyGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.music_note, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('SpotiPars Mobile'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome & Description Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SpotifyTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpotifyTheme.borderColor, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Скачивайте музыку из Spotify',
                    style: TextStyle(
                      color: SpotifyTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Вставьте ссылку на трек, альбом или плейлист, либо нажмите «Поделиться» в официальном приложении Spotify.',
                    style: TextStyle(
                      color: SpotifyTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Input field
            TextField(
              controller: _urlController,
              style: const TextStyle(color: SpotifyTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'https://open.spotify.com/playlist/...',
                prefixIcon: const Icon(
                  Icons.link,
                  color: SpotifyTheme.spotifyGreen,
                ),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: SpotifyTheme.textSecondary),
                        onPressed: () {
                          setState(() {
                            _urlController.clear();
                            _errorMessage = null;
                          });
                        },
                      )
                    : null,
              ),
              onSubmitted: (_) => _parseAndNavigate(),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: SpotifyTheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Paste from clipboard button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _pasteFromClipboard,
              icon: const Icon(Icons.content_paste, size: 18),
              label: const Text('Вставить из буфера'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SpotifyTheme.textPrimary,
                side: const BorderSide(color: SpotifyTheme.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Audio Format Selection
            const Text(
              'Формат аудио',
              style: TextStyle(
                color: SpotifyTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            FormatSelectorChips(
              selectedFormat: _selectedFormat,
              onFormatChanged: (format) {
                setState(() => _selectedFormat = format);
              },
            ),

            const SizedBox(height: 16),

            // Subfolder Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: SpotifyTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SpotifyTheme.borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.folder_outlined, color: SpotifyTheme.spotifyGreen, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Подпапка для плейлиста',
                        style: TextStyle(
                          color: SpotifyTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _createSubfolder,
                    activeColor: SpotifyTheme.spotifyGreen,
                    onChanged: (val) => setState(() => _createSubfolder = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Submit / Action Button
            ElevatedButton(
              onPressed: _isLoading ? null : _parseAndNavigate,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text('Открыть и подготовить к загрузке'),
            ),

            const SizedBox(height: 28),

            // Share feature instruction guide
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SpotifyTheme.surfaceElevated.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.share, color: SpotifyTheme.spotifyGreen, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Как скачивать в 1 клик из Spotify:',
                        style: TextStyle(
                          color: SpotifyTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. В официальном приложении Spotify откройте любой трек или плейлист.\n'
                    '2. Нажмите меню с тремя точками (⋮) ➔ «Поделиться».\n'
                    '3. Выберите SpotiPars — загрузка откроется автоматически!',
                    style: TextStyle(
                      color: SpotifyTheme.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
