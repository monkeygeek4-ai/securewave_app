// lib/services/notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import '../services/api_service.dart';
import '../services/title_notification_service.dart';

// Background message handler (должен быть top-level функцией)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[FCM Background] Получено сообщение: ${message.messageId}');

  // Обрабатываем уведомление в фоне
  await NotificationService.handleBackgroundMessage(message);
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _initialized = false;

  // ID каналов для уведомлений
  static const String _messageChannelId = 'messages_channel';
  static const String _messageChannelName = 'Сообщения';
  static const String _callChannelId = 'calls_channel';
  static const String _callChannelName = 'Звонки';

  Future<void> initialize() async {
    if (_initialized) return;

    print('[NotificationService] Инициализация...');

    // Инициализация Firebase
    if (!kIsWeb) {
      await Firebase.initializeApp();
    }

    // Инициализация FCM
    if (!kIsWeb) {
      await _initFCM();
    } else {
      await _initWebNotifications();
    }

    // Инициализация Local Notifications
    await _initLocalNotifications();

    // Инициализация Title Notifications для веб
    if (kIsWeb) {
      TitleNotificationService.instance.initialize();
      print('[NotificationService] ✅ Title notifications инициализирован');
    }

    _initialized = true;
    print('[NotificationService] ✅ Инициализация завершена');
  }

  // Инициализация FCM для мобильных платформ
  Future<void> _initFCM() async {
    // Запрашиваем разрешения
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    print('[FCM] Статус разрешений: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Получаем FCM токен
      _fcmToken = await _fcm.getToken();
      print('[FCM] Токен получен: $_fcmToken');

      // Отправляем токен на сервер
      if (_fcmToken != null) {
        await _sendTokenToServer(_fcmToken!);
      }

      // Слушаем обновления токена
      _fcm.onTokenRefresh.listen((newToken) {
        print('[FCM] Токен обновлен: $newToken');
        _fcmToken = newToken;
        _sendTokenToServer(newToken);
      });

      // Background message handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Когда пользователь открывает уведомление
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Проверяем, было ли приложение открыто из уведомления
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    }
  }

  // Инициализация Web Notifications
  Future<void> _initWebNotifications() async {
    if (kIsWeb) {
      try {
        // Замените на ваш VAPID ключ из Firebase Console
        final token = await _fcm.getToken(
          vapidKey:
              'BFa2MCbGoEgkfwY72WfpeycJjH4rTzboMqka_e0niTIHhLhBp_b5unNIus46patWHo9-KpqND1WiEiMkKIrjSR0',
        );

        if (token != null) {
          _fcmToken = token;
          print('[Web FCM] Токен получен: $token');
          await _sendTokenToServer(token);
        }

        // Слушаем сообщения в web
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      } catch (e) {
        print('[Web FCM] Ошибка: $e');
      }
    }
  }

  // Инициализация Local Notifications
  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Создаем каналы для Android
    if (!kIsWeb && Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  // Создание каналов уведомлений для Android
  Future<void> _createNotificationChannels() async {
    const messageChannel = AndroidNotificationChannel(
      _messageChannelId,
      _messageChannelName,
      description: 'Уведомления о новых сообщениях',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    const callChannel = AndroidNotificationChannel(
      _callChannelId,
      _callChannelName,
      description: 'Уведомления о входящих звонках',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messageChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);
  }

  // Отправка токена на сервер
  Future<void> _sendTokenToServer(String token) async {
    try {
      await ApiService.instance.post('/notifications/register', data: {
        'token': token,
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      });
      print('[NotificationService] ✅ Токен отправлен на сервер');
    } catch (e) {
      print('[NotificationService] ❌ Ошибка отправки токена: $e');
    }
  }

  // Обработка foreground сообщений
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('[FCM Foreground] Получено: ${message.data}');

    final data = message.data;
    final type = data['type'];

    if (type == 'new_message') {
      // Увеличиваем счетчик и мигаем заголовком (только для веб)
      if (kIsWeb) {
        final messagePreview = '${data['senderName']}: ${data['messageText']}';
        TitleNotificationService.instance.incrementUnread(
            message: messagePreview.length > 50
                ? messagePreview.substring(0, 50) + '...'
                : messagePreview);
      }

      await _showMessageNotification(
        chatId: data['chatId'],
        senderName: data['senderName'],
        messageText: data['messageText'],
        senderAvatar: data['senderAvatar'],
      );
    } else if (type == 'incoming_call') {
      // Для звонков тоже показываем в заголовке
      if (kIsWeb) {
        // ИСПРАВЛЕНО: добавлен именованный параметр duration
        TitleNotificationService.instance.showTemporaryNotification(
            'Входящий звонок от ${data['callerName']}',
            duration: const Duration(seconds: 30));
      }

      await _showIncomingCallNotification(
        callId: data['callId'],
        callerName: data['callerName'],
        callType: data['callType'],
        callerAvatar: data['callerAvatar'],
      );
    }
  }

  // Обработка background сообщений
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print('[FCM Background] Обработка: ${message.data}');
    // Здесь можно обработать фоновое сообщение
  }

  // Когда пользователь открывает уведомление
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('[FCM Opened] Уведомление открыто: ${message.data}');

    final data = message.data;
    final type = data['type'];

    // Навигация в зависимости от типа
    if (type == 'new_message') {
      // TODO: Открыть чат
      print('[FCM Opened] Открытие чата: ${data['chatId']}');
    } else if (type == 'incoming_call') {
      // TODO: Открыть экран звонка
      print('[FCM Opened] Открытие звонка: ${data['callId']}');
    }
  }

  // === УВЕДОМЛЕНИЯ О СООБЩЕНИЯХ ===

  Future<void> _showMessageNotification({
    required String chatId,
    required String senderName,
    required String messageText,
    String? senderAvatar,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _messageChannelId,
      _messageChannelName,
      channelDescription: 'Уведомления о новых сообщениях',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'reply',
          'Ответить',
          showsUserInterface: true,
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(label: 'Введите сообщение'),
          ],
        ),
        AndroidNotificationAction(
          'mark_read',
          'Прочитано',
        ),
      ],
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
      chatId.hashCode,
      senderName,
      messageText,
      notificationDetails,
      payload: 'message:$chatId',
    );
  }

  // === УВЕДОМЛЕНИЯ О ЗВОНКАХ ===

  Future<void> _showIncomingCallNotification({
    required String callId,
    required String callerName,
    required String callType,
    String? callerAvatar,
  }) async {
    final isVideo = callType == 'video';

    final androidDetails = AndroidNotificationDetails(
      _callChannelId,
      _callChannelName,
      channelDescription: 'Уведомления о входящих звонках',
      importance: Importance.max,
      priority: Priority.max,
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept',
          'Принять',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'decline',
          'Отклонить',
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ringtone.caf',
      interruptionLevel: InterruptionLevel.critical,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      callId.hashCode,
      '${isVideo ? 'Видеозвонок' : 'Аудиозвонок'} от $callerName',
      'Входящий ${isVideo ? 'видеозвонок' : 'звонок'}',
      notificationDetails,
      payload: 'call:$callId',
    );
  }

  // Публичный метод для показа уведомления о сообщении
  Future<void> showMessageNotification({
    required String chatId,
    required String senderName,
    required String messageText,
    String? senderAvatar,
  }) async {
    await _showMessageNotification(
      chatId: chatId,
      senderName: senderName,
      messageText: messageText,
      senderAvatar: senderAvatar,
    );
  }

  // Публичный метод для показа уведомления о звонке
  Future<void> showIncomingCallNotification({
    required String callId,
    required String callerName,
    required String callType,
    String? callerAvatar,
  }) async {
    await _showIncomingCallNotification(
      callId: callId,
      callerName: callerName,
      callType: callType,
      callerAvatar: callerAvatar,
    );
  }

  // Отмена уведомления о звонке
  Future<void> cancelCallNotification(String callId) async {
    await _localNotifications.cancel(callId.hashCode);
  }

  // Обработка нажатия на local notification
  void _onLocalNotificationTap(NotificationResponse response) async {
    print('[LocalNotification] Нажатие: ${response.payload}');

    if (response.payload != null) {
      final parts = response.payload!.split(':');
      if (parts.length == 2) {
        final type = parts[0];
        final id = parts[1];

        if (type == 'call') {
          if (response.actionId == 'accept') {
            print('[Action] Принять звонок: $id');
            // TODO: Реализовать логику принятия звонка
          } else if (response.actionId == 'decline') {
            print('[Action] Отклонить звонок: $id');
            // TODO: Реализовать логику отклонения звонка
          } else {
            print('[Action] Открыть экран звонка: $id');
            // TODO: Навигация к экрану звонка
          }
        } else if (type == 'message') {
          if (response.actionId == 'reply') {
            print('[Action] Ответить в чат: $id');
            print('[Action] Текст: ${response.input}');
            // TODO: Отправить сообщение
          } else if (response.actionId == 'mark_read') {
            print('[Action] Пометить прочитанным: $id');
            // TODO: Обновить статус сообщения

            // Уменьшаем счетчик непрочитанных
            if (kIsWeb) {
              TitleNotificationService.instance.decrementUnread();
            }
          } else {
            print('[Action] Открыть чат: $id');
            // TODO: Навигация к чату
          }
        }
      }
    }
  }

  // Получить FCM токен
  String? get fcmToken => _fcmToken;

  // Очистка всех уведомлений
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();

    // Сбрасываем счетчик в заголовке
    if (kIsWeb) {
      TitleNotificationService.instance.clearUnread();
    }
  }
}
