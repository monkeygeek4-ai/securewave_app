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
      return 'wss://securewave.sbk-19.ru:8085';
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
      if (e.response?.data != null) {
        throw e.response!.data['error'] ?? 'Ошибка регистрации';
      }
      throw 'Ошибка подключения. Попробуйте еще раз.';
    } catch (e) {
      _log('Ошибка регистрации: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> validateToken() async {
    try {
      _log('Валидация токена на сервере...');

      final response = await _dio.post('/auth/validate');

      _log('Ответ валидации: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'valid': false, 'error': 'Invalid token'};
      }
    } on DioException catch (e) {
      _log('Ошибка валидации токена: $e');
      return {'valid': false, 'error': e.message};
    }
  }

  Future<User> getCurrentUser() async {
    try {
      _log('Получение текущего пользователя...');

      final response = await _dio.get('/auth/me');

      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      } else {
        throw 'Не удалось получить пользователя';
      }
    } on DioException catch (e) {
      _log('Ошибка получения пользователя: $e');
      throw 'Ошибка получения данных пользователя';
    }
  }

  Future<void> logout() async {
    try {
      _log('Выполнение logout на сервере...');
      await _dio.post('/auth/logout');
    } catch (e) {
      _log('Ошибка при logout на сервере: $e');
    }
  }

  // ===== ПОЛЬЗОВАТЕЛИ =====

  Future<List<dynamic>> getUsers() async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для получения пользователей');
        return [];
      }

      final response = await _dio.get('/chats/users');
      return response.data ?? [];
    } catch (e) {
      _log('Ошибка получения пользователей: $e');
      return [];
    }
  }

  Future<List<dynamic>> searchUsers(String query) async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для поиска пользователей');
        return [];
      }

      final response = await _dio.get('/users/search', queryParameters: {
        'q': query,
      });

      return response.data ?? [];
    } catch (e) {
      _log('Ошибка поиска пользователей: $e');
      return [];
    }
  }

  // ===== ЧАТЫ =====

  Future<List<Chat>> getChats() async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для получения чатов');
        return [];
      }

      final response = await _dio.get('/chats/');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        return data.map((json) => Chat.fromJson(json)).toList();
      } else {
        _log('Ошибка получения чатов: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _log('Ошибка получения чатов: $e');
      return [];
    }
  }

  Future<Chat?> createOrGetChat(String userId, String chatName) async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для создания чата');
        return null;
      }

      final response = await _dio.post('/chats/', data: {
        'userId': userId,
        'chatName': chatName,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Chat.fromJson(response.data);
      } else {
        _log('Ошибка создания чата: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Ошибка создания чата: $e');
      return null;
    }
  }

  // Метод с именованными параметрами для совместимости
  Future<Chat?> createChat({
    required String userId,
    String? userName,
  }) async {
    return createOrGetChat(userId, userName ?? 'Chat');
  }

  Future<bool> deleteChat(String chatId) async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для удаления чата');
        return false;
      }

      final response = await _dio.delete('/chats/$chatId');

      if (response.statusCode == 200) {
        _log('Чат удален: $chatId');
        return true;
      } else {
        _log('Ошибка удаления чата: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _log('Ошибка удаления чата: $e');
      return false;
    }
  }

  Future<List<Message>> getMessages(String chatId) async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для получения сообщений');
        return [];
      }

      final response = await _dio.get('/chats/$chatId/messages');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data ?? [];
        return data.map((json) => Message.fromJson(json)).toList();
      } else {
        _log('Ошибка получения сообщений: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _log('Ошибка получения сообщений: $e');
      return [];
    }
  }

  Future<Message?> sendMessage({
    required String chatId,
    required String content,
    String type = 'text',
    String? replyToId,
  }) async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для отправки сообщения');
        return null;
      }

      final response = await _dio.post('/messages/send', data: {
        'chatId': chatId,
        'content': content,
        'type': type,
        if (replyToId != null) 'replyToId': replyToId,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Message.fromJson(response.data);
      } else {
        _log('Ошибка отправки сообщения: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Ошибка отправки сообщения: $e');
      return null;
    }
  }

  Future<bool> markMessagesAsRead(String chatId,
      [List<String>? messageIds]) async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для отметки сообщений');
        return false;
      }

      final response = await _dio.post('/chats/$chatId/read', data: {
        if (messageIds != null) 'messageIds': messageIds,
      });

      if (response.statusCode == 200) {
        _log('Сообщения отмечены как прочитанные');
        return true;
      } else {
        _log('Ошибка отметки сообщений: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _log('Ошибка отметки сообщений: $e');
      return false;
    }
  }

  // ===== ФАЙЛЫ =====

  Future<String?> uploadFile(String filePath) async {
    try {
      await waitForToken();

      if (!hasToken) {
        _log('Нет токена для загрузки файла');
        return null;
      }

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post('/files/upload', data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['url'];
      } else {
        _log('Ошибка загрузки файла: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Ошибка загрузки файла: $e');
      return null;
    }
  }
}
