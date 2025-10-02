// lib/providers/auth_provider.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_manager.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final WebSocketManager _wsManager = WebSocketManager.instance;

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentToken => _api.currentToken;

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('[Auth] Вход для пользователя: $username');

      await _api.clearToken();
      _wsManager.disconnect();

      final response = await _api.login(username, password);
      print('[Auth] Данные ответа входа: $response');

      if (response['success'] == true || response['user'] != null) {
        _currentUser = User.fromJson(response['user']);
        _isAuthenticated = true;

        String? token = response['token'] ??
            response['access_token'] ??
            response['accessToken'];

        if (token != null && token.isNotEmpty) {
          print('[Auth] Подключаем WebSocket после входа');
          await Future.delayed(Duration(milliseconds: 500));

          try {
            await _wsManager.connect(token: token);
          } catch (e) {
            print('[Auth] Ошибка подключения WebSocket: $e');
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
      print('[Auth] Регистрация пользователя: $username');

      await _api.clearToken();
      _wsManager.disconnect();

      final response = await _api.register(
        username: username,
        password: password,
        email: email,
        fullName: fullName,
      );

      print('[Auth] Ответ регистрации: $response');

      if (response['success'] == true || response['user'] != null) {
        _currentUser = User.fromJson(response['user']);
        _isAuthenticated = true;

        String? token = response['token'] ??
            response['access_token'] ??
            response['accessToken'];

        if (token != null && token.isNotEmpty) {
          print('[Auth] Подключаем WebSocket после регистрации');
          await Future.delayed(Duration(milliseconds: 500));

          try {
            await _wsManager.connect(token: token);
          } catch (e) {
            print('[Auth] Ошибка подключения WebSocket: $e');
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

  Future<void> logout() async {
    try {
      print('[Auth] Выход из системы...');
      _wsManager.disconnect();
      await _api.logout();
      await _api.clearToken();
      print('[Auth] Токен очищен, выход завершен');
    } catch (e) {
      print('[Auth] Ошибка при logout: $e');
    } finally {
      _currentUser = null;
      _isAuthenticated = false;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      print('[Auth] Проверка статуса авторизации...');

      final hasToken = await _api.waitForToken();

      if (!hasToken) {
        print('[Auth] Нет сохраненного токена');
        _isAuthenticated = false;
        _currentUser = null;
        notifyListeners();
        return;
      }

      print('[Auth] Токен найден, валидируем на сервере...');

      try {
        final response = await _api.validateToken();

        print('[Auth] Ответ validateToken: $response');

        if (response['valid'] == true && response['user'] != null) {
          _currentUser = User.fromJson(response['user']);
          _isAuthenticated = true;
          print(
              '[Auth] Токен валиден, пользователь: ${_currentUser?.username}');
          print('[Auth] isAuthenticated = $_isAuthenticated');
          print('[Auth] currentUser = $_currentUser');

          String? token = _api.currentToken;
          if (token != null && token.isNotEmpty) {
            print('[Auth] Подключаем WebSocket после валидации токена');
            await Future.delayed(Duration(milliseconds: 300));

            try {
              await _wsManager.connect(token: token);
            } catch (e) {
              print('[Auth] Ошибка подключения WebSocket: $e');
            }
          }
        } else {
          print('[Auth] Токен невалиден, очищаем');
          await _api.clearToken();
          _isAuthenticated = false;
          _currentUser = null;
        }
      } catch (e) {
        print('[Auth] Ошибка валидации токена: $e');
        await _api.clearToken();
        _isAuthenticated = false;
        _currentUser = null;
      }

      notifyListeners();
      print(
          '[Auth] После notifyListeners: isAuthenticated = $_isAuthenticated');
    } catch (e) {
      print('[Auth] Ошибка проверки статуса авторизации: $e');
      _isAuthenticated = false;
      _currentUser = null;
      notifyListeners();
    }
  }
}
