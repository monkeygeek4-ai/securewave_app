// lib/services/api_service.dart

import 'package:dio/dio.dart';
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
    return 'https://securewave.sbk-19.ru/backend/api';
  }

  static String get wsUrl {
    if (kIsWeb) {
      return 'wss://securewave.sbk-19.ru/ws';
    }
    return 'wss://securewave.sbk-19.ru/ws';
  }

  void _log(String message) {
    // ⭐⭐⭐ ВКЛЮЧЕНО: Ключевые логи для отладки
    print('[API] $message');
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
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
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
          // ⭐⭐⭐ УБРАНО: Не логируем частые запросы к /messages/chat и /chats
          final path = options.path.toString();
          final isChatsRequest = path.contains('/messages/chat/') || 
                                 path.contains('/chats') ||
                                 path == '/chats' ||
                                 path == 'chats' ||
                                 path.endsWith('/chats') ||
                                 path.contains('chats');
          if (!isChatsRequest) {
            _log('Запрос с токеном: ${options.method} ${options.path}');
          }
        } else {
          _log('Запрос без токена: ${options.method} ${options.path}');
        }

        return handler.next(options);
      },
      onResponse: (response, handler) {
        // ⭐⭐⭐ УБРАНО: Не логируем частые ответы от /messages/chat и /chats
        final path = response.requestOptions.path.toString();
        final isChatsRequest = path.contains('/messages/chat/') || 
                               path.contains('/chats') ||
                               path == '/chats' ||
                               path == 'chats' ||
                               path.endsWith('/chats') ||
                               path.contains('chats');
        if (!isChatsRequest) {
          _log('Ответ [${response.statusCode}]: ${response.requestOptions.path}');
        }
        return handler.next(response);
      },
      onError: (DioException error, handler) {
        _log(
            'Ошибка [${error.response?.statusCode}]: ${error.requestOptions.path}');
        _log('Детали ошибки: ${error.message}');
        _log('Response data: ${error.response?.data}');

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
      _log('=== НАЧАЛО ВХОДА ===');
      _log('Вход для пользователя: $username');
      _log('URL: $baseUrl/auth/login');

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
          _log('✅ Токен получен и сохранен');
        } else {
          _log('⚠️ Внимание: токен не найден в ответе');
          _log('Ключи ответа: ${data.keys.toList()}');
        }

        _log('=== ВХОД УСПЕШЕН ===');
        return data;
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        _log('❌ Неверные учетные данные');
        throw 'Неверное имя пользователя или пароль';
      } else {
        _log('❌ Ошибка входа: ${response.statusCode}');
        throw 'Ошибка входа: ${response.statusCode}';
      }
    } on DioException catch (e) {
      _log('❌ DioException при входе: ${e.message}');
      _log('Type: ${e.type}');
      _log('Response: ${e.response?.data}');

      if (e.response?.statusCode == 403 || e.response?.statusCode == 401) {
        throw 'Неверное имя пользователя или пароль';
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw 'Превышено время ожидания. Проверьте подключение к интернету.';
      }

      if (e.type == DioExceptionType.connectionError) {
        throw 'Ошибка подключения к серверу. Проверьте интернет-соединение.';
      }

      throw 'Ошибка подключения. Попробуйте еще раз.';
    } catch (e) {
      _log('❌ Ошибка входа: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
    String? phone,
  }) async {
    try {
      _log('Регистрация пользователя: $username');

      await clearToken();

      final data = {
        'username': username,
        'password': password,
        'email': email,
        'fullName': fullName,
      };

      if (phone != null && phone.isNotEmpty) {
        data['phone'] = phone;
      }

      final response = await _dio.post('/auth/register', data: data);

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

  /// Запрос на восстановление пароля
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      _log('Запрос на восстановление пароля: $email');

      final response = await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });

      _log('Ответ восстановления: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'error': 'Ошибка при запросе'};
      }
    } on DioException catch (e) {
      _log('DioException при запросе восстановления: $e');
      if (e.response?.data != null && e.response?.data['error'] != null) {
        return {'success': false, 'error': e.response?.data['error']};
      }
      return {'success': false, 'error': 'Ошибка подключения'};
    } catch (e) {
      _log('Ошибка запроса восстановления: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Подтверждение сброса пароля с кодом
  Future<Map<String, dynamic>> confirmPasswordReset(
      String email, String code, String newPassword) async {
    try {
      _log('Подтверждение сброса пароля: $email');

      final response = await _dio.post('/auth/reset-password', data: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });

      _log('Ответ сброса пароля: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'error': 'Ошибка при сбросе пароля'};
      }
    } on DioException catch (e) {
      _log('DioException при сбросе пароля: $e');
      if (e.response?.data != null && e.response?.data['error'] != null) {
        return {'success': false, 'error': e.response?.data['error']};
      }
      return {'success': false, 'error': 'Ошибка подключения'};
    } catch (e) {
      _log('Ошибка сброса пароля: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Запрос на удаление аккаунта
  Future<Map<String, dynamic>> requestAccountDeletion() async {
    try {
      _log('Запрос на удаление аккаунта');

      final response = await _dio.post('/auth/delete-account.php');

      _log('Ответ удаления аккаунта: ${response.statusCode} | ${response.data}');

      if (response.statusCode == 200) {
        if (response.data is Map<String, dynamic>) {
          return response.data;
        }
        return {'success': false, 'error': 'Неверный формат ответа'};
      } else {
        return {'success': false, 'error': 'Ошибка при удалении аккаунта'};
      }
    } on DioException catch (e) {
      _log('DioException при удалении аккаунта: ${e.message} | response: ${e.response?.data}');
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['error'] != null) {
        return {'success': false, 'error': data['error']};
      }
      if (data is String) {
        return {'success': false, 'error': data};
      }
      return {'success': false, 'error': 'Ошибка подключения: ${e.message}'};
    } catch (e) {
      _log('Ошибка удаления аккаунта: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Восстановление удалённого аккаунта
  Future<Map<String, dynamic>> restoreAccount() async {
    try {
      _log('Запрос на восстановление аккаунта');

      final response = await _dio.post('/auth/restore-account.php');

      _log('Ответ восстановления аккаунта: ${response.statusCode}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'error': 'Ошибка при восстановлении аккаунта'};
      }
    } on DioException catch (e) {
      _log('DioException при восстановлении аккаунта: $e');
      if (e.response?.data != null && e.response?.data['error'] != null) {
        return {'success': false, 'error': e.response?.data['error']};
      }
      return {'success': false, 'error': 'Ошибка подключения'};
    } catch (e) {
      _log('Ошибка восстановления аккаунта: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Проверка статуса удаления аккаунта
  Future<Map<String, dynamic>> checkDeletionStatus() async {
    try {
      final response = await _dio.get('/auth/deletion-status.php');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        return {'success': false, 'error': 'Ошибка при проверке статуса'};
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['error'] != null) {
        return {'success': false, 'error': e.response?.data['error']};
      }
      return {'success': false, 'error': 'Ошибка подключения'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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

  Future<Chat?> createPersonalChat(String userId) async {
    try {
      _log('Создание личного чата с пользователем: $userId');

      final response = await _dio.post('/chats/create', data: {
        'recipientId': userId,
        'type': 'personal',
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _log('Личный чат создан успешно');
        return Chat.fromJson(response.data);
      }

      _log('Ошибка создания личного чата: ${response.statusCode}');
      return null;
    } catch (e) {
      _log('Ошибка создания личного чата: $e');
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

  Future<bool> deleteChat(String chatId, {bool deleteForEveryone = false}) async {
    _log('🗑️ Удаление чата: $chatId, deleteForEveryone: $deleteForEveryone');

    // На разных версиях backend встречаются различия:
    // - метод: POST vs DELETE
    // - путь: /chats/{chatId}/delete (текущий роутер) vs /chats/delete(.php) (старые варианты)
    // Поэтому делаем несколько попыток, чтобы удаление работало стабильно.
    final attempts = <Future<Response<dynamic>> Function()>[
      // 0) POST /chats/{chatId}/delete (ТЕКУЩИЙ роутер backend/api/index.php)
      () => _dio.post('/chats/$chatId/delete', data: {
            'deleteForEveryone': deleteForEveryone,
          }),
      // 0.1) DELETE /chats/{chatId}/delete
      () => _dio.delete('/chats/$chatId/delete'),

      // 1) POST /chats/delete (текущая реализация сервера)
      () => _dio.post('/chats/delete', data: {
            'chatId': chatId,
            'deleteForEveryone': deleteForEveryone,
          }),
      // 2) DELETE /chats/delete?chatId=...
      () => _dio.delete('/chats/delete', queryParameters: {
            'chatId': chatId,
          }),
      // 3) POST /chats/delete.php (если сервер не роутит через index.php)
      () => _dio.post('/chats/delete.php', data: {
            'chatId': chatId,
            'deleteForEveryone': deleteForEveryone,
          }),
      // 4) DELETE /chats/delete.php?chatId=...
      () => _dio.delete('/chats/delete.php', queryParameters: {
            'chatId': chatId,
          }),
    ];

    for (var i = 0; i < attempts.length; i++) {
      try {
        final response = await attempts[i]();
        _log('Удаление чата: попытка ${i + 1}/${attempts.length}, статус ${response.statusCode}');

        if (response.statusCode != 200) {
          // Пробуем следующий вариант
          continue;
        }

        // Сервер может вернуть 200, но success=false (или другой формат ответа).
        final data = response.data;
        if (data is Map) {
          final success = data['success'];
          if (success is bool && success == false) {
            // Явный отказ сервера — дальше пробовать бессмысленно
            _log('Удаление чата: сервер вернул success=false');
            return false;
          }
        }

        return true;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        _log('Удаление чата: попытка ${i + 1}/${attempts.length} упала (DioException), статус: $status, msg: ${e.message}');
        // Если это 401/403 — дальнейшие попытки не помогут
        if (status == 401 || status == 403) return false;
        // Иначе пробуем следующий вариант
        continue;
      } catch (e) {
        _log('Удаление чата: попытка ${i + 1}/${attempts.length} упала (Exception): $e');
        continue;
      }
    }

    return false;
  }

  Future<void> markChatAsRead(String chatId) async {
    try {
      _log('Отметка чата как прочитанного: $chatId');

      await _dio.post('/chats/mark-read', data: {
        'chatId': chatId,
      });

      _log('Чат отмечен как прочитанный');
    } catch (e) {
      _log('Ошибка отметки чата как прочитанного: $e');
      rethrow;
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

  Future<Message?> sendMessage(
    String chatId,
    String content, {
    String type = 'text',
    String? replyToId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _log('📤 Отправка сообщения:');
      _log('  chatId: $chatId');
      _log('  content: $content');
      _log('  type: $type');
      _log('  replyToId: $replyToId');
      _log('  metadata: $metadata');

      final response = await _dio.post('/messages/send', data: {
        'chatId': chatId,
        'content': content,
        'type': type,
        if (replyToId != null) 'replyToId': replyToId,
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

  Future<bool> deleteMessage(String chatId, String messageId, {bool deleteForEveryone = false}) async {
    try {
      // print('========================================');
      // print('[API] 🗑️ УДАЛЕНИЕ СООБЩЕНИЯ');
      // print('[API] Message ID: $messageId (type: ${messageId.runtimeType})');
      // print('[API] Chat ID: $chatId (type: ${chatId.runtimeType})');
      // print('[API] Delete for everyone: $deleteForEveryone');
      // print('[API] ========================================');

      // Используем POST вместо DELETE, так как сервер поддерживает POST
      // и некоторые серверы не принимают body в DELETE запросах
      // print('[API] 📤 Отправка POST запроса на /messages/delete');
      // print('[API] Request data: {chatId: $chatId, messageId: $messageId, deleteForEveryone: $deleteForEveryone}');
      
      final response = await _dio.post('/messages/delete', data: {
        'chatId': chatId,
        'messageId': messageId,
        'deleteForEveryone': deleteForEveryone,
      });

      // print('[API] ✅ Ответ получен');
      // print('[API] Status Code: ${response.statusCode}');
      // print('[API] Response Data: ${response.data}');
      // print('[API] Response Data Type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        final responseData = response.data;
        // print('[API] Response Data (parsed): $responseData');
        
        // Проверяем разные форматы ответа
        if (responseData is Map) {
          // print('[API] Response is Map, keys: ${responseData.keys.toList()}');
          if (responseData['success'] == true) {
            // print('[API] ✅ Сообщение удалено успешно');
            // print('[API] ========================================');
            return true;
          }
          if (responseData['error'] != null) {
            // print('[API] ❌ Ошибка от сервера: ${responseData['error']}');
            // print('[API] ========================================');
            return false;
          }
          // Если просто Map без success, считаем успехом
          // print('[API] ✅ Сообщение удалено (ответ без success, но статус 200)');
          // print('[API] ========================================');
          return true;
        }
        
        // print('[API] ⚠️ Неожиданный формат ответа: $responseData');
        // print('[API] ========================================');
        return false;
      }

      // print('[API] ❌ Ошибка удаления сообщения: ${response.statusCode}');
      // print('[API] Response data: ${response.data}');
      // print('[API] ========================================');
      return false;
    } on DioException catch (_) {
      // print('[API] ========================================');
      // print('[API] ❌ ОШИБКА УДАЛЕНИЯ (DioException)');
      // print('[API] Error: $e');
      // print('[API] Message: ${e.message}');
      // print('[API] Type: ${e.type}');
      // print('[API] Response: ${e.response?.data}');
      // print('[API] Status Code: ${e.response?.statusCode}');
      // print('[API] Request Path: ${e.requestOptions.path}');
      // print('[API] Request Data: ${e.requestOptions.data}');
      // print('[API] Request Headers: ${e.requestOptions.headers}');
      // print('[API] ========================================');
      return false;
    } catch (e, _) {
      // print('[API] ========================================');
      // print('[API] ❌ ОШИБКА УДАЛЕНИЯ (Exception)');
      // print('[API] Error: $e');
      // print('[API] Stack Trace: $stackTrace');
      // print('[API] ========================================');
      return false;
    }
  }

  // Удаление файла с сервера
  Future<Map<String, dynamic>?> delete(String path, {Map<String, dynamic>? data}) async {
    try {
      // Используем POST вместо DELETE, так как сервер поддерживает POST
      final response = await _dio.post(path, data: data);
      return response.data;
    } catch (e) {
      _log('Ошибка DELETE запроса: $e');
      rethrow;
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

  // ===== FCM УВЕДОМЛЕНИЯ =====

  /// ✅✅✅ ОБНОВЛЕНО: Регистрация FCM токена с поддержкой VoIP для iOS
  Future<Map<String, dynamic>?> registerFCMToken(
    String token,
    String platform, [
    String? voipToken,
  ]) async {
    try {
      _log('========================================');
      _log('📤 РЕГИСТРАЦИЯ FCM ТОКЕНА');
      _log('========================================');
      _log('Платформа: $platform');
      _log('Токен (первые 30): ${token.substring(0, 30)}...');
      _log('Длина токена: ${token.length}');
      if (voipToken != null && voipToken.isNotEmpty) {
        _log('VoIP токен (первые 30): ${voipToken.substring(0, 30)}...');
      }
      _log('Endpoint: $baseUrl/notifications/register.php');

      // ⭐ ВАЖНО: Проверяем что токен авторизации установлен
      if (_authToken == null || _authToken!.isEmpty) {
        _log('⚠️⚠️⚠️ ТОКЕН АВТОРИЗАЦИИ НЕ УСТАНОВЛЕН!');
        _log('Пытаемся загрузить токен...');
        await _loadToken();

        if (_authToken == null || _authToken!.isEmpty) {
          _log('❌ Не удалось загрузить токен авторизации');
          _log('FCM токен НЕ БУДЕТ зарегистрирован');
          return {'success': false, 'error': 'No auth token'};
        }

        _log(
            '✅ Токен авторизации загружен: ${_authToken!.substring(0, 20)}...');
      } else {
        _log(
            '✅ Токен авторизации присутствует: ${_authToken!.substring(0, 20)}...');
      }

      final requestData = {
        'token': token,
        'platform': platform,
        if (voipToken != null && voipToken.isNotEmpty) 'voip_token': voipToken,
      };

      _log('========================================');
      _log('📦 Данные запроса:');
      _log(requestData.toString());
      _log('========================================');

      final response = await _dio.post(
        '/notifications/register.php',
        data: requestData,
      );

      _log('========================================');
      _log('📥 ОТВЕТ ОТ СЕРВЕРА');
      _log('========================================');
      _log('Статус: ${response.statusCode}');
      _log('Данные: ${response.data}');
      _log('========================================');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is Map && responseData['success'] == true) {
          _log('✅✅✅ FCM ТОКЕН УСПЕШНО ЗАРЕГИСТРИРОВАН!');
          _log('Token ID: ${responseData['tokenId']}');
          _log('========================================');
          return responseData as Map<String, dynamic>;
        } else {
          _log('⚠️ Успешный ответ, но success != true');
          _log('Response: $responseData');
          return responseData is Map
              ? responseData as Map<String, dynamic>
              : null;
        }
      }

      _log('⚠️ Неожиданный статус код: ${response.statusCode}');
      _log('========================================');
      return null;
    } on DioException catch (e) {
      _log('========================================');
      _log('❌ DIOEXCEPTION ПРИ РЕГИСТРАЦИИ FCM');
      _log('========================================');
      _log('Type: ${e.type}');
      _log('Message: ${e.message}');
      _log('Status Code: ${e.response?.statusCode}');
      _log('Response data: ${e.response?.data}');
      _log('Request path: ${e.requestOptions.path}');
      _log('Request headers: ${e.requestOptions.headers}');
      _log('Request data: ${e.requestOptions.data}');
      _log('========================================');
      return null;
    } catch (e, stackTrace) {
      _log('========================================');
      _log('❌ ОШИБКА РЕГИСТРАЦИИ FCM ТОКЕНА');
      _log('========================================');
      _log('Error: $e');
      _log('Stack trace: $stackTrace');
      _log('========================================');
      return null;
    }
  }

  /// Регистрация VoIP токена (iOS)
  Future<Map<String, dynamic>?> registerVoIPToken(String token) async {
    try {
      _log('========================================');
      _log('📤 РЕГИСТРАЦИЯ VoIP ТОКЕНА (iOS)');
      _log('========================================');
      _log('Платформа: ios');
      _log(
          'Токен (первые 30): ${token.substring(0, token.length > 30 ? 30 : token.length)}...');
      _log('Длина токена: ${token.length}');
      _log('Endpoint: $baseUrl/notifications/register-voip.php');

      // Проверяем токен авторизации
      if (_authToken == null || _authToken!.isEmpty) {
        _log('⚠️⚠️⚠️ ТОКЕН АВТОРИЗАЦИИ НЕ УСТАНОВЛЕН!');
        _log('Пытаемся загрузить токен...');
        await _loadToken();

        if (_authToken == null || _authToken!.isEmpty) {
          _log('❌ Не удалось загрузить токен авторизации');
          _log('VoIP токен НЕ БУДЕТ зарегистрирован');
          return {'success': false, 'error': 'No auth token'};
        }

        _log(
            '✅ Токен авторизации загружен: ${_authToken!.substring(0, 20)}...');
      } else {
        _log(
            '✅ Токен авторизации присутствует: ${_authToken!.substring(0, 20)}...');
      }

      final requestData = {
        'token': token,
        'platform': 'ios',
        'type': 'voip', // Указываем что это VoIP токен
      };

      _log('========================================');
      _log('📦 Данные запроса:');
      _log(requestData.toString());
      _log('========================================');

      final response = await _dio.post(
        '/notifications/register-voip.php',
        data: requestData,
      );

      _log('========================================');
      _log('📥 ОТВЕТ ОТ СЕРВЕРА');
      _log('========================================');
      _log('Статус: ${response.statusCode}');
      _log('Данные: ${response.data}');
      _log('========================================');

      if (response.statusCode == 200) {
        final responseData = response.data;

        if (responseData is Map && responseData['success'] == true) {
          _log('✅✅✅ VoIP ТОКЕН УСПЕШНО ЗАРЕГИСТРИРОВАН!');
          _log('Token ID: ${responseData['tokenId']}');
          _log('========================================');
          return responseData as Map<String, dynamic>;
        } else {
          _log('⚠️ Успешный ответ, но success != true');
          _log('Response: $responseData');
          return responseData is Map
              ? responseData as Map<String, dynamic>
              : null;
        }
      }

      _log('⚠️ Неожиданный статус код: ${response.statusCode}');
      _log('========================================');
      return null;
    } on DioException catch (e) {
      _log('========================================');
      _log('❌ DIOEXCEPTION ПРИ РЕГИСТРАЦИИ VoIP');
      _log('========================================');
      _log('Type: ${e.type}');
      _log('Message: ${e.message}');
      _log('Status Code: ${e.response?.statusCode}');
      _log('Response data: ${e.response?.data}');
      _log('Request path: ${e.requestOptions.path}');
      _log('Request headers: ${e.requestOptions.headers}');
      _log('Request data: ${e.requestOptions.data}');
      _log('========================================');
      return null;
    } catch (e, stackTrace) {
      _log('========================================');
      _log('❌ ОШИБКА РЕГИСТРАЦИИ VoIP ТОКЕНА');
      _log('========================================');
      _log('Error: $e');
      _log('Stack trace: $stackTrace');
      _log('========================================');
      return null;
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

  Future<dynamic> post(String path, {Map<String, dynamic>? data}) async {
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

  // ===== МОДЕРАЦИЯ И ЖАЛОБЫ =====

  /// Отправить жалобу на пользователя/сообщение
  Future<Map<String, dynamic>> reportContent({
    required int reportedUserId,
    int? messageId,
    int? chatId,
    required String reportType,
    String? description,
  }) async {
    try {
      _log('Отправка жалобы на пользователя: $reportedUserId');

      final response = await _dio.post('/moderation/report.php', data: {
        'reported_user_id': reportedUserId,
        if (messageId != null) 'message_id': messageId,
        if (chatId != null) 'chat_id': chatId,
        'report_type': reportType,
        if (description != null) 'description': description,
      });

      if (response.statusCode == 200) {
        return response.data;
      }
      return {'success': false, 'error': 'Ошибка при отправке жалобы'};
    } on DioException catch (e) {
      _log('DioException при отправке жалобы: $e');
      if (e.response?.data != null && e.response?.data['error'] != null) {
        return {'success': false, 'error': e.response?.data['error']};
      }
      return {'success': false, 'error': 'Ошибка подключения'};
    } catch (e) {
      _log('Ошибка отправки жалобы: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Заблокировать пользователя
  Future<Map<String, dynamic>> blockUser(int userId, {String? reason}) async {
    try {
      _log('Блокировка пользователя: $userId');

      final response = await _dio.post('/moderation/block.php', data: {
        'blocked_user_id': userId,
        if (reason != null) 'reason': reason,
      });

      if (response.statusCode == 200) {
        return response.data;
      }
      return {'success': false, 'error': 'Ошибка при блокировке'};
    } on DioException catch (e) {
      _log('DioException при блокировке: $e');
      if (e.response?.data != null && e.response?.data['error'] != null) {
        return {'success': false, 'error': e.response?.data['error']};
      }
      return {'success': false, 'error': 'Ошибка подключения'};
    } catch (e) {
      _log('Ошибка блокировки: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Разблокировать пользователя
  Future<Map<String, dynamic>> unblockUser(int userId) async {
    try {
      _log('Разблокировка пользователя: $userId');

      final response = await _dio.post('/moderation/unblock.php', data: {
        'blocked_user_id': userId,
      });

      if (response.statusCode == 200) {
        return response.data;
      }
      return {'success': false, 'error': 'Ошибка при разблокировке'};
    } on DioException catch (e) {
      _log('DioException при разблокировке: $e');
      return {'success': false, 'error': 'Ошибка подключения'};
    } catch (e) {
      _log('Ошибка разблокировки: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Получить список заблокированных пользователей
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final response = await _dio.get('/moderation/blocked-users.php');

      if (response.statusCode == 200 && response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      _log('Ошибка получения заблокированных: $e');
      return [];
    }
  }

  /// Проверить статус блокировки с пользователем
  Future<Map<String, dynamic>> checkBlockedStatus(int userId) async {
    try {
      final response = await _dio.get('/moderation/check-blocked.php', queryParameters: {
        'user_id': userId,
      });

      if (response.statusCode == 200) {
        return response.data;
      }
      return {'blocked_by_me': false, 'blocked_me': false, 'can_message': true};
    } catch (e) {
      _log('Ошибка проверки блокировки: $e');
      return {'blocked_by_me': false, 'blocked_me': false, 'can_message': true};
    }
  }
}
