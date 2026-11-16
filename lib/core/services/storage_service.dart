import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> setAuthToken(String token) async {
    await init();
    await _prefs!.setString('auth_token', token);
  }

  String? getAuthToken() => _prefs?.getString('auth_token');

  Future<void> clearAuth() async {
    await init();
    await _prefs!.remove('auth_token');
  }
}
