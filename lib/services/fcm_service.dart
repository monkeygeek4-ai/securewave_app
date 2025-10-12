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

  static const platform = MethodChannel('com.securewave.app/call');

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? _localNotifications;
  String? _fcmToken;

  Function(Map<String, dynamic>)? onIncomingCall;

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    print('[FCM] ========================================');
    print('[FCM] 🚀 Инициализация FCM Service');
    print('[FCM] Платформа: ${kIsWeb ? "Web" : Platform.operatingSystem}');
    print('[FCM] ========================================');

    if (!kIsWeb && Platform.isAndroid) {
      await _initializeLocalNotifications();
    }

    await _requestPermissions();
    await _getToken();
    _setupListeners();

    print('[FCM] ✅ FCM Service полностью инициализирован');
    print('[FCM] ========================================');
  }

  // ⭐ УБРАЛИ автоматический запрос overlay permission
  // Пользователь должен настроить вручную в настройках MIUI

  Future<void> _initializeLocalNotifications() async {
    print('[FCM] 📱 Инициализация локальных уведомлений...');

    try {
      _localNotifications = FlutterLocalNotificationsPlugin();

      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotifications!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationTap,
      );

      await _createNotificationChannels();

      print('[FCM] ✅ Локальные уведомления инициализированы');
    } catch (e) {
      print('[FCM] ❌ Ошибка инициализации локальных уведомлений: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    if (_localNotifications == null) return;

    print('[FCM] 📢 Создание notification channels...');

    try {
      // ⭐⭐⭐ FULL-SCREEN канал для звонков
      const callsChannel = AndroidNotificationChannel(
        'calls_channel',
        'Incoming Calls',
        description: 'Full-screen notifications for incoming calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      const messagesChannel = AndroidNotificationChannel(
        'messages_channel',
        'Messages',
        description: 'Notifications for new messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

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

  void _onNotificationTap(NotificationResponse response) {
    print('[FCM] ========================================');
    print('[FCM] 👆 Клик по уведомлению (foreground)');
    print('[FCM] Action ID: ${response.actionId}');
    print('[FCM] Payload: ${response.payload}');
    print('[FCM] ========================================');

    _handleNotificationAction(response.actionId, response.payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    print('[FCM] ========================================');
    print('[FCM] 👆 Клик по уведомлению (background/terminated)');
    print('[FCM] Action ID: ${response.actionId}');
    print('[FCM] Payload: ${response.payload}');
    print('[FCM] ========================================');
  }

  void _handleNotificationAction(String? actionId, String? payload) {
    if (payload == null) return;

    print('[FCM] 🎯 Обработка действия: $actionId');
    print('[FCM] 📦 Payload: $payload');

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
            _showCallScreen(callId, callerName, 'audio');
          } else if (actionId == 'decline') {
            print('[FCM] ❌ Отклонение звонка через уведомление');
            cancelCallNotification(callId);
          } else {
            print('[FCM] 📱 Открытие приложения для звонка');
            _showCallScreen(callId, callerName, 'audio');
          }
        }
        break;

      case 'message':
        if (parts.length >= 2) {
          final chatId = parts[1];
          print('[FCM] 💬 Открытие чата: $chatId');
        }
        break;

      default:
        print('[FCM] ❓ Неизвестный тип: $type');
    }
  }

  Future<void> _showCallScreen(
      String callId, String callerName, String callType) async {
    try {
      print('[FCM] 🚀 Вызов нативного метода showCallScreen');
      await platform.invokeMethod('showCallScreen', {
        'callId': callId,
        'callerName': callerName,
        'callType': callType,
      });
      print('[FCM] ✅ CallScreen показан');
    } catch (e) {
      print('[FCM] ❌ Ошибка показа CallScreen: $e');
    }
  }

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

  Future<String?> _getToken() async {
    try {
      print('[FCM] 🔑 Получение FCM токена...');

      String? token = await _firebaseMessaging.getToken();

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

  void _setupListeners() {
    print('[FCM] 👂 Настройка слушателей уведомлений');

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print('[FCM] 🔄 FCM токен обновлен');
      _fcmToken = newToken;
      _registerTokenOnBackend(newToken);
    });

    // ⭐ FOREGROUND MESSAGES
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM] ========================================');
      print('[FCM] 📩 📩 📩 FOREGROUND MESSAGE ПОЛУЧЕНО! 📩 📩 📩');
      print('[FCM] ========================================');
      print('[FCM] Message ID: ${message.messageId}');
      print('[FCM] ========================================');
      print('[FCM] 📦 DATA PAYLOAD:');
      message.data.forEach((key, value) {
        print('[FCM]   - $key: $value');
      });
      print('[FCM] ========================================');

      _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] ========================================');
      print('[FCM] 🖱️ Клик по уведомлению (background->foreground)');
      print('[FCM] Data: ${message.data}');
      print('[FCM] ========================================');

      _handleNotificationClick(message.data);
    });

    _checkInitialMessage();

    print('[FCM] ✅ Все слушатели настроены');
  }

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

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    print('[FCM] ========================================');
    print('[FCM] 🔍 ОБРАБОТКА FOREGROUND СООБЩЕНИЯ');
    print('[FCM] Тип: $type');
    print('[FCM] ========================================');

    switch (type) {
      case 'incoming_call':
        print('[FCM] 📞📞📞 ВХОДЯЩИЙ ЗВОНОК - ЗАПУСКАЕМ CallActivity!');

        final callId = data['callId'] ?? data['call_id'];
        final callerName =
            data['callerName'] ?? data['caller_name'] ?? 'Unknown';
        final callType = data['callType'] ?? data['call_type'] ?? 'audio';

        print('[FCM] Call ID: $callId');
        print('[FCM] Caller: $callerName');
        print('[FCM] Type: $callType');

        // ⭐⭐⭐ ЗАПУСКАЕМ CallActivity НАПРЯМУЮ
        _showCallScreen(callId, callerName, callType);

        // Также вызываем callback если установлен
        if (onIncomingCall != null) {
          final normalizedData = {
            'callId': callId,
            'callerName': callerName,
            'callType': callType,
            'callerAvatar': data['callerAvatar'] ?? data['caller_avatar'],
          };
          onIncomingCall!(normalizedData);
        }
        break;

      case 'new_message':
        print('[FCM] 💬 Новое сообщение (foreground)');
        _showMessageNotification(data);
        break;

      case 'call_ended':
        print('[FCM] 📵 Звонок завершен');
        final callId = data['callId'] ?? data['call_id'];
        if (callId != null) {
          cancelCallNotification(callId);
        }
        break;

      default:
        print('[FCM] ❓ Неизвестный тип: $type');
    }
  }

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
      final callId = data['callId'] ?? data['call_id'] ?? 'unknown';
      final callerName = data['callerName'] ?? data['caller_name'] ?? 'Unknown';
      final callType = data['callType'] ?? data['call_type'] ?? 'audio';

      print('[FCM] Call ID: $callId');
      print('[FCM] Caller: $callerName');
      print('[FCM] Type: $callType');

      final androidDetails = AndroidNotificationDetails(
        'calls_channel',
        'Incoming Calls',
        channelDescription: 'Full-screen notifications for incoming calls',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Incoming Call',
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('ringtone'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        styleInformation: BigTextStyleInformation(
          'Tap to answer the call',
          contentTitle:
              '📞 ${callType == "video" ? "Видеозвонок" : "Звонок"} от $callerName',
        ),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'decline',
            '❌ Отклонить',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          const AndroidNotificationAction(
            'accept',
            '✅ Принять',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications!.show(
        callId.hashCode,
        '📞 ${callType == "video" ? "Видеозвонок" : "Звонок"}',
        'От: $callerName',
        notificationDetails,
        payload: 'call:$callId:$callerName:$callType',
      );

      print('[FCM] ✅ Full-screen notification показан');
      print('[FCM] ========================================');
    } catch (e) {
      print('[FCM] ❌ Ошибка показа уведомления о звонке: $e');
      print('[FCM] Stack trace: $e');
    }
  }

  Future<void> _showMessageNotification(Map<String, dynamic> data) async {
    if (_localNotifications == null) return;

    try {
      final chatId = data['chatId'] ?? data['chat_id'] ?? 'unknown';
      final senderName = data['senderName'] ?? data['sender_name'] ?? 'Unknown';
      final messageText =
          data['messageText'] ?? data['message'] ?? 'New message';

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

  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'new_message':
        final chatId = data['chatId'];
        print('[FCM] 💬 Открываем чат: $chatId');
        break;

      case 'call':
      case 'incoming_call':
        final callId = data['callId'] ?? data['call_id'];
        final action = data['action'];
        print('[FCM] 📞 Обработка звонка: $callId, действие: $action');

        if (action == 'accept') {
          print('[FCM] ✅ Принятие звонка');
        } else if (action == 'decline') {
          print('[FCM] ❌ Отклонение звонка');
        }
        break;

      default:
        print('[FCM] ❓ Неизвестный тип: $type');
    }
  }

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

  Future<String?> getToken() async {
    if (_fcmToken != null) {
      return _fcmToken;
    }
    return await _getToken();
  }

  Future<void> refreshToken() async {
    final token = await getToken();
    if (token != null) {
      await _registerTokenOnBackend(token);
    }
  }
}
