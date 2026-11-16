import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  String? _lastTapPayload;

  String? consumeLastTapPayload() {
    final payload = _lastTapPayload;
    _lastTapPayload = null;
    return payload;
  }

  void Function(String payload)? onNotificationTap;

  static const String _channelIdProgress = 'transfer_progress_channel';
  static const String _channelIdCompletion = 'transfer_completion_channel';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _lastTapPayload = launchDetails?.notificationResponse?.payload;
    }

    await _createChannels();
    _initialized = true;
  }

  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelIdProgress,
      'Transfer Progress',
      description: 'Shows ongoing upload/download progress',
      importance: Importance.low,
      playSound: false,
    ));

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelIdCompletion,
      'Transfer Completion',
      description: 'Shows transfer completed or failed notification',
      importance: Importance.high,
      playSound: true,
    ));
  }

  Future<bool> requestPermission() async {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return result ?? false;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload ?? '';
    _lastTapPayload = payload;
    onNotificationTap?.call(payload);
  }

  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String content,
    required int percent,
    bool isUpload = false,
  }) async {
    if (!_initialized) return;

    await _plugin.show(
      id,
      title,
      content,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdProgress,
          'Transfer Progress',
          channelDescription: 'Ongoing transfer progress',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
        ),
      ),
      payload: '$id|$isUpload',
    );
  }

  Future<void> dismissProgressNotification(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id);
  }

  Future<void> showCompletionNotification({
    required int id,
    required String title,
    required String subtitle,
    required bool success,
    required String screenPayload,
  }) async {
    if (!_initialized) return;

    final body = success ? 'Completed' : 'Failed';

    await _plugin.show(
      // Offset completion IDs by 20 million to avoid colliding with progress IDs.
      id + 20000000,
      title,
      '$body: $subtitle',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelIdCompletion,
          'Transfer Completion',
          channelDescription: 'Transfer finished or failed',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: false,
          autoCancel: true,
          styleInformation: const DefaultStyleInformation(true, true),
        ),
      ),
      payload: screenPayload,
    );
  }
}
