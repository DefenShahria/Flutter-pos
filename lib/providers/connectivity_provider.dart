import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/connectivity_service.dart';

class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _service = ConnectivityService.instance;

  bool _isConnected = true;
  StreamSubscription? _subscription;

  bool get isConnected => _isConnected;

  ConnectivityProvider() {
    _init();
  }

  Future<void> _init() async {
    await _service.init();
    _isConnected = _service.lastResult != ConnectivityResult.none;
    notifyListeners();

    _subscription = _service.stream.listen((results) {
      final connected =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      if (_isConnected != connected) {
        _isConnected = connected;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
