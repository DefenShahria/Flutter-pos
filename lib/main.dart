import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'app.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/foreground_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/networkcaller.dart';
import 'core/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  NetworkCaller.instance.init();
  StorageService.instance.init();
  ConnectivityService.instance.init();
  ForegroundServiceManager.instance.initialize();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermission();
  await FlutterForegroundTask.requestNotificationPermission();

  runApp(const PosApp());
}
