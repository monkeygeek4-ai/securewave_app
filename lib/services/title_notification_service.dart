// lib/services/title_notification_service.dart

import 'package:flutter/foundation.dart';

// Условный импорт - выбирает нужную реализацию в зависимости от платформы
import 'title_notification_service_stub.dart'
    if (dart.library.html) 'title_notification_service_web.dart';

class TitleNotificationService {
  static final TitleNotificationService instance = TitleNotificationService._();
  TitleNotificationService._() {
    _impl = TitleNotificationServiceImpl();
  }

  late final TitleNotificationServiceImpl _impl;

  /// Инициализация сервиса
  void initialize() {
    _impl.initialize();
  }

  /// Увеличить счетчик непрочитанных и начать мигание
  void incrementUnread({String? message}) {
    _impl.incrementUnread(message: message);
  }

  /// Уменьшить счетчик непрочитанных
  void decrementUnread() {
    _impl.decrementUnread();
  }

  /// Установить точное количество непрочитанных
  void setUnreadCount(int count) {
    _impl.setUnreadCount(count);
  }

  /// Обновить счетчик непрочитанных (алиас для совместимости)
  void updateUnreadCount(int count) {
    setUnreadCount(count);
  }

  /// Сбросить счетчик (когда пользователь просмотрел все сообщения)
  void clearUnread() {
    _impl.clearUnread();
  }

  /// Показать уведомление в заголовке
  void showNotification(String text) {
    _impl.showTemporaryNotification(text);
  }

  /// Временно показать уведомление (например, при новом сообщении)
  void showTemporaryNotification(String text, {Duration? duration}) {
    _impl.showTemporaryNotification(
      text,
      duration: duration ?? const Duration(seconds: 5),
    );
  }

  /// Обновить заголовок страницы
  void updateTitle(String title) {
    _impl.updateTitle(title);
  }

  /// Очистить все уведомления
  void clearNotifications() {
    _impl.clearUnread();
  }

  /// Сбросить заголовок к исходному
  void resetTitle() {
    _impl.resetTitle();
  }

  /// Очистка ресурсов
  void dispose() {
    _impl.dispose();
  }

  /// Получить текущий счетчик
  int get unreadCount => _impl.unreadCount;

  /// Проверка активности мигания
  bool get isBlinking => _impl.isBlinking;
}
