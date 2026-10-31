import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../constants/app_constants.dart';

class ForegroundDownloadService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.notificationChannelId,
        channelName: AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDesc,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
  }

  static Future<bool> startForeground({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid) return false;

    await initialize();

    if (await FlutterForegroundTask.isRunningService) {
      return await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } else {
      return await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  static Future<void> updateProgress({
    required String title,
    required String text,
  }) async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  static Future<bool> stopForeground() async {
    if (!Platform.isAndroid) return false;
    if (await FlutterForegroundTask.isRunningService) {
      return await FlutterForegroundTask.stopService();
    }
    return true;
  }
}
