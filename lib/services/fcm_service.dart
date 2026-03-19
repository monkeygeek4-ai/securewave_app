// lib/services/fcm_service.dart

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'api_service.dart';
import 'websocket_manager.dart';
import '../main.dart';
import '../screens/chat_screen.dart';
import '../providers/chat_provider.dart';
import 'package:provider/provider.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;

  FCMService._internal();

  static const platform = MethodChannel('com.securewave.app/call');
  static const notificationChannel =
      MethodChannel('com.securewave.app/notification');

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin? _localNotifications;
  String? _fcmToken;

  Function(Map<String, dynamic>)? onIncomingCall;
  Function(String callId)? onDeclineCall;

  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    // print('[FCM] ========================================');
    // print('[FCM] 🚀 Инициализация FCM Service');
    if (kIsWeb) {
      // print('[FCM] Платформа: Web');
    } else {
      // print('[FCM] Платформа: ${Platform.operatingSystem}');
    }
    // print('[FCM] ========================================');

    // ⭐⭐⭐ ИСПРАВЛЕНО: Инициализируем локальные уведомления для Android И iOS
    // Для iOS локальные уведомления нужны для показа уведомлений о сообщениях в foreground
    if (!kIsWeb) {
      await _initializeLocalNotifications();
    }

    await _requestPermissions();
    await _getToken();
    _setupListeners();
    _setupNativeChannelListener();

    // print('[FCM] ✅ FCM Service полностью инициализирован');
    // print('[FCM] ========================================');
  }

  void _setupNativeChannelListener() {
    // print('[FCM] 👂 Настройка слушателя Native Channel');

    notificationChannel.setMethodCallHandler((call) async {
      // print('[FCM] ========================================');
      // print('[FCM] 📥 Получен вызов от Native: ${call.method}');
      // print('[FCM] Arguments: ${call.arguments}');
      // print('[FCM] ========================================');

      switch (call.method) {
        case 'onNotificationTap':
          final data = Map<String, dynamic>.from(call.arguments);
          await _handleNativeNotificationTap(data);
          break;

        case 'openChat':
          final data = Map<String, dynamic>.from(call.arguments);
          await _openChatFromNotification(data);
          break;

        default:
          // print('[FCM] ⚠️ Неизвестный метод: ${call.method}');
      }
    });

    // print('[FCM] ✅ Native Channel listener настроен');
  }

  /// ✅ ИСПРАВЛЕНО: Добавлен autoAccept в callback
  Future<void> _handleNativeNotificationTap(Map<String, dynamic> data) async {
    // print('[FCM] ========================================');
    // print('[FCM] 📞 Обработка данных из Native');
    // print('[FCM] Type: ${data['type']}');
    // print('[FCM] CallId: ${data['callId']}');
    // print('[FCM] Action: ${data['action']}');
    // print('[FCM] AutoAccept: ${data['autoAccept']}');
    // print('[FCM] ========================================');

    final type = data['type'];
    final action = data['action'];

    if (type == 'incoming_call') {
      final callId = data['callId'];
      final callerName = data['callerName'] ?? 'Unknown';
      final callType = data['callType'] ?? 'audio';
      final autoAccept = data['autoAccept'] == true; // ✅ ИЗВЛЕКАЕМ autoAccept

      if (action == 'accept') {
        // print('[FCM] ========================================');
        // print('[FCM] ✅✅✅ ПОЛЬЗОВАТЕЛЬ ПРИНЯЛ ЗВОНОК!');
        // print('[FCM] CallId: $callId');
        // print('[FCM] AutoAccept: $autoAccept');
        // print('[FCM] Вызываем onIncomingCall callback...');
        // print('[FCM] ========================================');

        // ✅ ПЕРЕДАЕМ autoAccept В CALLBACK
        if (onIncomingCall != null) {
          onIncomingCall!({
            'callId': callId,
            'callerName': callerName,
            'callType': callType,
            'action': 'accept',
            'autoAccept': autoAccept, // ✅ КРИТИЧЕСКИ ВАЖНО!
          });
        } else {
          // print('[FCM] ⚠️ onIncomingCall callback не установлен!');
        }
      } else if (action == 'decline') {
        // print('[FCM] ========================================');
        // print('[FCM] ❌ ПОЛЬЗОВАТЕЛЬ ОТКЛОНИЛ ЗВОНОК');
        // print('[FCM] CallId: $callId');
        // print('[FCM] ========================================');

        if (onDeclineCall != null) {
          // print('[FCM] 📤 Вызываем onDeclineCall callback');
          onDeclineCall!(callId);
        } else {
          // print('[FCM] ⚠️ onDeclineCall callback не установлен!');
          // print('[FCM] 📤 Отправляем decline напрямую через WebSocket');

          try {
            WebSocketManager.instance.declineCall(callId);
            // print('[FCM] ✅ Decline отправлен через WebSocket');
          } catch (e) {
            // print('[FCM] ❌ Ошибка отправки decline: $e');
          }
        }
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // print('[FCM] 📱 Инициализация локальных уведомлений...');

    try {
      _localNotifications = FlutterLocalNotificationsPlugin();

      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // ⭐⭐⭐ ИСПРАВЛЕНО: Добавляем настройки для iOS
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotifications!.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationTap,
      );

      // ⭐⭐⭐ Создаем notification channels только для Android
      if (!kIsWeb && Platform.isAndroid) {
        await _createNotificationChannels();
      }

      // print('[FCM] ✅ Локальные уведомления инициализированы');
    } catch (e) {
      // print('[FCM] ❌ Ошибка инициализации локальных уведомлений: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    if (_localNotifications == null) return;

    // print('[FCM] 📢 Создание notification channels...');

    try {
      const callsChannel = AndroidNotificationChannel(
        'calls_channel',
        'Входящие звонки',
        description: 'Уведомления на весь экран для входящих звонков',
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
        // print('[FCM] ✅ Notification channels созданы');
      } else {
        // print('[FCM] ⚠️ Android plugin не найден');
      }
    } catch (e) {
      // print('[FCM] ❌ Ошибка создания channels: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    // print('[FCM] ========================================');
    // print('[FCM] 👆 Клик по уведомлению (foreground)');
    // print('[FCM] Action ID: ${response.actionId}');
    // print('[FCM] Payload: ${response.payload}');
    // print('[FCM] ========================================');

    _handleNotificationAction(response.actionId, response.payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    // print('[FCM] ========================================');
    // print('[FCM] 👆 Клик по уведомлению (background/terminated)');
    // print('[FCM] Action ID: ${response.actionId}');
    // print('[FCM] Payload: ${response.payload}');
    // print('[FCM] ========================================');
  }

  void _handleNotificationAction(String? actionId, String? payload) {
    if (payload == null) return;

    // print('[FCM] 🎯 Обработка действия: $actionId');
    // print('[FCM] 📦 Payload: $payload');

    final parts = payload.split(':');
    if (parts.isEmpty) return;

    final type = parts[0];

    switch (type) {
      case 'call':
        if (parts.length >= 3) {
          final callId = parts[1];
          final callerName = parts[2];

          // print('[FCM] ========================================');
          // print('[FCM] 📞 ДЕЙСТВИЕ СО ЗВОНКОМ');
          // print('[FCM] Call ID: $callId');
          // print('[FCM] Caller: $callerName');
          // print('[FCM] Action: $actionId');
          // print('[FCM] ========================================');

          if (actionId == 'accept') {
            // print('[FCM] ✅ Принятие звонка через уведомление');
            _showCallScreen(callId, callerName, 'audio');
          } else if (actionId == 'decline') {
            // print('[FCM] ❌ Отклонение звонка через уведомление');
            cancelCallNotification(callId);
          } else {
            // print('[FCM] 📱 Открытие приложения для звонка');
            _showCallScreen(callId, callerName, 'audio');
          }
        }
        break;

      case 'message':
        if (parts.length >= 2) {
          final chatId = parts[1];
          _openChatFromNotification({'chatId': chatId});
        }
        break;

      default:
        // print('[FCM] ❓ Неизвестный тип: $type');
    }
  }

  Future<void> _showCallScreen(
      String callId, String callerName, String callType) async {
    try {
      // print('[FCM] 🚀 Вызов нативного метода showCallScreen');
      await platform.invokeMethod('showCallScreen', {
        'callId': callId,
        'callerName': callerName,
        'callType': callType,
      });
      // print('[FCM] ✅ CallScreen показан');
    } catch (e) {
      // print('[FCM] ❌ Ошибка показа CallScreen: $e');
    }
  }

  Future<void> _requestPermissions() async {
    // print('[FCM] 📱 Запрос разрешений на уведомления');

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

      // print('[FCM] 🔔 Статус разрешений: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // print('[FCM] ✅ Разрешения получены');

        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        // print('[FCM] ⚠️ Временные разрешения получены');
      } else {
        // print('[FCM] ❌ Разрешения отклонены');
      }
    } catch (e) {
      // print('[FCM] ❌ Ошибка запроса разрешений: $e');
    }
  }

  Future<String?> _getToken() async {
    try {
      // print('[FCM] 🔑 Получение FCM токена...');

      String? voipToken;

      // ⭐⭐⭐ iOS: Сначала получаем APNS токен с retry
      if (!kIsWeb && Platform.isIOS) {
        // print('[FCM] 📱 iOS: Получение APNS токена...');
        String? apnsToken;

        // Retry до 10 раз с delay 5 секунд
        for (int i = 0; i < 10; i++) {
          try {
            apnsToken = await _firebaseMessaging.getAPNSToken();
            if (apnsToken != null) {
              // print('[FCM] ✅ APNS токен получен (попытка ${i + 1}): ${apnsToken.substring(0, min(30, apnsToken.length))}...');
              break;
            } else {
              if (i < 9) {
                // print('[FCM] ⚠️ APNS токен пока не доступен, ожидание 5 сек... (попытка ${i + 1}/10)');
                await Future.delayed(const Duration(seconds: 5));
              } else {
                // print('[FCM] ⚠️ APNS токен не получен после 10 попыток, пробуем получить FCM токен');
              }
            }
          } catch (e) {
            if (i < 9) {
              // print('[FCM] ⚠️ Ошибка получения APNS токена (попытка ${i + 1}/10): $e');
              await Future.delayed(const Duration(seconds: 5));
            } else {
              // print('[FCM] ❌ Не удалось получить APNS токен после 10 попыток: $e');
            }
          }
        }

        // ⭐⭐⭐ НОВОЕ: Получаем VoIP Push токен для iOS CallKit
        try {
          // print('[FCM] 📱 iOS: Получение VoIP Push токена...');
          voipToken = await platform.invokeMethod('getVoIPToken');
          if (voipToken != null && voipToken.isNotEmpty) {
            // print('[FCM] ✅ VoIP токен получен: ${voipToken.substring(0, min(30, voipToken.length))}...');
          } else {
            // print('[FCM] ⚠️ VoIP токен пустой или не получен');
          }
        } catch (e) {
          // print('[FCM] ⚠️ Ошибка получения VoIP токена: $e');
          // print('[FCM]    Возможно VoIP еще не настроен в iOS');
        }
      }

      String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        _fcmToken = token;
        // print('[FCM] ✅ FCM токен: ${token.substring(0, 30)}...');
        await _registerTokenOnBackend(token, voipToken);
      } else {
        // print('[FCM] ❌ Не удалось получить FCM токен');
      }

      return token;
    } catch (e) {
      // print('[FCM] ❌ Ошибка получения токена: $e');
      return null;
    }
  }

  Future<void> _registerTokenOnBackend(String token, [String? voipToken]) async {
    try {
      // print('[FCM] 📤 Регистрация токена на бэкенде...');

      final apiService = ApiService();
      final platformName = kIsWeb ? 'web' : Platform.operatingSystem;

      // print('[FCM] Platform: $platformName');
      if (voipToken != null) {
        // print('[FCM] VoIP токен: ${voipToken.substring(0, min(30, voipToken.length))}...');
      }

      final response = await apiService.registerFCMToken(token, platformName, voipToken);

      if (response != null && response['success'] == true) {
        // print('[FCM] ✅ Токен зарегистрирован на бэкенде');
      } else {
        // print('[FCM] ⚠️ Ошибка регистрации токена на бэкенде');
      }
    } catch (e) {
      // print('[FCM] ❌ Ошибка регистрации токена: $e');
    }
  }

  void _setupListeners() {
    // print('[FCM] 👂 Настройка слушателей уведомлений');

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      // print('[FCM] 🔄 FCM токен обновлен');
      _fcmToken = newToken;
      _registerTokenOnBackend(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // print('[FCM] ========================================');
      // print('[FCM] 📩 FOREGROUND MESSAGE ПОЛУЧЕНО!');
      // print('[FCM] ========================================');
      // print('[FCM] Message ID: ${message.messageId}');
      // print('[FCM] ========================================');
      // print('[FCM] 📦 DATA PAYLOAD:');
      message.data.forEach((key, value) {
        // print('[FCM]   - $key: $value');
      });
      // print('[FCM] ========================================');
      // ⭐⭐⭐ ИСПРАВЛЕНО: Проверяем наличие notification в payload для iOS
      if (!kIsWeb && Platform.isIOS) {
        // print('[FCM] 📱 iOS: Проверка notification payload...');
        if (message.notification != null) {
          // print('[FCM] ✅ Notification payload присутствует:');
          // print('[FCM]   Title: ${message.notification?.title}');
          // print('[FCM]   Body: ${message.notification?.body}');
        } else {
          // print('[FCM] ⚠️⚠️⚠️ КРИТИЧНО: Notification payload ОТСУТСТВУЕТ!');
          // print('[FCM] ⚠️ Для iOS уведомления должны содержать поле "notification"');
          // print('[FCM] ⚠️ Без него iOS НЕ покажет уведомление автоматически');
          // print('[FCM] ⚠️ Backend должен отправлять payload с полем "notification"');
        }
        // print('[FCM] ========================================');
      }

      await _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // print('[FCM] ========================================');
      // print('[FCM] 🖱️ Клик по уведомлению (background->foreground)');
      // print('[FCM] Data: ${message.data}');
      // print('[FCM] ========================================');

      _handleNotificationClick(message.data);
    });

    _checkInitialMessage();

    // print('[FCM] ✅ Все слушатели настроены');
  }

  Future<void> _checkInitialMessage() async {
    try {
      // print('[FCM] ========================================');
      // print('[FCM] 🔍 Проверка начального сообщения FCM...');
      if (kIsWeb) {
        // print('[FCM] Платформа: Web');
      } else {
        // print('[FCM] Платформа: ${Platform.isIOS ? "iOS" : Platform.isAndroid ? "Android" : "Unknown"}');
      }
      // print('[FCM] ========================================');
      
      // ⭐⭐⭐ ВАЖНО: getInitialMessage() работает только для Android
      // Для iOS FCM data-only уведомления обрабатываются через didReceiveRemoteNotification в AppDelegate.swift
      if (!kIsWeb && Platform.isIOS) {
        // print('[FCM] ⚠️ iOS: getInitialMessage() не работает для data-only уведомлений');
        // print('[FCM] ⚠️ iOS: FCM обрабатывается через didReceiveRemoteNotification в AppDelegate.swift');
        // print('[FCM] ========================================');
        return;
      }
      
      final initialMessage = await _firebaseMessaging.getInitialMessage();

      if (initialMessage != null) {
        // print('[FCM] ========================================');
        // print('[FCM] 🚀 Приложение открыто из уведомления (terminated)');
        // print('[FCM] Data: ${initialMessage.data}');
        // print('[FCM] ========================================');

        _handleNotificationClick(initialMessage.data);
      } else {
        // print('[FCM] ℹ️ Начальное сообщение не найдено');
      }
    } catch (e) {
      // print('[FCM] ⚠️ Ошибка проверки начального сообщения: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];

    // print('[FCM] ========================================');
    // print('[FCM] 🔍 ОБРАБОТКА FOREGROUND СООБЩЕНИЯ');
    // print('[FCM] Тип: $type');
    // print('[FCM] ========================================');

    switch (type) {
      case 'incoming_call':
      case 'call':
        // print('[FCM] ========================================');
        // print('[FCM] 📞 ВХОДЯЩИЙ ЗВОНОК (FOREGROUND)');
        // print('[FCM] ⚠️ Приложение ОТКРЫТО - WebSocket должен обработать!');
        // print('[FCM] 🚫 НЕ ЗАПУСКАЕМ CallActivity');
        // print('[FCM] ========================================');

        if (onIncomingCall != null) {
          final callId = data['callId'] ?? data['call_id'];
          final callerName =
              data['callerName'] ?? data['caller_name'] ?? 'Unknown';
          final callType = data['callType'] ?? data['call_type'] ?? 'audio';

          onIncomingCall!({
            'callId': callId,
            'callerName': callerName,
            'callType': callType,
            'callerAvatar': data['callerAvatar'] ?? data['caller_avatar'],
          });
        }
        break;

      case 'new_message':
        // print('[FCM] 💬 Новое сообщение (foreground)');
        // print('[FCM] Данные сообщения: $data');
        // ⭐⭐⭐ ИСПРАВЛЕНО: НЕ показываем уведомление здесь, так как:
        // 1. Сообщение придет через WebSocket и будет обработано в ChatProvider
        // 2. ChatProvider покажет уведомление только если чат не открыт
        // 3. Это предотвращает дублирование уведомлений
        // print('[FCM] ⏭️ Пропускаем показ уведомления - сообщение обработается через WebSocket в ChatProvider');
        break;

      case 'call_ended':
        // print('[FCM] 📵 Звонок завершен');
        final callId = data['callId'] ?? data['call_id'];
        if (callId != null) {
          cancelCallNotification(callId);
        }
        break;

      default:
        // print('[FCM] ❓ Неизвестный тип: $type');
    }
  }


  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'new_message':
        _openChatFromNotification(data);
        break;

      case 'call':
      case 'incoming_call':
        final callId = data['callId'] ?? data['call_id'];
        final callerName = data['callerName'] ?? data['caller_name'] ?? 'Unknown';
        final callType = data['callType'] ?? data['call_type'] ?? 'audio';
        final action = data['action'];
        
        // print('[FCM] ========================================');
        // print('[FCM] 📞 ОБРАБОТКА ЗВОНКА ИЗ УВЕДОМЛЕНИЯ');
        // print('[FCM] Call ID: $callId');
        // print('[FCM] Caller: $callerName');
        // print('[FCM] Type: $callType');
        // print('[FCM] Action: $action');
        // print('[FCM] ========================================');

        if (action == 'accept') {
          // print('[FCM] ✅ Принятие звонка через уведомление');
          // ⭐⭐⭐ КРИТИЧНО: Вызываем callback для обработки принятия звонка
          if (onIncomingCall != null) {
            onIncomingCall!({
              'callId': callId,
              'callerName': callerName,
              'callType': callType,
              'action': 'accept',
              'autoAccept': true, // Автоматически принимаем при клике на "Ответить"
            });
          } else {
            // print('[FCM] ⚠️ onIncomingCall callback не установлен!');
          }
        } else if (action == 'decline') {
          // print('[FCM] ❌ Отклонение звонка через уведомление');
          if (onDeclineCall != null) {
            onDeclineCall!(callId);
          } else {
            // print('[FCM] ⚠️ onDeclineCall callback не установлен!');
            try {
              WebSocketManager.instance.declineCall(callId);
              // print('[FCM] ✅ Decline отправлен через WebSocket');
            } catch (e) {
              // print('[FCM] ❌ Ошибка отправки decline: $e');
            }
          }
        } else {
          // ⭐⭐⭐ НОВОЕ: Если просто клик по уведомлению (не action), открываем CallScreen
          // print('[FCM] 📱 Открытие приложения для звонка');
          if (onIncomingCall != null) {
            onIncomingCall!({
              'callId': callId,
              'callerName': callerName,
              'callType': callType,
              'action': 'open',
            });
          } else {
            // print('[FCM] ⚠️ onIncomingCall callback не установлен!');
          }
        }
        break;

      default:
        // print('[FCM] ❓ Неизвестный тип: $type');
    }
  }

  Future<void> cancelCallNotification(String callId) async {
    // print('[FCM] 🚫 Отменяем уведомление для callId: $callId');

    // Отменяем через Flutter Local Notifications (если используется)
    if (_localNotifications != null) {
      try {
        await _localNotifications!.cancel(callId.hashCode);
        // print('[FCM] ✅ Flutter Local Notification отменено');
      } catch (e) {
        // print('[FCM] ⚠️ Ошибка отмены Flutter notification: $e');
      }
    }

    // Отменяем через Native Android код (CallNotificationHelper)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await platform.invokeMethod('cancelCallNotification', {'callId': callId});
        // print('[FCM] ✅ Native Android notification отменено');
      } catch (e) {
        // print('[FCM] ⚠️ Ошибка отмены native notification: $e');
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

  // ⭐⭐⭐ НОВОЕ: Публичный метод для показа локального уведомления о сообщении
  Future<void> showLocalMessageNotification({
    required String chatId,
    required String senderName,
    required String messageText,
  }) async {
    if (_localNotifications == null) {
      // print('[FCM] ⚠️ Локальные уведомления не инициализированы');
      return;
    }

    try {
      // print('[FCM] ========================================');
      // print('[FCM] 📱 Показ локального уведомления о сообщении');
      // print('[FCM] Chat ID: $chatId');
      // print('[FCM] Sender: $senderName');
      // print('[FCM] Message: $messageText');
      // print('[FCM] ========================================');

      const androidDetails = AndroidNotificationDetails(
        'messages_channel',
        'Messages',
        channelDescription: 'Notifications for new messages',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications!.show(
        chatId.hashCode,
        '💬 $senderName',
        messageText,
        notificationDetails,
        payload: 'message:$chatId',
      );

      // print('[FCM] ✅ Локальное уведомление о сообщении показано');
      // print('[FCM]   Chat ID: $chatId');
      // print('[FCM]   Sender: $senderName');
      // print('[FCM]   Message: $messageText');
    } catch (e) {
      // print('[FCM] ❌ Ошибка показа локального уведомления о сообщении: $e');
    }
  }

  /// ⭐⭐⭐ НОВОЕ: Открытие чата при нажатии на push-уведомление
  Future<void> _openChatFromNotification(Map<String, dynamic> data) async {
    final chatId = data['chatId'] ?? data['chat_id'];
    
    if (chatId == null || chatId.isEmpty) {
      print('[FCM] ⚠️ chatId отсутствует в данных уведомления');
      return;
    }

    print('[FCM] 💬 Открываем чат из уведомления: $chatId');

    // Ждем, пока приложение полностью загрузится
    await Future.delayed(const Duration(milliseconds: 500));

    if (navigatorKey.currentState == null || navigatorKey.currentContext == null) {
      print('[FCM] ⚠️ Navigator еще не готов, повторная попытка через 1 секунду...');
      await Future.delayed(const Duration(seconds: 1));
      
      if (navigatorKey.currentState == null || navigatorKey.currentContext == null) {
        print('[FCM] ❌ Navigator все еще не готов');
        return;
      }
    }

    final context = navigatorKey.currentContext!;
    
    try {
      // Получаем ChatProvider
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Убеждаемся, что чаты загружены
      if (chatProvider.chats.isEmpty) {
        print('[FCM] 📥 Чаты не загружены, загружаем...');
        await chatProvider.loadChats();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Получаем чат по ID
      final chat = chatProvider.getChatById(chatId);
      
      if (chat == null) {
        print('[FCM] ⚠️ Чат $chatId не найден, пытаемся загрузить чаты еще раз...');
        await chatProvider.loadChats();
        await Future.delayed(const Duration(milliseconds: 500));
        
        final chatRetry = chatProvider.getChatById(chatId);
        if (chatRetry == null) {
          print('[FCM] ❌ Чат $chatId не найден после повторной загрузки');
          return;
        }
        
        // Открываем чат
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(chat: chatRetry),
          ),
        );
        print('[FCM] ✅ Чат открыт: ${chatRetry.name}');
      } else {
        // Открываем чат
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(chat: chat),
          ),
        );
        print('[FCM] ✅ Чат открыт: ${chat.name}');
      }
    } catch (e, stackTrace) {
      print('[FCM] ❌ Ошибка открытия чата: $e');
      print('[FCM] Stack: $stackTrace');
    }
  }
}
