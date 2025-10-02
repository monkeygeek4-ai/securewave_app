// lib/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/user.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  String? _token;

  static const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

  ApiService._internal() {
    final baseUrl = kIsWeb
        ? '${Uri.base.origin}/backend/api'
        : 'https://securewave.sbk-19.ru/backend/api';

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        _log('📤 ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _log('✅ ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) {
        _log('❌ Ошибка: ${error.message}');
        _log('   URL: ${error.requestOptions.path}');
        _log('   Статус: ${error.response?.statusCode}');
        _log('   Данные: ${error.response?.data}');
        return handler.next(error);
      },
    ));
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[ApiService] $message');
    }
  }

  void setToken(String? token) {
    _token = token;
    _log('Токен ${token != null ? "установлен" : "удален"}');
  }

  String? get token => _token;

  // ===== АУТЕНТИФИКАЦИЯ =====

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['token'] != null) {
          setToken(data['token']);
        }
        return data;
      }

      return null;
    } catch (e) {
      _log('Ошибка входа: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> register(
      String email, String password, String username) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'username': username,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['token'] != null) {
          setToken(data['token']);
        }
        return data;
      }

      return null;
    } catch (e) {
      _log('Ошибка регистрации: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');

      if (response.statusCode == 200) {
        return response.data;
      }

      return null;
    } catch (e) {
      _log('Ошибка получения текущего пользователя: $e');
      return null;
    }
  }

  void logout() {
    setToken(null);
  }

  // ===== ЧАТЫ =====

  Future<List<Chat>> getChats() async {
    try {
      final response = await _dio.get('/chats/list');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Chat.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _log('Ошибка получения чатов: $e');
      return [];
    }
  }

  Future<Chat?> createChat(String recipientId) async {
    try {
      final response = await _dio.post('/chats/create', data: {
        'recipientId': recipientId,
      });

      if (response.statusCode == 200) {
        return Chat.fromJson(response.data);
      }

      return null;
    } catch (e) {
      _log('Ошибка создания чата: $e');
      return null;
    }
  }

  Future<bool> deleteChat(String chatId) async {
    try {
      final response = await _dio.delete('/chats/delete', data: {
        'chatId': chatId,
      });

      return response.statusCode == 200;
    } catch (e) {
      _log('Ошибка удаления чата: $e');
      return false;
    }
  }

  // ===== СООБЩЕНИЯ =====

  Future<List<Message>> getMessages(String chatId) async {
    try {
      // ИСПРАВЛЕНО: используем query параметры вместо path
      final response =
          await _dio.get('/messages/chat', queryParameters: {'chatId': chatId});

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Message.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _log('Ошибка получения сообщений для чата $chatId: $e');
      return [];
    }
  }

  Future<Message?> sendMessage(String chatId, String content) async {
    try {
      final response = await _dio.post('/messages/send', data: {
        'chatId': chatId,
        'content': content,
      });

      if (response.statusCode == 200) {
        return Message.fromJson(response.data);
      }

      return null;
    } catch (e) {
      _log('Ошибка отправки сообщения: $e');
      return null;
    }
  }

  Future<bool> markMessagesAsRead(String chatId) async {
    try {
      _log('Отметка сообщений как прочитанных для чата: $chatId');

      final response = await _dio.post('/messages/mark-read', data: {
        'chatId': chatId,
      });

      _log('Ответ от mark-read: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      _log('Ошибка отметки сообщений как прочитанных: $e');
      if (e is DioException) {
        _log('DioException details: ${e.response?.data}');
      }
      return false;
    }
  }

  // ===== ПОЛЬЗОВАТЕЛИ =====

  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await _dio.get('/users/search', queryParameters: {
        'q': query,
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => User.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _log('Ошибка поиска пользователей: $e');
      return [];
    }
  }

  Future<List<User>> getUsers() async {
    try {
      final response = await _dio.get('/chats/users');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => User.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _log('Ошибка получения пользователей: $e');
      return [];
    }
  }

  // ===== УНИВЕРСАЛЬНЫЕ МЕТОДЫ GET/POST =====

  Future<dynamic> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data;
    } catch (e) {
      _log('Ошибка GET $path: $e');
      rethrow;
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } catch (e) {
      _log('Ошибка POST $path: $e');
      rethrow;
    }
  }
}
