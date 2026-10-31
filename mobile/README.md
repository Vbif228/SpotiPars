# SpotiPars Mobile (Android)

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android_8.0+-1DB954?style=for-the-badge&logo=android&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Framework-Flutter_3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Language-Dart_3-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Style-Spotify_Dark-121212?style=for-the-badge&logo=spotify&logoColor=1DB954" alt="Style">
</p>

Быстрый, современный и бессерверный загрузчик треков, альбомов и плейлистов из Spotify для Android. Написан на Flutter/Dart на базе проверенной архитектурной спецификации SpotiPars.

---

## 🌟 Ключевые возможности

- 🎧 **Интеграция с системным меню «Поделиться»:** Нажмите «Поделиться» на треке или плейлисте в приложении Spotify, выберите **SpotiPars** — приложение сразу откроется и покажет треки, готовые к загрузке.
- ⚡ **Бессерверный парсер метаданных:** Работает без платных API-ключей Spotify благодаря парсингу `open.spotify.com/embed` (`__NEXT_DATA__` JSON), OpenGraph и oEmbed.
- 🔍 **Каскадный поиск YouTube с обходом Topic/PO-Token DRM:**
  - Очистка названий от суффиксов переизданий (`- 2007 Remaster`, `(Deluxe)` и т.д.).
  - Приоритетный поиск `lyrics` и `official audio` (100% содержит оригинальный студийный звук и не блокируется YouTube Music Topic защитой).
  - Фильтрация аудиозаглушек (< 500 КБ).
- 🏷️ **Вшивка метаданных ID3v2.3 и обложек:** Название, исполнитель, альбом, номер трека и полноразмерная обложка JPEG вшиваются прямо в MP3.
- 📁 **Экспорт в системный MediaStore:** Треки сохраняются в `/storage/emulated/0/Music/SpotiPars` (с опциональной подпапкой плейлиста) и мгновенно распознаются всеми аудиопроигрывателями (Poweramp, AIMP, Samsung Music, YT Music).
- 📲 **Android Foreground Service:** Непрерывная фоновая загрузка даже при заблокированном экране телефона со шкалой прогресса в шторке уведомлений.
- 🎨 **Spotify Dark UI:** Стильный минималистичный темный интерфейс (#121212 / #1DB954) с плавными 60/120 FPS анимациями.

---

## 📐 Архитектура проекта

```text
spotipars_mobile/
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml       <-- Intent-фильтр ACTION_SEND, Foreground Service, Permissions
├── lib/
│   ├── core/
│   │   ├── constants/                <-- Константы, битрейт, директории
│   │   ├── models/                   <-- TrackItem, PlaylistInfo, DownloadItem
│   │   ├── spotify/                  <-- SpotifyScraper (Embed, JSON, OpenGraph, oEmbed)
│   │   ├── youtube/                  <-- TrackTitleCleaner, YouTubeSearchEngine (Каскад поиска)
│   │   ├── downloader/               <-- AudioDownloadManager (Многопоточная очередь)
│   │   ├── tagger/                   <-- Id3Tagger (ID3v2.3 фреймы + APIC Cover)
│   │   └── storage/                  <-- MediaStoreHelper (Запись в Music/SpotiPars)
│   ├── services/
│   │   ├── foreground_download_service.dart <-- Foreground Service и уведомления
│   │   └── share_intent_receiver.dart       <-- Перехватчик ссылок из Spotify
│   ├── ui/
│   │   ├── theme/                    <-- Spotify Dark Palette
│   │   ├── widgets/                  <-- TrackListTile, DownloadProgressBar, FormatChips
│   │   └── screens/                  <-- HomeScreen, PreviewScreen, QueueScreen, SettingsScreen
│   └── main.dart
├── test/
│   ├── standalone_core_test.dart     <-- 13 автоматических тестов ядра
│   └── run_tests.dart
├── .github/workflows/
│   └── build_apk.yml                 <-- Автоматическая сборка APK через GitHub Actions
├── build_apk.bat                     <-- Скрипт локальной сборки
└── pubspec.yaml
```

---

## 🚀 Сборка и запуск

### Вариант 1: Сборка через GitHub Actions (Рекомендуется)
1. Отправьте проект в свой GitHub-репозиторий:
   ```bash
   git init
   git add .
   git commit -m "feat: SpotiPars Mobile initial release"
   git remote add origin <URL-вашего-репозитория>
   git push -u origin main
   ```
2. Перейдите во вкладку **Actions** в репозитории на GitHub.
3. Дождитесь завершения сборки workflow **Build SpotiPars Android APK** (~2–3 минуты).
4. Скачайте готовый `app-release.apk` из блока **Artifacts**.

### Вариант 2: Локальная сборка на ПК
1. Установите [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) и Android Studio.
2. Откройте терминал в папке `spotipars_mobile/` и выполните:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
3. Готовый APK будет расположен по адресу:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔒 Разрешения Android

| Разрешение | Назначение |
| :--- | :--- |
| `INTERNET` | Загрузка метаданных Spotify и аудиопотоков YouTube |
| `FOREGROUND_SERVICE_DATA_SYNC` | Фоновая работа процесса загрузки при заблокированном экране |
| `POST_NOTIFICATIONS` | Отображение прогресс-бара загрузки в шторке уведомлений (Android 13+) |
| `WAKE_LOCK` | Предотвращение засыпания процессора во время загрузки очереди |
| `WRITE_EXTERNAL_STORAGE` | Запись треков в общедоступную папку `Music/SpotiPars` |
