import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/urls.dart';
import '../../core/services/networkcaller.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/foreground_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/transfer_item.dart';
import '../../data/models/transfer_status.dart';
import '../../data/models/transfer_type.dart';
import 'package:dio/dio.dart' as dio;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/connectivity_service.dart';

class TransferProvider extends ChangeNotifier {
  final NetworkCaller _network = NetworkCaller.instance;
  final NotificationService _notifications = NotificationService.instance;

  static const String _prefsKey = 'transfer_history';
  static const Duration _progressThrottle = Duration(milliseconds: 500);

  final List<TransferItem> _transfers = [];
  final Map<String, dio.CancelToken> _cancelTokens = {};
  final Map<String, DateTime> _lastProgressUpdate = {};

  StreamSubscription? _connectivitySubscription;

  List<TransferItem> get transfers => List.unmodifiable(_transfers);
  List<TransferItem> get activeTransfers =>
      _transfers.where((t) => t.status.isActive).toList();
  int get activeCount => activeTransfers.length;
  bool get hasActiveTransfers => activeCount > 0;

  TransferProvider() {
    _loadHistory();
    _connectivitySubscription =
        ConnectivityService.instance.stream.listen((results) {
      final connected =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      if (connected) {
        unawaited(_resumeOrRetryAll());
      } else {
        _pauseAllActive();
      }
    });
  }

  Future<void> startUpload(File file, String fileName) async {
    final id = const Uuid().v4();
    final item = TransferItem(
      id: id,
      fileName: fileName,
      filePath: file.path,
      type: TransferType.upload,
      status: TransferStatus.uploading,
      totalBytes: file.lengthSync(),
      createdAt: DateTime.now(),
    );
    _transfers.insert(0, item);
    notifyListeners();
    _ensureForegroundService();
    unawaited(_startUploadTask(item));
  }

  Future<void> startDownload(String serverFileName) async {
    final id = const Uuid().v4();
    final tempDir = await getApplicationSupportDirectory();
    final savePath = '${tempDir.path}/.$serverFileName.part';

    final item = TransferItem(
      id: id,
      fileName: serverFileName,
      filePath: savePath,
      type: TransferType.download,
      status: TransferStatus.downloading,
      createdAt: DateTime.now(),
    );
    _transfers.insert(0, item);
    notifyListeners();
    _ensureForegroundService();
    unawaited(_startDownloadTask(item, savePath, 0));
  }

  void pause(String id) {
    final idx = _transfers.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final item = _transfers[idx];
    if (!item.status.isActive) return;

    _cancelTransfer(id);
    _transfers[idx] = item.copyWith(status: TransferStatus.paused);
    notifyListeners();
    _checkForegroundService();
  }

  Future<void> resume(String id) async {
    final idx = _transfers.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final item = _transfers[idx];
    if (item.status != TransferStatus.paused) return;

    if (item.type == TransferType.download) {
      final partFile = File(item.filePath);
      final existing = partFile.existsSync() ? partFile.lengthSync() : 0;
      _transfers[idx] = item.copyWith(
        status: TransferStatus.downloading,
        bytesTransferred: existing,
      );
      notifyListeners();
      unawaited(_startDownloadTask(item, item.filePath, existing));
    } else {
      // Upload restarts from zero — server-side multipart resume not supported.
      _transfers[idx] = item.copyWith(
        status: TransferStatus.uploading,
        bytesTransferred: 0,
      );
      notifyListeners();
      unawaited(_startUploadTask(item));
    }
    _ensureForegroundService();
  }

  Future<void> retry(String id) async {
    final idx = _transfers.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final item = _transfers[idx];
    // Downloads resume from whatever partial bytes are on disk.
    final existing = item.type == TransferType.download
        ? (File(item.filePath).existsSync()
            ? File(item.filePath).lengthSync()
            : 0)
        : 0;

    _transfers[idx] = item.copyWith(
      status: item.type == TransferType.upload
          ? TransferStatus.uploading
          : TransferStatus.downloading,
      bytesTransferred: existing,
      errorMessage: null,
    );
    notifyListeners();
    _ensureForegroundService();

    if (item.type == TransferType.download) {
      unawaited(_startDownloadTask(item, item.filePath, existing));
    } else {
      unawaited(_startUploadTask(item));
    }
  }

  void _pauseAllActive() {
    for (final item in activeTransfers) {
      pause(item.id);
    }
  }

