// lib/services/fcm_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'api_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;

  FCMService._internal();

  static const platform = MethodChannel('com.securewave.app/fcm');

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? _localNotifications;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Инициализация FCM
  Future<void> initialize() async {
    print('[FCM] ========================================');
    print('[FCM] 🚀 Инициализация FCM Service');
    print('[FCM] Платформа: ${kIsWeb ? "Web" : Platform.operatingSystem}');
    print('[FCM] ========================================');

    // Инициализируем локальные уведомления для Android
    if (!kIsWeb && Platform.isAndroid) {
      await _initializeLocalNotifications();
    }

    // Запрашиваем разрешения
    await _requestPermissions();

    // Получаем токен
    await _getToken();

    // Настраиваем слушателей
    _setupListeners();

    print('[FCM] ✅ FCM Service полностью инициализирован');
    print('[FCM] ========================================');
  }

  /// Инициализация локальных уведомлений для Android
  Future<void> _initializeLocalNotifications() async {
    print('[FCM] 📱 Инициализация локальных уведомлений...');

    try {
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Настройки инициализации для Android
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      // Инициализируем плагин
      await _localNotifications!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationTap,
      );

      // Создаем каналы уведомлений
      await _createNotificationChannels();

      print('[FCM] ✅ Локальные уведомления инициализированы');
    } catch (e) {
      print('[FCM] ❌ Ошибка инициализации локальных уведомлений: $e');
    }
  }

  /// Создание каналов уведомлений
  Future<void> _createNotificationChannels() async {
    if (_localNotifications == null) return;

    print('[FCM] 📢 Создание notification channels...');

    try {
      // Канал для звонков
      const callsChannel = AndroidNotificationChannel(
        'calls_channel',
        'Incoming Calls',
        description: 'Notifications for incoming calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      // Канал для сообщений
      const messagesChannel = AndroidNotificationChannel(
        'messages_channel',
        'Messages',
        description: 'Notifications for new messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      // Получаем Android implementation - ВСЁ В ОДНОЙ СТРОКЕ!
      final android = _localNotifications!
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        await android.createNotificationChannel(callsChannel);
        await android.createNotificationChannel(messagesChannel);
        print('[FCM] ✅ Notification channels созданы');
      } else {
        print('[FCM] ⚠️ Android plugin не найден');
      }
    } catch (e) {
      print('[FCM] ❌ Ошибка создания channels: $e');
    }
  }

  /// Обработка клика по уведомлению (foreground/background)
  void _onNotificationTap(NotificationResponse response) {
    print('[FCM] ========================================');
    print('[FCM] 👆 Клик по уведомлению (foreground)');
    print('[FCM] Action ID: ${response.actionId}');
    print('[FCM] Payload: ${response.payload}');
    print('[FCM] ========================================');

    _handleNotificationAction(response.actionId, response.payload);
  }

  /// Обработка клика по уведомлению (terminated state)
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    print('[FCM] ========================================');
    print('[FCM] 👆 Клик по уведомлению (background/terminated)');
    print('[FCM] Action ID: ${response.actionId}');
    print('[FCM] Payload: ${response.payload}');
    print('[FCM] ========================================');
  }

  /// Обработка действий с уведомлением
  void _handleNotificationAction(String? actionId, String? payload) {
    if (payload == null) return;

    print('[FCM] 🎯 Обработка действия: $actionId');
    print('[FCM] 📦 Payload: $payload');

    // Парсим payload: "type:id:extra"
    final parts = payload.split(':');
    if (parts.isEmpty) return;

    final type = parts[0];

    switch (type) {
      case 'call':
        if (parts.length >= 3) {
          final callId = parts[1];
          final callerName = parts[2];

          print('[FCM] ========================================');
          print('[FCM] 📞 ДЕЙСТВИЕ СО ЗВОНКОМ');
          print('[FCM] Call ID: $callId');
          print('[FCM] Caller: $callerName');
          print('[FCM] Action: $actionId');
          print('[FCM] ========================================');

          if (actionId == 'accept') {
            print('[FCM] ✅ Принятие звонка через уведомление');
            // TODO: Открыть CallScreen и принять звонок
          } else if (actionId == 'decline') {
            print('[FCM] ❌ Отклонение звонка через уведомление');
            cancelCallNotification(callId);
          } else {
            print('[FCM] 📱 Открытие приложения для звонка');
          }
        }
        break;

      case 'message':
        if (parts.length >= 2) {
          final chatId = parts[1];
          print('[FCM] 💬 Открытие чата: $chatId');
          // TODO: Навигация к чату
        }
        break;

      default:
        print('[FCM] ❓ Неизвестный тип: $type');
    }
  }

  /// Запрос разрешений
  Future<void> _requestPermissions() async {
    print('[FCM] 📱 Запрос разрешений на уведомления');

    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      print('[FCM] 🔔 Статус разрешений: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('[FCM] ✅ Разрешения получены');

        // Настраиваем presentation options
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print('[FCM] ⚠️ Временные разрешения получены');
      } else {
        print('[FCM] ❌ Разрешения отклонены');
      }
    } catch (e) {
      print('[FCM] ❌ Ошибка запроса разрешений: $e');
    }
  }

  /// Получение FCM токена
  Future<String?> _getToken() async {
    try {
      print('[FCM] 🔑 Получение FCM токена...');

      String? token = await _firebaseMessaging.getToken();

      if (token == null && !kIsWeb && Platform.isAndroid) {
        print('[FCM] 🔍 Пробуем получить токен из SharedPreferences...');
        try {
          token = await platform.invokeMethod('getFCMToken');
        } catch (e) {
          print('[FCM] ⚠️ Ошибка получения токена из SharedPreferences: $e');
        }
      }

      if (token != null) {
        _fcmToken = token;
        print('[FCM] ✅ FCM токен: ${token.substring(0, 30)}...');
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
      final platformName = kIsWeb ? 'web' : Platform.operatingSystem;
      final response = await apiService.registerFCMToken(token, platformName);

      if (response != null && response['success'] == true) {
        print('[FCM] ✅ Токен зарегистрирован на бэкенде');
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

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM] ========================================');
      print('[FCM] 📩 Foreground уведомление');
      print('[FCM] Title: ${message.notification?.title}');
      print('[FCM] Body: ${message.notification?.body}');
      print('[FCM] Data: ${message.data}');
      print('[FCM] ========================================');

      _handleForegroundMessage(message);
    });

    // Background/terminated -> foreground (клик по уведомлению)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] ========================================');
      print('[FCM] 🖱️ Клик по уведомлению (background->foreground)');
      print('[FCM] Data: ${message.data}');
      print('[FCM] ========================================');

      _handleNotificationClick(message.data);
    });

    // Нативный обработчик кликов (Android)
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationClick') {
        final data = Map<String, dynamic>.from(call.arguments);
        print('[FCM] 🖱️ Клик по уведомлению (нативное событие)');
        print('[FCM] 📦 Данные: $data');
        _handleNotificationClick(data);
      }
    });

    // Проверяем начальное уведомление
    _checkInitialMessage();

    print('[FCM] ✅ Все слушатели настроены');
  }

  /// Проверка начального уведомления
  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _firebaseMessaging.getInitialMessage();

      if (initialMessage != null) {
        print('[FCM] ========================================');
        print('[FCM] 🚀 Приложение открыто из уведомления (terminated)');
        print('[FCM] Data: ${initialMessage.data}');
        print('[FCM] ========================================');

        _handleNotificationClick(initialMessage.data);
      }
    } catch (e) {
      print('[FCM] ⚠️ Ошибка проверки начального сообщения: $e');
    }
  }

  /// Обработка foreground уведомления
  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'];

    switch (type) {
      case 'call':
        print('[FCM] 📞 Входящий звонок (foreground)');
        _showFullScreenCallNotification(message.data);
        break;

      case 'new_message':
        print('[FCM] 💬 Новое сообщение (foreground)');
        _showMessageNotification(message.data);
        break;

      default:
        print('[FCM] 📦 Неизвестный тип: $type');
    }
  }

  /// Полноэкранное уведомление о звонке
  Future<void> _showFullScreenCallNotification(
      Map<String, dynamic> data) async {
    if (_localNotifications == null) {
      print('[FCM] ⚠️ LocalNotifications не инициализированы');
      return;
    }

    print('[FCM] ========================================');
    print('[FCM] 📱 ПОКАЗЫВАЕМ FULL-SCREEN УВЕДОМЛЕНИЕ О ЗВОНКЕ');
    print('[FCM] ========================================');

    try {
      final callId = data['call_id'] ?? data['callId'] ?? 'unknown';
      final callerName = data['caller_name'] ?? data['callerName'] ?? 'Unknown';
      final callType = data['call_type'] ?? data['callType'] ?? 'video';

      print('[FCM] Call ID: $callId');
      print('[FCM] Caller: $callerName');
      print('[FCM] Type: $callType');

      // Создаем детали уведомления
      final androidDetails = AndroidNotificationDetails(
        'calls_channel',
        'Incoming Calls',
        channelDescription: 'Notifications for incoming calls',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Incoming Call',
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        styleInformation: const BigTextStyleInformation(
          'Tap to answer the call',
          contentTitle: '📞 Incoming Call',
        ),
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            'decline',
            '❌ Decline',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'accept',
            '✅ Accept',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications!.show(
        callId.hashCode,
        '📞 Incoming Call',
        'From: $callerName',
        notificationDetails,
        payload: 'call:$callId:$callerName',
      );

      print('[FCM] ✅ Full-screen notification показан');
      print('[FCM] ========================================');
    } catch (e) {
      print('[FCM] ❌ Ошибка показа уведомления о звонке: $e');
    }
  }

  /// Показ уведомления о сообщении
  Future<void> _showMessageNotification(Map<String, dynamic> data) async {
    if (_localNotifications == null) return;

    try {
      final chatId = data['chatId'] ?? data['chat_id'] ?? 'unknown';
      final senderName = data['sender_name'] ?? data['senderName'] ?? 'Unknown';
      final messageText = data['message'] ?? 'New message';

      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications!.show(
        chatId.hashCode,
        '💬 $senderName',
        messageText,
        notificationDetails,
        payload: 'message:$chatId',
      );
    } catch (e) {
      print('[FCM] ❌ Ошибка показа уведомления о сообщении: $e');
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

      case 'call':
      case 'incoming_call':
        final callId = data['callId'] ?? data['call_id'];
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
        print('[FCM] ❓ Неизвестный тип: $type');
    }
  }

  /// Отмена уведомления о звонке
  Future<void> cancelCallNotification(String callId) async {
    if (_localNotifications != null) {
      try {
        await _localNotifications!.cancel(callId.hashCode);
        print('[FCM] ✅ Уведомление отменено: $callId');
      } catch (e) {
        print('[FCM] ❌ Ошибка отмены уведомления: $e');
      }
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
