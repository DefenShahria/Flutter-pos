import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundServiceManager {
  ForegroundServiceManager._();

  static final ForegroundServiceManager instance = ForegroundServiceManager._();

  bool _isRunning = false;

  bool get isRunning => _isRunning;

  void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'transfer_service_channel',
        channelName: 'Transfer Service',
        channelDescription: 'Active file transfers running in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  Future<void> startService() async {
    if (_isRunning) return;

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'POS App - Active Transfers',
      notificationText: 'File transfers are running in the background',
    );

    if (result is ServiceRequestSuccess) {
      _isRunning = true;
    }
  }

  Future<void> stopService() async {
    if (!_isRunning) return;
    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }
}
