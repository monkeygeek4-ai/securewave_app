// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_manager.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService.instance;
  final WebSocketManager _wsManager = WebSocketManager.instance;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentToken => _api.currentToken;

  // УБРАНО: Автоматическая проверка из конструктора
  // Теперь проверка вызывается явно из InitializationWrapper
  AuthProvider() {
    print('[AuthProvider] Создан экземпляр AuthProvider');
  }

  // ИСПРАВЛЕНО: Теперь публичный метод
  Future<void> checkAuth() async {
    print('[AuthProvider] ========================================');
    print('[AuthProvider] Проверка авторизации...');
    print('[AuthProvider] ========================================');

    _isLoading = true;
    notifyListeners();

    try {
      // Ждем загрузки токена из хранилища
      await _api.waitForToken();

      if (_api.hasToken) {
        print('[AuthProvider] ✅ Токен найден');
        print('[AuthProvider] 🔍 Получаем данные пользователя...');

        // Получаем данные текущего пользователя
        final user = await _api.getCurrentUser();

        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;

          print('[AuthProvider] ========================================');
          print('[AuthProvider] ✅ Пользователь восстановлен');
          print('[AuthProvider]    Username: ${user.username}');
          print('[AuthProvider]    User ID: ${user.id}');
          print('[AuthProvider]    Email: ${user.email}');
          print('[AuthProvider] ========================================');

          // Подключаем WebSocket
          try {
            print('[AuthProvider] 🔌 Подключение WebSocket...');
            await _wsManager.connect(token: _api.currentToken!);
            print('[AuthProvider] ✅ WebSocket подключен');
          } catch (e) {
            print('[AuthProvider] ⚠️ Ошибка подключения WebSocket: $e');
          }
        } else {
          print('[AuthProvider] ❌ Не удалось получить данные пользователя');
          _isAuthenticated = false;
          await _api.clearToken();
        }
      } else {
        print('[AuthProvider] ℹ️ Токен не найден');
        _isAuthenticated = false;
      }
    } catch (e) {
      print('[AuthProvider] ========================================');
      print('[AuthProvider] ❌ Ошибка проверки авторизации: $e');
      print('[AuthProvider] ========================================');
      _isAuthenticated = false;
      await _api.clearToken();
    } finally {
      _isLoading = false;
      notifyListeners();

      print('[AuthProvider] ========================================');
      print('[AuthProvider] Проверка завершена');
      print(
          '[AuthProvider] Статус: ${_isAuthenticated ? "Авторизован" : "Не авторизован"}');
      print('[AuthProvider] ========================================');
    }
  }

  // УСТАРЕЛО: Оставлено для обратной совместимости
  @Deprecated('Используйте checkAuth() вместо этого')
  Future<void> checkAuthStatus() async {
    return checkAuth();
  }

  Future<bool> login(String username, String password) async {
    print('[AuthProvider] ========================================');
    print('[AuthProvider] 🔐 Вход для пользователя: $username');
    print('[AuthProvider] ========================================');

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.clearToken();
      _wsManager.disconnect();

      final response = await _api.login(username, password);
      print('[AuthProvider] Данные ответа входа: $response');

      if (response['success'] == true || response['user'] != null) {
        _currentUser = User.fromJson(response['user']);
        _isAuthenticated = true;

        print('[AuthProvider] ✅ Вход выполнен успешно');
        print('[AuthProvider]    Username: ${_currentUser!.username}');
        print('[AuthProvider]    User ID: ${_currentUser!.id}');

        String? token = response['token'] ??
            response['access_token'] ??
            response['accessToken'];

        if (token != null && token.isNotEmpty) {
          print('[AuthProvider] 🔌 Подключаем WebSocket после входа');
          await Future.delayed(Duration(milliseconds: 500));

          try {
            await _wsManager.connect(token: token);
            print('[AuthProvider] ✅ WebSocket подключен');
          } catch (e) {
            print('[AuthProvider] ⚠️ Ошибка подключения WebSocket: $e');
          }
        }

        _isLoading = false;
        notifyListeners();

        print('[AuthProvider] ========================================');
        return true;
      } else {
        _errorMessage = response['error'] ?? 'Неверные учетные данные';
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();

        print('[AuthProvider] ❌ Ошибка входа: $_errorMessage');
        print('[AuthProvider] ========================================');
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();

      print('[AuthProvider] ❌ Критическая ошибка входа: $e');
      print('[AuthProvider] ========================================');
      return false;
    }
  }

  Future<bool> register(
    String username,
    String password,
    String email,
    String fullName,
  ) async {
    print('[AuthProvider] ========================================');
    print('[AuthProvider] 📝 Регистрация пользователя: $username');
    print('[AuthProvider] ========================================');

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.clearToken();
      _wsManager.disconnect();

      final response = await _api.register(
        username: username,
        password: password,
        email: email,
        fullName: fullName,
      );

      print('[AuthProvider] Ответ регистрации: $response');

      if (response['success'] == true || response['user'] != null) {
        _currentUser = User.fromJson(response['user']);
        _isAuthenticated = true;

        print('[AuthProvider] ✅ Регистрация успешна');
        print('[AuthProvider]    Username: ${_currentUser!.username}');
        print('[AuthProvider]    User ID: ${_currentUser!.id}');

        String? token = response['token'] ??
            response['access_token'] ??
            response['accessToken'];

        if (token != null && token.isNotEmpty) {
          print('[AuthProvider] 🔌 Подключаем WebSocket после регистрации');
          await Future.delayed(Duration(milliseconds: 500));

          try {
            await _wsManager.connect(token: token);
            print('[AuthProvider] ✅ WebSocket подключен');
          } catch (e) {
            print('[AuthProvider] ⚠️ Ошибка подключения WebSocket: $e');
          }
        }

        _isLoading = false;
        notifyListeners();

        print('[AuthProvider] ========================================');
        return true;
      } else {
        _errorMessage = response['error'] ?? 'Ошибка регистрации';
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();

        print('[AuthProvider] ❌ Ошибка регистрации: $_errorMessage');
        print('[AuthProvider] ========================================');
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();

      print('[AuthProvider] ❌ Критическая ошибка регистрации: $e');
      print('[AuthProvider] ========================================');
      return false;
    }
  }

  void setAuthenticated(Map<String, dynamic> userData, String? token) {
    print('[AuthProvider] ========================================');
    print('[AuthProvider] setAuthenticated вызван');
    print('[AuthProvider] ========================================');

    _currentUser = User.fromJson(userData);
    _isAuthenticated = true;

    if (token != null && token.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          await _wsManager.connect(token: token);
          print('[AuthProvider] ✅ WebSocket подключен');
        } catch (e) {
          print('[AuthProvider] ⚠️ Ошибка подключения WebSocket: $e');
        }
      });
    }

    notifyListeners();
  }

  Future<void> logout() async {
    print('[AuthProvider] ========================================');
    print('[AuthProvider] 🚪 Выход из системы');
    print('[AuthProvider] ========================================');

    _isLoading = true;
    notifyListeners();

    try {
      await _api.logout();
      _wsManager.disconnect();
      await _api.clearToken();

      _currentUser = null;
      _isAuthenticated = false;
      _errorMessage = null;

      print('[AuthProvider] ✅ Выход выполнен успешно');
    } catch (e) {
      print('[AuthProvider] ⚠️ Ошибка выхода: $e');
    } finally {
      _isLoading = false;
      notifyListeners();

      print('[AuthProvider] ========================================');
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