  Future<void> _resumeOrRetryAll() async {
    final pausedOrFailed = _transfers
        .where((t) =>
            t.status == TransferStatus.paused ||
            t.status == TransferStatus.failed)
        .toList();
    for (final item in pausedOrFailed) {
      if (item.status == TransferStatus.paused) {
        await resume(item.id);
      } else if (item.status == TransferStatus.failed) {
        await retry(item.id);
      }
    }
  }

  void cancel(String id) {
    _cancelTransfer(id);
    final idx = _transfers.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _transfers[idx] =
          _transfers[idx].copyWith(status: TransferStatus.cancelled);
      notifyListeners();
    }
    _checkForegroundService();
  }

  void remove(String id) {
    _cancelTransfer(id);
    _transfers.removeWhere((t) => t.id == id);
    _saveHistory();
    notifyListeners();
    _checkForegroundService();
  }

  void clearCompleted() {
    _transfers.removeWhere((t) => t.status.isTerminal);
    _saveHistory();
    notifyListeners();
  }

  void _ensureForegroundService() {
    if (!ForegroundServiceManager.instance.isRunning && activeCount > 0) {
      ForegroundServiceManager.instance.startService();
    }
  }

  void _checkForegroundService() {
    if (!hasActiveTransfers) {
      ForegroundServiceManager.instance.stopService();
    }
  }

  void _cancelTransfer(String id) {
    _cancelTokens[id]?.cancel();
    _cancelTokens.remove(id);
    _lastProgressUpdate.remove(id);
  }

  Future<void> _startUploadTask(TransferItem item) async {
    final cancelToken = dio.CancelToken();
    _cancelTokens[item.id] = cancelToken;

    final file = File(item.filePath);
    if (!await file.exists()) {
      _failTransfer(item, 'Source file not found.');
      return;
    }

    try {
      final response = await _network.uploadFile(
        filePath: file.path,
        onSendProgress: (sent, total) {
          if (cancelToken.isCancelled) return;
          _throttleProgress(item.id, () {
            final updated = item.copyWith(
              bytesTransferred: sent,
              totalBytes: total > 0 ? total : item.totalBytes,
              updatedAt: DateTime.now(),
            );
            final i = _transfers.indexOf(item);
            if (i != -1) _transfers[i] = updated;
            notifyListeners();
          });
        },
        cancelToken: cancelToken,
      );

      if (cancelToken.isCancelled) return;

      if (!response.isSuccess) {
        _failTransfer(item, response.errorMessage);
        return;
      }

      String returnedName = item.fileName;
      final data = response.responseData;
      if (data is Map) {
        returnedName = data['name']?.toString() ??
            data['filename']?.toString() ??
            data['file']?.toString() ??
            (data['url']?.toString() ?? '').split('/').last;
        if (returnedName.isEmpty) returnedName = item.fileName;
      } else if (data is String && data.isNotEmpty) {
        returnedName = data;
      }

      final completed = item.copyWith(
        fileName: returnedName,
        status: TransferStatus.completed,
        bytesTransferred: item.totalBytes,
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final i = _transfers.indexOf(item);
      if (i != -1) _transfers[i] = completed;
      _saveHistory();
      notifyListeners();
      _showCompletionNotification(completed, true);
      _checkForegroundService();
    } catch (e) {
      if (cancelToken.isCancelled) return;
      _failTransfer(item, e.toString());
    }
  }

  Future<void> _startDownloadTask(
    TransferItem item,
    String savePath,
    int resumeFrom,
  ) async {
    final cancelToken = dio.CancelToken();
    _cancelTokens[item.id] = cancelToken;

    final downloadUrl = Urls.download(item.fileName);

    try {
      final headers = resumeFrom > 0 ? {'Range': 'bytes=$resumeFrom-'} : null;

      final response = await _network.downloadFile(
        url: downloadUrl,
        savePath: savePath,
        onReceiveProgress: (received, total) {
          if (cancelToken.isCancelled) return;
          _throttleProgress(item.id, () {
            final updated = item.copyWith(
              bytesTransferred: received,
              totalBytes: total > 0 ? total : item.totalBytes,
              updatedAt: DateTime.now(),
            );
            final idx = _transfers.indexOf(item);
            if (idx != -1) _transfers[idx] = updated;
            notifyListeners();
          });
        },
        cancelToken: cancelToken,
        extraHeaders: headers,
        resumeFrom: resumeFrom,
      );

      if (cancelToken.isCancelled) return;

      // Server returned 200 when we expected 206 — it doesn't support Range.
      // Delete the stale partial file and restart from zero.
      if (!response.isSuccess && response.statusCode == 200) {
        final partFile = File(savePath);
        if (partFile.existsSync()) await partFile.delete();
        await _startDownloadTask(
          item.copyWith(bytesTransferred: 0, totalBytes: 0),
          savePath,
          0,
        );
        return;
      }

      if (!response.isSuccess) {
        _failTransfer(item, response.errorMessage);
        return;
      }

      final partFile = File(savePath);
      if (partFile.existsSync()) {
        final destPath = await _moveToDownloads(partFile, item.fileName);
        final completed = item.copyWith(
          status: TransferStatus.completed,
          filePath: destPath,
          bytesTransferred: item.totalBytes,
          completedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final idx = _transfers.indexOf(item);
        if (idx != -1) _transfers[idx] = completed;
        _saveHistory();
        notifyListeners();
        _showCompletionNotification(completed, true);
      }

      _checkForegroundService();
    } catch (e) {
      if (cancelToken.isCancelled) return;
      _failTransfer(item, e.toString());
    }
  }

  void _failTransfer(TransferItem item, String reason) {
    final idx = _transfers.indexOf(item);
    if (idx == -1) return;
    _cancelTokens.remove(item.id);
    _lastProgressUpdate.remove(item.id);
    final failed = item.copyWith(
      status: TransferStatus.failed,
      errorMessage: reason,
      updatedAt: DateTime.now(),
    );
    _transfers[idx] = failed;
    _saveHistory();
    notifyListeners();
    _showCompletionNotification(failed, false);
    _checkForegroundService();
  }

  void _throttleProgress(String id, VoidCallback callback) {
    final now = DateTime.now();
    final last = _lastProgressUpdate[id];
    if (last != null && now.difference(last) < _progressThrottle) return;
    _lastProgressUpdate[id] = now;
    callback();
    _sendProgressNotification(id);
  }

  // Upload and download share the same ID space from hashCode. The type offset
  // ensures a UUID that happens to hash the same won't collide.
  int _notifId(TransferItem item) {
    final base = item.id.hashCode & 0x3FFFFFFF;
    return item.type == TransferType.upload ? base : base + 10000000;
  }

  void _sendProgressNotification(String id) {
    final idx = _transfers.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final item = _transfers[idx];
    final percent = (item.progress * 100).round();
    final content =
        '${Formatters.formatBytes(item.bytesTransferred)} / ${Formatters.formatBytes(item.totalBytes)} ($percent%)';
    _notifications.showProgressNotification(
      id: _notifId(item),
      title: '${item.type.label}ing',
      content: content,
      percent: percent,
      isUpload: item.type == TransferType.upload,
    );
  }

  void _showCompletionNotification(TransferItem item, bool success) {
    final notifId = _notifId(item);
    _notifications.dismissProgressNotification(notifId);
    _notifications.showCompletionNotification(
      id: notifId,
      title: '${item.type.label} ${success ? "Complete" : "Failed"}',
      subtitle: item.fileName,
      success: success,
      screenPayload: 'transfers',
    );
  }

  Future<String> _moveToDownloads(File partFile, String fileName) async {
    try {
      final dirs =
          await getExternalStorageDirectories(type: StorageDirectory.downloads);
      final downloadsDir = (dirs != null && dirs.isNotEmpty)
          ? dirs.first
          : Directory('${(await getExternalStorageDirectory())!.path}/POSApp');
      await downloadsDir.create(recursive: true);
      final destPath = '${downloadsDir.path}/$fileName';
      await partFile.rename(destPath);
      return destPath;
    } catch (_) {
      // Fallback: app-local storage when external storage is not writable.
      final appDir = await getApplicationSupportDirectory();
      final destPath = '${appDir.path}/$fileName';
      await partFile.copy(destPath);
      await partFile.delete();
      return destPath;
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final e in list) {
        var item = TransferItem.fromJson(Map<String, dynamic>.from(e as Map));
        // Transfers that were active before process death are restored as paused.
        if (item.status.isActive) {
          item = item.copyWith(status: TransferStatus.paused);
        }
        _transfers.add(item);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to restore transfer history: $e');
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final toSave = _transfers
        .where((t) => !t.status.isTerminal)
        .map((t) => t.toJson())
        .toList();
    await prefs.setString(_prefsKey, jsonEncode(toSave));
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    for (final token in _cancelTokens.values) {
      token.cancel();
    }
    super.dispose();
  }
}
