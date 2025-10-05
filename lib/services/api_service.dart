// lib/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../models/message.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();

  late Dio _dio;
  String? _authToken;
  bool _isInitialized = false;

  static const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

  static String get baseUrl {
    if (kIsWeb) {
      return 'https://securewave.sbk-19.ru/backend/api';
    }
    return 'http://10.0.2.2:8080/backend/api';
  }

  static String get wsUrl {
    if (kIsWeb) {
      return 'wss://securewave.sbk-19.ru/ws';
    }
    return 'ws://10.0.2.2:8085';
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[API] $message');
    }
  }

  ApiService._internal() {
    _log(
        'Инициализация ApiService. Web: $kIsWeb, BaseURL: $baseUrl, WS: $wsUrl');
    _initializeDio();
  }

  factory ApiService() => instance;

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) {
        return status! < 500;
      },
    ));

    _initializeInterceptors();
    _loadTokenAsync();
  }

  void _initializeInterceptors() {
    _dio.interceptors.clear();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_authToken == null && !_isInitialized) {
          await _loadToken();
        }

        if (_authToken != null && _authToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_authToken';
          _log('Запрос с токеном: ${options.method} ${options.path}');
        } else {
          _log('Запрос без токена: ${options.method} ${options.path}');
        }

        return handler.next(options);
      },
      onResponse: (response, handler) {
        _log('Ответ [${response.statusCode}]: ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException error, handler) {
        _log(
            'Ошибка [${error.response?.statusCode}]: ${error.requestOptions.path}');
        _log('Детали ошибки: ${error.response?.data}');

        if (error.response?.statusCode == 403 ||
            error.response?.statusCode == 401) {
          _log('Ошибка авторизации - очищаем токен');
          clearToken();
        }

        return handler.next(error);
      },
    ));
  }

  Future<void> _loadTokenAsync() async {
    await _loadToken();
  }

  Future<void> _loadToken() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenValue = prefs.getString('auth_token');

      if (tokenValue != null && tokenValue.isNotEmpty) {
        if (tokenValue.startsWith('"') && tokenValue.endsWith('"')) {
          _authToken = tokenValue.substring(1, tokenValue.length - 1);
          _log('Токен загружен и очищен от кавычек');
        } else {
          _authToken = tokenValue;
          _log('Токен загружен из хранилища');
        }
      } else {
        _log('Токен не найден в хранилище');
      }

      _isInitialized = true;
    } catch (e) {
      _log('Ошибка загрузки токена: $e');
      _isInitialized = true;
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      _log('Сохранение токена...');

      if (token.startsWith('"') && token.endsWith('"')) {
        token = token.substring(1, token.length - 1);
        _log('Убраны кавычки из токена');
      }

      _authToken = token;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      _log('Токен сохранен');
    } catch (e) {
      _log('Ошибка сохранения токена: $e');
    }
  }

  Future<void> clearToken() async {
    try {
      _log('Очистка токена');
      _authToken = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');

      _log('Токен очищен');
    } catch (e) {
      _log('Ошибка очистки токена: $e');
    }
  }

  bool get hasToken => _authToken != null && _authToken!.isNotEmpty;
  String? get currentToken => _authToken;
  String? get token => _authToken;

  Future<bool> waitForToken(
      {Duration timeout = const Duration(seconds: 2)}) async {
    final startTime = DateTime.now();

    while (!_isInitialized) {
      if (DateTime.now().difference(startTime) > timeout) {
        _log('Таймаут ожидания загрузки токена');
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return hasToken;
  }

  // ===== АУТЕНТИФИКАЦИЯ =====

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      _log('Вход для пользователя: $username');

      await clearToken();

      final response = await _dio.post('/auth/login', data: {
        'username': username,
        'password': password,
      });

      _log('Ответ входа: ${response.statusCode}');
      _log('Данные ответа: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        String? token = data['token'] ??
            data['access_token'] ??
            data['accessToken'] ??
            data['jwt'];

        if (token != null) {
          await _saveToken(token);
          _log('Токен получен и сохранен');
        } else {
          _log('Внимание: токен не найден в ответе');
          _log('Ключи ответа: ${data.keys.toList()}');
        }

        return data;
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        throw 'Неверное имя пользователя или пароль';
      } else {
        throw 'Ошибка входа: ${response.statusCode}';
      }
    } on DioException catch (e) {
      _log('DioException при входе: $e');
      if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
        throw 'Неверное имя пользователя или пароль';
      }
      throw 'Ошибка подключения. Попробуйте еще раз.';
    } catch (e) {
      _log('Ошибка входа: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
  }) async {
    try {
      _log('Регистрация пользователя: $username');

      await clearToken();

      final response = await _dio.post('/auth/register', data: {
        'username': username,
        'password': password,
        'email': email,
        'fullName': fullName,
      });

      _log('Ответ регистрации: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;

        String? token = data['token'] ??
            data['access_token'] ??
            data['accessToken'] ??
            data['jwt'];

        if (token != null) {
          await _saveToken(token);
          _log('Токен получен и сохранен');
        }

        return data;
      } else {
        throw 'Ошибка регистрации: ${response.statusCode}';
      }
    } on DioException catch (e) {
      _log('DioException при регистрации: $e');
      throw 'Ошибка подключения. Попробуйте еще раз.';
    } catch (e) {
      _log('Ошибка регистрации: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateToken() async {
    try {
      _log('Валидация токена...');

      final response = await _dio.post('/auth/validate');

      _log('Ответ валидации: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'valid': false, 'error': 'Invalid token'};
      }
    } catch (e) {
      _log('Ошибка валидации токена: $e');
      return {'valid': false, 'error': e.toString()};
    }
  }

  Future<void> logout() async {
    try {
      _log('Выход из системы...');
      await _dio.post('/auth/logout');
      _log('Logout выполнен на сервере');
    } catch (e) {
      _log('Ошибка при logout: $e');
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      _log('Получение текущего пользователя...');

      final response = await _dio.get('/auth/me');

      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }

      return null;
    } catch (e) {
      _log('Ошибка получения пользователя: $e');
      return null;
    }
  }

  // ===== ЧАТЫ =====

  Future<List<Chat>> getChats() async {
    try {
      final response = await _dio.get('/chats');

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

  Future<Chat?> createGroupChat(
      String groupName, List<String> participantIds) async {
    try {
      _log(
          'API: Создание группового чата "$groupName" с ${participantIds.length} участниками');

      final response = await _dio.post('/chats/create-group', data: {
        'name': groupName,
        'participants': participantIds,
      });

      _log('API Response: ${response.statusCode}');
      _log('Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _log('API: Групповой чат создан успешно');
        return Chat.fromJson(response.data);
      }

      _log('API: Неожиданный статус код: ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      _log('DioException при создании группового чата: ${e.message}');
      _log('Response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      _log('Ошибка создания группового чата: $e');
      rethrow;
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
      final response = await _dio.get('/messages/chat/$chatId');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Message.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      _log('Ошибка получения сообщений: $e');
      return [];
    }
  }

  // ОБНОВЛЕНО: Метод sendMessage с поддержкой type и metadata
  Future<Message?> sendMessage(
    String chatId,
    String content, {
    String type = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _log('📤 Отправка сообщения:');
      _log('  chatId: $chatId');
      _log('  content: $content');
      _log('  type: $type');
      _log('  metadata: $metadata');

      final response = await _dio.post('/messages/send', data: {
        'chatId': chatId,
        'content': content,
        'type': type,
        if (metadata != null) 'metadata': metadata,
      });

      _log('📥 Ответ от сервера [${response.statusCode}]:');
      _log('  ${response.data}');

      if (response.statusCode == 200) {
        final message = Message.fromJson(response.data);
        _log('✅ Распарсенное сообщение:');
        _log('  ID: ${message.id}');
        _log('  Type: ${message.type}');
        _log('  Metadata: ${message.metadata}');
        _log('  isCallMessage: ${message.isCallMessage}');
        return message;
      }

      return null;
    } catch (e) {
      _log('❌ Ошибка отправки сообщения: $e');
      return null;
    }
  }

  Future<bool> markMessagesAsRead(String chatId) async {
    try {
      final response = await _dio.post('/messages/mark-read', data: {
        'chatId': chatId,
      });

      return response.statusCode == 200;
    } catch (e) {
      _log('Ошибка отметки сообщений как прочитанных: $e');
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
      _log('GET запрос: $path');
      final response = await _dio.get(path, queryParameters: queryParameters);

      if (response.statusCode == 200) {
        return response.data;
      }

      throw 'Ошибка: ${response.statusCode}';
    } on DioException catch (e) {
      _log('DioException при GET: $e');
      if (e.response != null) {
        return e.response!.data;
      }
      throw 'Ошибка подключения';
    } catch (e) {
      _log('Ошибка GET: $e');
      rethrow;
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> data) async {
    try {
      _log('POST запрос: $path');
      final response = await _dio.post(path, data: data);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }

      throw 'Ошибка: ${response.statusCode}';
    } on DioException catch (e) {
      _log('DioException при POST: $e');
      if (e.response != null) {
        return e.response!.data;
      }
      throw 'Ошибка подключения';
    } catch (e) {
      _log('Ошибка POST: $e');
      rethrow;
    }
  }

  Future<void> saveToken(String token) async {
    await _saveToken(token);
  }

  void setToken(String token) {
    _authToken = token;
  }
}
