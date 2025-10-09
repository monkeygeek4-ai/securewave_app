// lib/services/title_notification_service.dart

import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class TitleNotificationService {
  static final TitleNotificationService instance = TitleNotificationService._();
  TitleNotificationService._();

  Timer? _blinkTimer;
  int _unreadCount = 0;
  String _originalTitle = 'SecureWave';
  bool _isBlinking = false;
  bool _showingNotification = false;

  /// Инициализация сервиса
  void initialize() {
    if (kIsWeb) {
      _originalTitle = html.document.title ?? 'SecureWave';
      print(
          '[TitleNotification] Инициализирован. Оригинальный заголовок: $_originalTitle');
    }
  }

  /// Увеличить счетчик непрочитанных и начать мигание
  void incrementUnread({String? message}) {
    if (!kIsWeb) return;

    _unreadCount++;
    _updateTitle();
    _startBlinking(message);

    print('[TitleNotification] Непрочитанных: $_unreadCount');
  }

  /// Уменьшить счетчик непрочитанных
  void decrementUnread() {
    if (!kIsWeb || _unreadCount <= 0) return;

    _unreadCount--;
    _updateTitle();

    if (_unreadCount == 0) {
      _stopBlinking();
    }

    print('[TitleNotification] Непрочитанных: $_unreadCount');
  }

  /// Установить точное количество непрочитанных
  void setUnreadCount(int count) {
    if (!kIsWeb) return;

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
    if (!kIsWeb) return;

    _unreadCount = 0;
    _stopBlinking();
    _updateTitle();

    print('[TitleNotification] Все сообщения прочитаны');
  }

  /// Обновить заголовок страницы
  void _updateTitle() {
    if (!kIsWeb) return;

    if (_unreadCount > 0) {
      html.document.title = '($_unreadCount) $_originalTitle';
    } else {
      html.document.title = _originalTitle;
    }
  }

  /// Начать мигание заголовка
  void _startBlinking([String? message]) {
    if (!kIsWeb || _isBlinking) return;

    _isBlinking = true;
    final notificationText = message ?? 'Новое сообщение!';

    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (!kIsWeb) {
        timer.cancel();
        return;
      }

      _showingNotification = !_showingNotification;

      if (_showingNotification) {
        // Показываем уведомление
        html.document.title = '🔔 $notificationText';
      } else {
        // Показываем счетчик
        if (_unreadCount > 0) {
          html.document.title = '($_unreadCount) $_originalTitle';
        } else {
          html.document.title = _originalTitle;
        }
      }
    });

    print('[TitleNotification] Мигание начато');
  }

  /// Остановить мигание заголовка
  void _stopBlinking() {
    if (!kIsWeb) return;

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

    print('[TitleNotification] Мигание остановлено');
  }

  /// Временно показать уведомление (например, при новом сообщении)
  void showTemporaryNotification(String text,
      {Duration duration = const Duration(seconds: 5)}) {
    if (!kIsWeb) return;

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
    if (kIsWeb) {
      html.document.title = _originalTitle;
    }
  }

  /// Получить текущий счетчик
  int get unreadCount => _unreadCount;

  /// Проверка активности мигания
  bool get isBlinking => _isBlinking;
}
