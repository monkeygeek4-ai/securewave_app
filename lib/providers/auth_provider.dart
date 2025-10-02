// lib/providers/auth_provider.dart (ОБНОВЛЕННАЯ ВЕРСИЯ)

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

  // НОВЫЙ МЕТОД: Установка авторизованного состояния (для инвайт-регистрации)
  void setAuthenticated(Map<String, dynamic> userData, String? token) {
    _currentUser = User.fromJson(userData);
    _isAuthenticated = true;

    if (token != null && token.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 500), () async {
        try {
          await _wsManager.connect(token: token);
        } catch (e) {
          print('[Auth] Ошибка подключения WebSocket: $e');
        }
      });
    }

    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    try {
      final response = await _api.get('/auth/me');

      if (response['id'] != null) {
        _currentUser = User.fromJson(response);
        _isAuthenticated = true;
        notifyListeners();

        if (_api.currentToken != null) {
          try {
            await _wsManager.connect(token: _api.currentToken!);
          } catch (e) {
            print('[Auth] Ошибка подключения WebSocket: $e');
          }
        }
      } else {
        _isAuthenticated = false;
        notifyListeners();
      }
    } catch (e) {
      print('[Auth] Ошибка проверки статуса: $e');
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      _wsManager.disconnect();
      await _api.clearToken();

      _currentUser = null;
      _isAuthenticated = false;
      _errorMessage = null;
    } catch (e) {
      print('[Auth] Ошибка выхода: $e');
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
