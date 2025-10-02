// lib/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  String? _userId;
  String? _username;
  String? _email;
  String? _avatarUrl;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  String? get avatarUrl => _avatarUrl;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get token => _api.token;

  // ДОБАВЛЕНО: геттер currentUser для совместимости
  User? get currentUser {
    if (_userId == null) return null;
    return User(
      id: _userId!,
      username: _username ?? '',
      email: _email ?? '',
      avatarUrl: _avatarUrl,
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[AuthProvider] $message');
    }
  }

  Future<void> logout() async {
    _log('Выход из системы');

    _api.logout();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _userId = null;
    _username = null;
    _email = null;
    _avatarUrl = null;
    _isAuthenticated = false;

    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _log('Попытка входа: $email');

      final response = await _api.login(email, password);

      if (response != null) {
        _userId = response['user']?['id']?.toString() ?? '';
        _username = response['user']?['username'] ?? email.split('@')[0];
        _email = response['user']?['email'] ?? email;
        _avatarUrl = response['user']?['avatar_url'];
        final token = response['token'] ?? '';
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('userId', _userId!);
        await prefs.setString('username', _username!);
        await prefs.setString('email', _email!);
        if (_avatarUrl != null) {
          await prefs.setString('avatarUrl', _avatarUrl!);
        }

        _log('Вход выполнен успешно');
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Неверный email или пароль';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _log('Ошибка входа: $e');
      _errorMessage = 'Ошибка входа: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _log('Попытка регистрации: $email');

      final response = await _api.register(email, password, username);

      if (response != null) {
        _userId = response['user']?['id']?.toString() ?? '';
        _username = response['user']?['username'] ?? username;
        _email = response['user']?['email'] ?? email;
        _avatarUrl = response['user']?['avatar_url'];
        final token = response['token'] ?? '';
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('userId', _userId!);
        await prefs.setString('username', _username!);
        await prefs.setString('email', _email!);
        if (_avatarUrl != null) {
          await prefs.setString('avatarUrl', _avatarUrl!);
        }

        _log('Регистрация выполнена успешно');
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = 'Ошибка регистрации';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _log('Ошибка регистрации: $e');
      _errorMessage = 'Ошибка регистрации: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      _log('Проверка статуса авторизации');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        _log('Токен не найден');
        _isAuthenticated = false;
        notifyListeners();
        return;
      }

      _api.setToken(token);

      final userData = await _api.getCurrentUser();

      if (userData != null) {
        _userId = userData['id']?.toString() ?? prefs.getString('userId') ?? '';
        _username = userData['username'] ?? prefs.getString('username') ?? '';
        _email = userData['email'] ?? prefs.getString('email') ?? '';
        _avatarUrl = userData['avatar_url'] ?? prefs.getString('avatarUrl');
        _isAuthenticated = true;

        _log('Пользователь авторизован: $_username');
      } else {
        _log('Не удалось получить данные пользователя');
        await logout();
      }

      notifyListeners();
    } catch (e) {
      _log('Ошибка проверки авторизации: $e');
      await logout();
    }
  }

  Future<void> initializeAuth() async {
    _log('Инициализация аутентификации');

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      _api.setToken(token);

      _userId = prefs.getString('userId');
      _username = prefs.getString('username');
      _email = prefs.getString('email');
      _avatarUrl = prefs.getString('avatarUrl');

      if (_userId != null && _username != null) {
        _isAuthenticated = true;
        _log('Восстановлена сессия пользователя: $_username');

        checkAuthStatus();
      }
    }

    notifyListeners();
  }

  Future<bool> updateProfile({
    String? username,
    String? email,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _log('Обновление профиля');

      if (username != null) _username = username;
      if (email != null) _email = email;
      if (avatarUrl != null) _avatarUrl = avatarUrl;

      final prefs = await SharedPreferences.getInstance();
      if (username != null) await prefs.setString('username', username);
      if (email != null) await prefs.setString('email', email);
      if (avatarUrl != null) await prefs.setString('avatarUrl', avatarUrl);

      _log('Профиль обновлен успешно');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _log('Ошибка обновления профиля: $e');
      _errorMessage = 'Ошибка обновления профиля: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ДОБАВЛЕНО: метод для установки аутентификации (для invite_register_screen)
  void setAuthenticated(
      String userId, String username, String email, String token) {
    _userId = userId;
    _username = username;
    _email = email;
    _isAuthenticated = true;
    _api.setToken(token);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
