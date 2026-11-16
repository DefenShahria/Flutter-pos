import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  Stream<List<ConnectivityResult>> get stream => _controller.stream;

  ConnectivityResult? _lastResult;
  ConnectivityResult? get lastResult => _lastResult;

  bool get isConnected =>
      _lastResult != null && _lastResult != ConnectivityResult.none;

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _lastResult = results.isEmpty ? null : results.first;
    _connectivity.onConnectivityChanged.listen((results) {
      _lastResult = results.isEmpty ? null : results.first;
      _controller.add(results);
    });
  }

  void dispose() {
    _controller.close();
  }
}
