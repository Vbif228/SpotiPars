import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/downloader/audio_download_manager.dart';
import '../../core/storage/media_store_helper.dart';
import '../theme/spotify_theme.dart';

class SettingsScreen extends StatefulWidget {
  final AudioDownloadManager downloadManager;

  const SettingsScreen({Key? key, required this.downloadManager})
      : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _concurrency;
  String _currentFolderPath = MediaStoreHelper.defaultMusicPath;

  @override
  void initState() {
    super.initState();
    _concurrency = widget.downloadManager.maxConcurrency;
    _loadCurrentFolder();
  }

  Future<void> _loadCurrentFolder() async {
    final folder = await MediaStoreHelper.getMusicBasePath();
    if (mounted) {
      setState(() {
        _currentFolderPath = folder;
      });
    }
  }

  void _showFolderPickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SpotifyTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'Выберите папку для сохранения музыки',
                    style: TextStyle(
                      color: SpotifyTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...MediaStoreHelper.folderPresets.map((preset) {
                  final isSelected = _currentFolderPath == preset;
                  String label = preset;
                  if (preset == '/storage/emulated/0/Music/SpotiPars') {
                    label = 'Music/SpotiPars (По умолчанию)';
                  } else if (preset == '/storage/emulated/0/Music') {
                    label = 'Music (Общая системная папка)';
                  } else if (preset == '/storage/emulated/0/Download/SpotiPars') {
                    label = 'Download/SpotiPars (Папка Загрузки)';
                  } else if (preset == '/storage/emulated/0/Download') {
                    label = 'Download (Общая папка Загрузок)';
                  }

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.folder_outlined,
                      color: isSelected
                          ? SpotifyTheme.spotifyGreen
                          : SpotifyTheme.textSecondary,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? SpotifyTheme.spotifyGreen
                            : SpotifyTheme.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      preset,
                      style: const TextStyle(
                        color: SpotifyTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await MediaStoreHelper.setMusicBasePath(preset);
                      setState(() => _currentFolderPath = preset);
                    },
                  );
                }),
                const Divider(color: SpotifyTheme.borderColor),
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.edit_note,
                    color: SpotifyTheme.spotifyGreen,
                  ),
                  title: const Text(
                    'Указать другой путь...',
                    style: TextStyle(
                      color: SpotifyTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCustomPathDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomPathDialog() {
    final controller = TextEditingController(text: _currentFolderPath);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SpotifyTheme.surface,
          title: const Text(
            'Свой путь к папке',
            style: TextStyle(color: SpotifyTheme.textPrimary, fontSize: 16),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(
              color: SpotifyTheme.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: const InputDecoration(
              hintText: '/storage/emulated/0/...',
              hintStyle: TextStyle(color: SpotifyTheme.textSecondary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: SpotifyTheme.borderColor),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: SpotifyTheme.spotifyGreen),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: SpotifyTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx);
                  await MediaStoreHelper.setMusicBasePath(text);
                  setState(() => _currentFolderPath = text);
                }
              },
              child: const Text('Сохранить', style: TextStyle(color: SpotifyTheme.spotifyGreen)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Storage Section
          _buildSectionHeader('Хранилище'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpotifyTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SpotifyTheme.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Папка сохранения',
                      style: TextStyle(
                        color: SpotifyTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.folder_open, size: 16, color: SpotifyTheme.spotifyGreen),
                      label: const Text(
                        'Изменить',
                        style: TextStyle(color: SpotifyTheme.spotifyGreen, fontSize: 13),
                      ),
                      onPressed: _showFolderPickerDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentFolderPath,
                  style: const TextStyle(
                    color: SpotifyTheme.spotifyGreen,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Треки автоматически индексируются в MediaStore и сразу видны в системных плеерах (Samsung Music, Poweramp, YouTube Music, AIMP).',
                  style: TextStyle(
                    color: SpotifyTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Download Engine Section
          _buildSectionHeader('Параллельные загрузки'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpotifyTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SpotifyTheme.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Потоков одновременно:',
                      style: TextStyle(
                        color: SpotifyTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$_concurrency',
                      style: const TextStyle(
                        color: SpotifyTheme.spotifyGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _concurrency.toDouble(),
                  min: 1,
                  max: 4,
                  divisions: 3,
                  activeColor: SpotifyTheme.spotifyGreen,
                  inactiveColor: SpotifyTheme.surfaceElevated,
                  onChanged: (val) {
                    final newVal = val.round();
                    setState(() => _concurrency = newVal);
                    widget.downloadManager.configure(maxConcurrency: newVal);
                  },
                ),
                const Text(
                  'Рекомендуется 1 поток для стабильной мобильной загрузки без блокировок YouTube (особенно при работе через VPN).',
                  style: TextStyle(
                    color: SpotifyTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Search Engine Features Section
          _buildSectionHeader('Каскадный поиск и обход защиты'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpotifyTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SpotifyTheme.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '✓ Lyrics Cascade Priority',
                  style: TextStyle(
                    color: SpotifyTheme.spotifyGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Автоматический поиск lyrics-версий со 100% студийным оригиналом звука, полностью обходящий блокировки YouTube Topic и PO-Token DRM.',
                  style: TextStyle(
                    color: SpotifyTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '✓ Фильтр аудиозаглушек (< 500 КБ)',
                  style: TextStyle(
                    color: SpotifyTheme.spotifyGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Автоматическое отсечение 30-секундных превью и битых файлов.',
                  style: TextStyle(
                    color: SpotifyTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('О приложении'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpotifyTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SpotifyTheme.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: SpotifyTheme.spotifyGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '${AppConstants.appName} Mobile',
                          style: TextStyle(
                            color: SpotifyTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Версия ${AppConstants.appVersion}',
                          style: TextStyle(
                            color: SpotifyTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Быстрый бессерверный загрузчик музыки из Spotify для Android. Разработано автономно на базе архитектурной спецификации SpotiPars.',
                  style: TextStyle(
                    color: SpotifyTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: SpotifyTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
