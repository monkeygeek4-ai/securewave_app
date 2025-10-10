// lib/services/title_notification_service_web.dart

import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Веб-реализация сервиса уведомлений в заголовке браузера
class TitleNotificationServiceImpl {
  Timer? _blinkTimer;
  int _unreadCount = 0;
  String _originalTitle = 'SecureWave';
  bool _isBlinking = false;
  bool _showingNotification = false;

  /// Инициализация сервиса
  void initialize() {
    _originalTitle = html.document.title ?? 'SecureWave';
    print('[TitleNotification] ========================================');
    print('[TitleNotification] Инициализирован');
    print('[TitleNotification] Оригинальный заголовок: $_originalTitle');
    print('[TitleNotification] ========================================');
  }

  /// Увеличить счетчик непрочитанных и начать мигание
  void incrementUnread({String? message}) {
    _unreadCount++;
    _updateTitle();
    _startBlinking(message);

    print('[TitleNotification] ========================================');
    print('[TitleNotification] ✅ incrementUnread вызван');
    print('[TitleNotification] Непрочитанных: $_unreadCount');
    print('[TitleNotification] Сообщение: $message');
    print('[TitleNotification] ========================================');
  }

  /// Уменьшить счетчик непрочитанных
  void decrementUnread() {
    if (_unreadCount <= 0) return;

    _unreadCount--;
    _updateTitle();

    if (_unreadCount == 0) {
      _stopBlinking();
    }

    print('[TitleNotification] Непрочитанных: $_unreadCount');
  }

  /// Установить точное количество непрочитанных
  void setUnreadCount(int count) {
    _unreadCount = count;
    _updateTitle();

    if (_unreadCount > 0) {
      _startBlinking();
    } else {
      _stopBlinking();
    }

    print('[TitleNotification] Установлено непрочитанных: $_unreadCount');
  }

  /// Сбросить счетчик (когда пользователь просмотрел все сообщения)
  void clearUnread() {
    print('[TitleNotification] ========================================');
    print('[TitleNotification] 🔴 clearUnread вызван');
    print('[TitleNotification] Текущий счетчик: $_unreadCount');

    // Показываем stack trace только если счетчик > 0
    if (_unreadCount > 0) {
      print('[TitleNotification] Stack trace:');
      print(StackTrace.current);
    }

    print('[TitleNotification] ========================================');

    _unreadCount = 0;
    _stopBlinking();
    _updateTitle();

    print('[TitleNotification] Все сообщения прочитаны');
  }

  /// Обновить заголовок страницы
  void _updateTitle() {
    if (_unreadCount > 0) {
      html.document.title = '($_unreadCount) $_originalTitle';
    } else {
      html.document.title = _originalTitle;
    }
  }

  /// Обновить оригинальный заголовок
  void updateTitle(String title) {
    _originalTitle = title;
    if (!_isBlinking) {
      _updateTitle();
    }
  }

  /// Сбросить к оригинальному заголовку
  void resetTitle() {
    _stopBlinking();
    html.document.title = _originalTitle;
  }

  /// Начать мигание заголовка
  void _startBlinking([String? message]) {
    if (_isBlinking) {
      print('[TitleNotification] ⚠️ Мигание уже активно, пропускаем');
      return;
    }

    _isBlinking = true;
    final notificationText = message ?? 'Новое сообщение!';

    print('[TitleNotification] ========================================');
    print('[TitleNotification] ✨ Начинаем мигание');
    print('[TitleNotification] Текст: $notificationText');
    print('[TitleNotification] ========================================');

    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _showingNotification = !_showingNotification;

      if (_showingNotification) {
        // Показываем уведомление
        html.document.title = '🔔 $notificationText';
        print('[TitleNotification] 💫 Показываем: 🔔 $notificationText');
      } else {
        // Показываем счетчик
        if (_unreadCount > 0) {
          html.document.title = '($_unreadCount) $_originalTitle';
          print(
              '[TitleNotification] 💫 Показываем: ($_unreadCount) $_originalTitle');
        } else {
          html.document.title = _originalTitle;
          print('[TitleNotification] 💫 Показываем: $_originalTitle');
        }
      }
    });

    print('[TitleNotification] Мигание начато');
  }

  /// Остановить мигание заголовка
  void _stopBlinking() {
    if (!_isBlinking) return;

    _isBlinking = false;
    _showingNotification = false;
    _blinkTimer?.cancel();
    _blinkTimer = null;

    // Восстанавливаем нормальный заголовок
    if (_unreadCount > 0) {
      html.document.title = '($_unreadCount) $_originalTitle';
    } else {
      html.document.title = _originalTitle;
    }

    print('[TitleNotification] ⏹️ Мигание остановлено');
  }

  /// Временно показать уведомление (например, при новом сообщении)
  void showTemporaryNotification(String text, {Duration? duration}) {
    duration ??= const Duration(seconds: 5);

    final wasBlinking = _isBlinking;

    // Останавливаем текущее мигание
    _stopBlinking();

    // Показываем временное уведомление
    html.document.title = '🔔 $text';

    // Через указанное время возвращаем обычное состояние
    Timer(duration, () {
      if (wasBlinking && _unreadCount > 0) {
        _startBlinking();
      } else {
        _updateTitle();
      }
    });
  }

  /// Очистка ресурсов
  void dispose() {
    _blinkTimer?.cancel();
    html.document.title = _originalTitle;
  }

  /// Получить текущий счетчик
  int get unreadCount => _unreadCount;

  /// Проверка активности мигания
  bool get isBlinking => _isBlinking;
}
