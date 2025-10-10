// lib/services/notification_handler_service.dart

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class NotificationHandlerService {
  static final NotificationHandlerService _instance =
      NotificationHandlerService._internal();
  factory NotificationHandlerService() => _instance;

  NotificationHandlerService._internal();

  static const platform = MethodChannel('com.securewave.app/notification');

  BuildContext? _context;

  /// Инициализация обработчика уведомлений
  Future<void> initialize(BuildContext context) async {
    _context = context;

    print('[NotificationHandler] ========================================');
    print('[NotificationHandler] 🔔 Инициализация NotificationHandlerService');
    print('[NotificationHandler] ========================================');

    // Настраиваем слушатель для нативных событий
    platform.setMethodCallHandler((call) async {
      print('[NotificationHandler] ========================================');
      print('[NotificationHandler] 📨 Получен вызов: ${call.method}');
      print('[NotificationHandler] ========================================');

      if (call.method == 'onNotificationTap') {
        final data = Map<String, dynamic>.from(call.arguments);
        print('[NotificationHandler] 📦 Данные: $data');
        await _handleNotificationTap(data);
      }
    });

    print('[NotificationHandler] ✅ Слушатель настроен');
    print('[NotificationHandler] ========================================');
  }

  /// Обработка клика по уведомлению
  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final type = data['type'];

    print('[NotificationHandler] ========================================');
    print('[NotificationHandler] 🎯 Обработка клика по уведомлению');
    print('[NotificationHandler] Type: $type');
    print('[NotificationHandler] ========================================');

    if (_context == null) {
      print(
          '[NotificationHandler] ⚠️ Context is null, невозможно открыть экран');
      return;
    }

    switch (type) {
      case 'new_message':
        final chatId = data['chatId'];
        print('[NotificationHandler] 💬 Открываем чат: $chatId');
        // TODO: Навигация к чату
        break;

      case 'incoming_call':
        final callId = data['callId'];
        final callerName = data['callerName'];
        final callType = data['callType'];
        final action = data['action'];

        print('[NotificationHandler] ========================================');
        print('[NotificationHandler] 📞 ОБРАБОТКА ВХОДЯЩЕГО ЗВОНКА');
        print('[NotificationHandler] ========================================');
        print('[NotificationHandler] CallId: $callId');
        print('[NotificationHandler] CallerName: $callerName');
        print('[NotificationHandler] CallType: $callType');
        print('[NotificationHandler] Action: $action');

        if (action == 'accept') {
          print('[NotificationHandler] ✅ Пользователь хочет ПРИНЯТЬ звонок');
          // Здесь нужно открыть CallScreen и автоматически принять звонок
          // TODO: Открыть CallScreen с auto-accept
        } else if (action == 'decline') {
          print('[NotificationHandler] ❌ Пользователь хочет ОТКЛОНИТЬ звонок');
          // TODO: Отклонить звонок через WebRTC Service
        } else {
          print(
              '[NotificationHandler] 📱 Просто открываем приложение для звонка');
          // Звонок должен автоматически показаться через CallOverlay
        }

        print('[NotificationHandler] ========================================');
        break;

      default:
        print('[NotificationHandler] ❓ Неизвестный тип: $type');
    }
  }

  /// Обновление контекста (вызывать при смене экрана)
  void updateContext(BuildContext context) {
    _context = context;
  }
}
