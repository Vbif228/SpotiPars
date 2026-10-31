import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/downloader/audio_download_manager.dart';
import 'core/models/download_item.dart';
import 'core/spotify/spotify_scraper.dart';
import 'services/foreground_download_service.dart';
import 'services/share_intent_receiver.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/preview_screen.dart';
import 'ui/screens/queue_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/theme/spotify_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background foreground service
  await ForegroundDownloadService.initialize();

  runApp(
    const ProviderScope(
      child: SpotiParsApp(),
    ),
  );
}

class SpotiParsApp extends StatelessWidget {
  const SpotiParsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotiPars Mobile',
      debugShowCheckedModeBanner: false,
      theme: SpotifyTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({Key? key}) : super(key: key);

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final AudioDownloadManager _downloadManager = AudioDownloadManager();
  final ShareIntentReceiver _intentReceiver = ShareIntentReceiver();
  final SpotifyScraper _scraper = SpotifyScraper();

  @override
  void initState() {
    super.initState();

    // Listen for incoming links from Android 'Share' menu in Spotify
    _intentReceiver.initialize(
      onLinkReceived: (url) {
        _handleSharedLink(url);
      },
    );
  }

  Future<void> _handleSharedLink(String url) async {
    try {
      final info = await _scraper.fetchEntity(url);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            playlistInfo: info,
            audioFormat: _downloadManager.audioFormat,
            createSubfolder: true,
            downloadManager: _downloadManager,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка распознавания ссылки: $e'),
          backgroundColor: SpotifyTheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _intentReceiver.dispose();
    _downloadManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _downloadManager,
      builder: (context, _) {
        final activeCount = _downloadManager.queue
            .where((i) =>
                i.status == DownloadStatus.downloading ||
                i.status == DownloadStatus.searching ||
                i.status == DownloadStatus.tagging ||
                i.status == DownloadStatus.queued)
            .length;

        final screens = [
          const HomeScreen(),
          QueueScreen(downloadManager: _downloadManager),
          SettingsScreen(downloadManager: _downloadManager),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.search),
                selectedIcon: Icon(Icons.search, color: SpotifyTheme.spotifyGreen),
                label: 'Поиск',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text('$activeCount'),
                  child: const Icon(Icons.download),
                ),
                selectedIcon: Badge(
                  isLabelVisible: activeCount > 0,
                  label: Text('$activeCount'),
                  child: const Icon(Icons.download, color: SpotifyTheme.spotifyGreen),
                ),
                label: 'Очередь',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings),
                selectedIcon: Icon(Icons.settings, color: SpotifyTheme.spotifyGreen),
                label: 'Настройки',
              ),
            ],
          ),
        );
      },
    );
  }
}
