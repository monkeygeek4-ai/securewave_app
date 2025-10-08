// lib/services/notification_service.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Обработчик фоновых уведомлений (должен быть top-level функцией)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[FCM] 🔔 Фоновое уведомление: ${message.messageId}');
  print('[FCM] Данные: ${message.data}');
}

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Stream для обработки нажатий на уведомления
  final StreamController<Map<String, dynamic>> _notificationClickController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationClick =>
      _notificationClickController.stream;

  Future<void> initialize() async {
    print('[Notifications] ========================================');
    print('[Notifications] Инициализация сервиса уведомлений');
    print('[Notifications] ========================================');

    try {
      // 1. Запрашиваем разрешения
      await _requestPermissions();

      // 2. Настраиваем локальные уведомления
      await _initializeLocalNotifications();

      // 3. Получаем FCM токен
      await _getFCMToken();

      // 4. Настраиваем обработчики FCM
      _setupFCMHandlers();

      // 5. Регистрируем обработчик фоновых уведомлений
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      print('[Notifications] ✅ Сервис успешно инициализирован');
    } catch (e) {
      print('[Notifications] ❌ Ошибка инициализации: $e');
    }
  }

  Future<void> _requestPermissions() async {
    print('[Notifications] 📋 Запрос разрешений...');

    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    print('[Notifications] Статус разрешений: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('[Notifications] ✅ Разрешения получены');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('[Notifications] ⚠️ Временные разрешения');
    } else {
      print('[Notifications] ❌ Разрешения отклонены');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    print('[Notifications] 🔔 Настройка локальных уведомлений...');

    // Android настройки
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS настройки
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Создаем канал уведомлений для Android
    if (!kIsWeb) {
      const androidChannel = AndroidNotificationChannel(
        'high_importance_channel',
        'Важные уведомления',
        description: 'Канал для важных уведомлений приложения',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Канал для звонков
      const callChannel = AndroidNotificationChannel(
        'call_channel',
        'Входящие звонки',
        description: 'Уведомления о входящих звонках',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('ringtone'),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(callChannel);
    }

    print('[Notifications] ✅ Локальные уведомления настроены');
  }

  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      print('[Notifications] ========================================');
      print('[Notifications] 🔑 FCM Token получен:');
      print('[Notifications] $_fcmToken');
      print('[Notifications] ========================================');

      // TODO: Отправьте токен на ваш сервер
      // await _sendTokenToServer(_fcmToken!);

      // Слушаем обновления токена
      _fcm.onTokenRefresh.listen((newToken) {
        print('[Notifications] 🔄 FCM Token обновлен: $newToken');
        _fcmToken = newToken;
        // TODO: Отправьте новый токен на сервер
        // _sendTokenToServer(newToken);
      });
    } catch (e) {
      print('[Notifications] ❌ Ошибка получения FCM токена: $e');
    }
  }

  void _setupFCMHandlers() {
    print('[Notifications] 🎯 Настройка обработчиков FCM...');

    // Когда приложение в foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[Notifications] ========================================');
      print('[Notifications] 📨 Уведомление получено (foreground)');
      print('[Notifications] Заголовок: ${message.notification?.title}');
      print('[Notifications] Текст: ${message.notification?.body}');
      print('[Notifications] Данные: ${message.data}');
      print('[Notifications] ========================================');

      _handleForegroundMessage(message);
    });

    // Когда приложение открывается из уведомления
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[Notifications] ========================================');
      print('[Notifications] 📱 Приложение открыто из уведомления');
      print('[Notifications] Данные: ${message.data}');
      print('[Notifications] ========================================');

      _handleNotificationClick(message.data);
    });

    // Проверяем, было ли приложение запущено из уведомления
    _fcm.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('[Notifications] ========================================');
        print('[Notifications] 🚀 Приложение запущено из уведомления');
        print('[Notifications] Данные: ${message.data}');
        print('[Notifications] ========================================');

        _handleNotificationClick(message.data);
      }
    });

    print('[Notifications] ✅ Обработчики FCM настроены');
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'];

    if (type == 'call') {
      // Входящий звонок
      _showCallNotification(
        title: message.notification?.title ?? 'Входящий звонок',
        body: message.notification?.body ?? 'Нажмите для ответа',
        payload: message.data,
      );
    } else if (type == 'message') {
      // Новое сообщение
      _showMessageNotification(
        title: message.notification?.title ?? 'Новое сообщение',
        body: message.notification?.body ?? '',
        payload: message.data,
      );
    } else {
      // Обычное уведомление
      _showNotification(
        title: message.notification?.title ?? 'Уведомление',
        body: message.notification?.body ?? '',
        payload: message.data,
      );
    }
  }

  Future<void> _showCallNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    print('[Notifications] 📞 Показываем уведомление о звонке');

    const androidDetails = AndroidNotificationDetails(
      'call_channel',
      'Входящие звонки',
      channelDescription: 'Уведомления о входящих звонках',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ringtone'),
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ringtone.aiff',
      categoryIdentifier: 'call',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      payload['callId'].hashCode,
      title,
      body,
      notificationDetails,
      payload: _encodePayload(payload),
    );
  }

  Future<void> _showMessageNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    print('[Notifications] 💬 Показываем уведомление о сообщении');

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Важные уведомления',
      channelDescription: 'Канал для важных уведомлений приложения',
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

    await _localNotifications.show(
      payload['chatId'].hashCode,
      title,
      body,
      notificationDetails,
      payload: _encodePayload(payload),
    );
  }

  Future<void> _showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Важные уведомления',
      channelDescription: 'Канал для важных уведомлений приложения',
      importance: Importance.high,
      priority: Priority.high,
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

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: _encodePayload(payload),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('[Notifications] ========================================');
    print('[Notifications] 👆 Нажатие на уведомление');
    print('[Notifications] Payload: ${response.payload}');
    print('[Notifications] ========================================');

    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      _handleNotificationClick(data);
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    print('[Notifications] 🎯 Обработка нажатия на уведомление');
    print('[Notifications] Тип: ${data['type']}');

    // Отправляем событие в stream
    _notificationClickController.add(data);
  }

  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  Map<String, dynamic> _decodePayload(String payload) {
    final map = <String, dynamic>{};
    for (final pair in payload.split('|')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  void dispose() {
    _notificationClickController.close();
  }
}
