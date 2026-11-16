import 'package:flutter/foundation.dart';
import '../../core/services/networkcaller.dart';
import '../../core/services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final NetworkCaller _network = NetworkCaller.instance;
  final StorageService _storage = StorageService.instance;

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> restoreSession() async {
    final token = _storage.getAuthToken();
    if (token != null && token.isNotEmpty) {
      _network.setAuthToken(token);
      _network.setOnUnauthorized(_autoLogout);
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _setLoading(true);
    _errorMessage = null;

    final response = await _network.postFormRequest(
      path: '/token',
      fields: {'username': username, 'password': password},
    );

    if (response.isSuccess && response.responseData != null) {
      final data = response.responseData;
      String? token;
      if (data is Map) {
        token = data['access_token']?.toString() ??
            data['token']?.toString() ??
            data['accessToken']?.toString() ??
            data['auth_token']?.toString();
      } else if (data is String && data.isNotEmpty) {
        token = data;
      }

      if (token != null && token.isNotEmpty) {
        await _storage.setAuthToken(token);
        _network.setAuthToken(token);
        _network.setOnUnauthorized(_autoLogout);
        _isLoggedIn = true;
        _setLoading(false);
        return true;
      }
    }

    _errorMessage = response.errorMessage;
    _setLoading(false);
    return false;
  }

  void _autoLogout() => logout();

  void logout() {
    _isLoggedIn = false;
    _network.setAuthToken('');
    _network.setOnUnauthorized(null);
    _storage.clearAuth();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
