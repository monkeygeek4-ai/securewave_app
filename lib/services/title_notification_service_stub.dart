// lib/services/title_notification_service_stub.dart

/// Заглушка для мобильных платформ (Android/iOS)
/// Все методы пустые, т.к. на мобильных устройствах нет заголовка браузера
class TitleNotificationServiceImpl {
  int _unreadCount = 0;
  bool _isBlinking = false;

  void initialize() {
    // Ничего не делаем на мобильных платформах
  }

  void incrementUnread({String? message}) {
    _unreadCount++;
    // Ничего не делаем на мобильных платформах
  }

  void decrementUnread() {
    if (_unreadCount > 0) _unreadCount--;
    // Ничего не делаем на мобильных платформах
  }

  void setUnreadCount(int count) {
    _unreadCount = count;
    // Ничего не делаем на мобильных платформах
  }

  void clearUnread() {
    _unreadCount = 0;
    _isBlinking = false;
    // Ничего не делаем на мобильных платформах
  }

  void showTemporaryNotification(String text, {Duration? duration}) {
    // Ничего не делаем на мобильных платформах
  }

  void updateTitle(String title) {
    // Ничего не делаем на мобильных платформах
  }

  void resetTitle() {
    // Ничего не делаем на мобильных платформах
  }

  void dispose() {
    // Ничего не делаем на мобильных платформах
  }

  int get unreadCount => _unreadCount;
  bool get isBlinking => _isBlinking;
}
