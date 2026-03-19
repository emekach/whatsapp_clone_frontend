// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _api     = ApiService();
  final _storage = const FlutterSecureStorage();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String?    _error;

  AuthStatus get status    => _status;
  UserModel? get user      => _user;
  String?    get error     => _error;
  bool       get isLoggedIn => _status == AuthStatus.authenticated;

  Future<void> checkAuth() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final data = await _api.getMe();
      _user   = UserModel.fromJson(data['user']);
      _status = AuthStatus.authenticated;
      // Update online status
      _api.ping();
    } catch (_) {
      await _storage.delete(key: AppConstants.tokenKey);
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    _error = null;
    try {
      final data  = await _api.login(phone, password);
      final token = data['token'] as String;
      await _storage.write(key: AppConstants.tokenKey, value: token);
      _user   = UserModel.fromJson(data['user']);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String phone, String password) async {
    _error = null;
    try {
      final data  = await _api.register({
        'name':                  name,
        'phone':                 phone,
        'password':              password,
        'password_confirmation': password,
      });
      final token = data['token'] as String;
      await _storage.write(key: AppConstants.tokenKey, value: token);
      _user   = UserModel.fromJson(data['user']);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    await _storage.delete(key: AppConstants.tokenKey);
    _user   = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void updateUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  String _parseError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('422')) return 'Invalid phone or password.';
    if (msg.contains('SocketException'))             return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }
}
