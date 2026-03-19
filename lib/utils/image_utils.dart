// lib/utils/image_utils.dart

/// Утилита для работы с изображениями (аватары)
class ImageUtils {
  // Базовый URL сервера
  static const String baseServerUrl = 'https://securewave.sbk-19.ru';
  
  // Путь к папке с аватарами на сервере
  static const String avatarsPath = '/backend/uploads/avatars';

  /// Формирует полный URL для аватара
  /// 
  /// Если avatarPath уже содержит полный URL (начинается с http:// или https://),
  /// возвращает его как есть.
  /// Если avatarPath - относительный путь, добавляет базовый URL сервера.
  /// Если avatarPath null или пустой, возвращает null.
  static String? getAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return null;
    }

    // Если уже полный URL, возвращаем как есть
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return avatarPath;
    }

    // Если путь начинается с /, используем его напрямую
    if (avatarPath.startsWith('/')) {
      return '$baseServerUrl$avatarPath';
    }

    // Иначе добавляем путь к папке аватаров
    return '$baseServerUrl$avatarsPath/$avatarPath';
  }

  /// Проверяет, является ли строка валидным URL изображения
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    return url.startsWith('http://') || url.startsWith('https://');
  }
}

