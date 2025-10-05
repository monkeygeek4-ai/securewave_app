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

  AuthProvider() {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      print('[AuthProvider] Проверка авторизации...');

      // Ждем загрузки токена из хранилища
      await _api.waitForToken();

      if (_api.hasToken) {
        print('[AuthProvider] Токен найден, получаем данные пользователя');

        // Получаем данные текущего пользователя
        final user = await _api.getCurrentUser();

        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
          print('[AuthProvider] Пользователь восстановлен: ${user.username}');

          // Подключаем WebSocket
          try {
            await _wsManager.connect(token: _api.currentToken!);
            print('[AuthProvider] WebSocket подключен');
          } catch (e) {
            print('[AuthProvider] Ошибка подключения WebSocket: $e');
          }
        } else {
          print('[AuthProvider] Не удалось получить данные пользователя');
          _isAuthenticated = false;
          await _api.clearToken();
        }
      } else {
        print('[AuthProvider] Токен не найден');
        _isAuthenticated = false;
      }
    } catch (e) {
      print('[AuthProvider] Ошибка проверки авторизации: $e');
      _isAuthenticated = false;
      await _api.clearToken();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      print('[AuthProvider] Проверка статуса авторизации');

      if (_api.hasToken) {
        final user = await _api.getCurrentUser();

        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
          notifyListeners();

          if (_api.currentToken != null) {
            try {
              await _wsManager.connect(token: _api.currentToken!);
            } catch (e) {
              print('[AuthProvider] Ошибка подключения WebSocket: $e');
            }
          }
        } else {
          _isAuthenticated = false;
          notifyListeners();
        }
      } else {
        _isAuthenticated = false;
        notifyListeners();
      }
    } catch (e) {
      print('[AuthProvider] Ошибка проверки статуса: $e');
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('[AuthProvider] Вход для пользователя: $username');

      await _api.clearToken();
      _wsManager.disconnect();

      final response = await _api.login(username, password);
      print('[AuthProvider] Данные ответа входа: $response');

      if (response['success'] == true || response['user'] != null) {
        _currentUser = User.fromJson(response['user']);
        _isAuthenticated = true;

        String? token = response['token'] ??
            response['access_token'] ??
            response['accessToken'];

        if (token != null && token.isNotEmpty) {
          print('[AuthProvider] Подключаем WebSocket после входа');
          await Future.delayed(Duration(milliseconds: 500));

          try {
            await _wsManager.connect(token: token);
          } catch (e) {
            print('[AuthProvider] Ошибка подключения WebSocket: $e');
          }
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error'] ?? 'Неверные учетные данные';
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
    String username,
    String password,
    String email,
    String fullName,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('[AuthProvider] Регистрация пользователя: $username');

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

        String? token = response['token'] ??
            response['access_token'] ??
            response['accessToken'];

        if (token != null && token.isNotEmpty) {
          print('[AuthProvider] Подключаем WebSocket после регистрации');
          await Future.delayed(Duration(milliseconds: 500));

          try {
            await _wsManager.connect(token: token);
          } catch (e) {
            print('[AuthProvider] Ошибка подключения WebSocket: $e');
          }
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['error'] ?? 'Ошибка регистрации';
        _isAuthenticated = false;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void setAuthenticated(Map<String, dynamic> userData, String? token) {
    _currentUser = User.fromJson(userData);
    _isAuthenticated = true;

    if (token != null && token.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          await _wsManager.connect(token: token);
        } catch (e) {
          print('[AuthProvider] Ошибка подключения WebSocket: $e');
        }
      });
    }

    notifyListeners();
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _api.logout();
      _wsManager.disconnect();
      await _api.clearToken();

      _currentUser = null;
      _isAuthenticated = false;
      _errorMessage = null;
    } catch (e) {
      print('[AuthProvider] Ошибка выхода: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
