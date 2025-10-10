// lib/services/fcm_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;

  FCMService._internal();

  static const platform = MethodChannel('com.securewave.app/fcm');

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Инициализация FCM
  Future<void> initialize() async {
    print('[FCM] 🚀 Инициализация FCM Service');

    // Запрашиваем разрешения
    await _requestPermissions();

    // Получаем токен
    await _getToken();

    // Настраиваем слушателей
    _setupListeners();

    print('[FCM] ✅ FCM Service инициализирован');
  }

  /// Запрос разрешений
  Future<void> _requestPermissions() async {
    print('[FCM] 📱 Запрос разрешений на уведомления');

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('[FCM] 🔔 Статус разрешений: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[FCM] ✅ Разрешения получены');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('[FCM] ⚠️ Временные разрешения получены');
    } else {
      print('[FCM] ❌ Разрешения отклонены');
    }
  }

  /// Получение FCM токена
  Future<String?> _getToken() async {
    try {
      print('[FCM] 🔑 Получение FCM токена...');

      // Пытаемся получить токен из Firebase
      String? token = await _firebaseMessaging.getToken();

      // Если не получили - пробуем получить из нативного кода (для Android)
      if (token == null) {
        print(
            '[FCM] 🔍 Токен не получен от Firebase, пробуем SharedPreferences...');
        try {
          token = await platform.invokeMethod('getFCMToken');
        } catch (e) {
          print('[FCM] ⚠️ Не удалось получить токен из SharedPreferences: $e');
        }
      }

      if (token != null) {
        _fcmToken = token;
        print('[FCM] ✅ FCM токен получен: ${token.substring(0, 20)}...');

        // Регистрируем токен на бэкенде
        await _registerTokenOnBackend(token);
      } else {
        print('[FCM] ❌ Не удалось получить FCM токен');
      }

      return token;
    } catch (e) {
      print('[FCM] ❌ Ошибка получения токена: $e');
      return null;
    }
  }

  /// Регистрация токена на бэкенде
  Future<void> _registerTokenOnBackend(String token) async {
    try {
      print('[FCM] 📤 Регистрация токена на бэкенде...');

      final apiService = ApiService();
      final response = await apiService.registerFCMToken(token, 'android');

      if (response != null && response['success'] == true) {
        print('[FCM] ✅ Токен успешно зарегистрирован на бэкенде');
      } else {
        print('[FCM] ⚠️ Ошибка регистрации токена на бэкенде');
      }
    } catch (e) {
      print('[FCM] ❌ Ошибка регистрации токена: $e');
    }
  }

  /// Настройка слушателей уведомлений
  void _setupListeners() {
    print('[FCM] 👂 Настройка слушателей уведомлений');

    // Обновление токена
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('[FCM] 🔄 FCM токен обновлен');
      _fcmToken = newToken;
      _registerTokenOnBackend(newToken);
    });

    // Уведомления когда приложение на переднем плане
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM] 📩 Получено foreground уведомление');
      print('[FCM] 📦 Данные: ${message.data}');

      if (message.notification != null) {
        print('[FCM] 🔔 Заголовок: ${message.notification?.title}');
        print('[FCM] 💬 Текст: ${message.notification?.body}');
      }

      // Здесь можно показать локальное уведомление или обновить UI
      _handleForegroundMessage(message);
    });

    // Клик по уведомлению когда приложение в фоне
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] 🖱️ Клик по уведомлению (приложение в фоне)');
      print('[FCM] 📦 Данные: ${message.data}');
      _handleNotificationClick(message.data);
    });

    // Настраиваем слушатель для нативных событий (Android)
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationClick') {
        final data = Map<String, dynamic>.from(call.arguments);
        print('[FCM] 🖱️ Клик по уведомлению (нативное событие)');
        print('[FCM] 📦 Данные: $data');
        _handleNotificationClick(data);
      }
    });

    // Проверяем, было ли приложение открыто из уведомления
    _checkInitialMessage();
  }

  /// Проверка начального уведомления (если приложение было закрыто)
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      print('[FCM] 🚀 Приложение открыто из уведомления');
      print('[FCM] 📦 Данные: ${initialMessage.data}');
      _handleNotificationClick(initialMessage.data);
    }
  }

  /// Обработка уведомления на переднем плане
  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'];

    switch (type) {
      case 'new_message':
        print('[FCM] 💬 Новое сообщение (foreground)');
        // Здесь можно обновить список чатов
        break;
      case 'incoming_call':
        print('[FCM] 📞 Входящий звонок (foreground)');
        // Здесь можно показать диалог входящего звонка
        break;
      default:
        print('[FCM] 📦 Неизвестный тип уведомления: $type');
    }
  }

  /// Обработка клика по уведомлению
  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'new_message':
        final chatId = data['chatId'];
        print('[FCM] 💬 Открываем чат: $chatId');
        // TODO: Навигация к чату
        break;

      case 'incoming_call':
        final callId = data['callId'];
        final action = data['action'];
        print('[FCM] 📞 Обработка звонка: $callId, действие: $action');

        if (action == 'accept') {
          print('[FCM] ✅ Принятие звонка');
          // TODO: Принять звонок
        } else if (action == 'decline') {
          print('[FCM] ❌ Отклонение звонка');
          // TODO: Отклонить звонок
        }
        break;

      default:
        print('[FCM] ❓ Неизвестный тип клика: $type');
    }
  }

  /// Получить текущий токен
  Future<String?> getToken() async {
    if (_fcmToken != null) {
      return _fcmToken;
    }
    return await _getToken();
  }

  /// Обновить токен на бэкенде
  Future<void> refreshToken() async {
    final token = await getToken();
    if (token != null) {
      await _registerTokenOnBackend(token);
    }
  }
}
