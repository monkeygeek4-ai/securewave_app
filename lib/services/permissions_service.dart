// lib/services/permissions_service.dart

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class PermissionsService {
  static const String _prefFirstLaunch = 'first_launch_completed';

  // Проверка, был ли первый запуск
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_prefFirstLaunch);
    return completed != true; // true если первый запуск (completed == null или false)
  }

  // Отметить, что первый запуск завершен
  static Future<void> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefFirstLaunch, true);
  }

  // Получить список всех необходимых разрешений
  static List<Permission> getRequiredPermissions() {
    if (Platform.isAndroid) {
      return [
        Permission.camera,
        Permission.photos,
        Permission.storage,
        Permission.notification,
        Permission.microphone,
      ];
    } else if (Platform.isIOS) {
      return [
        Permission.camera,
        Permission.photos,
        Permission.photosAddOnly, // Для сохранения фото
        Permission.notification,
        Permission.microphone,
      ];
    }
    return [];
  }

  // Проверить статус всех разрешений
  static Future<Map<Permission, PermissionStatus>> checkAllPermissions() async {
    final permissions = getRequiredPermissions();
    final statuses = <Permission, PermissionStatus>{};

    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }

    return statuses;
  }

  // Запросить все разрешения
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final permissions = getRequiredPermissions();
    final statuses = <Permission, PermissionStatus>{};

    // print('[Permissions] 📱 Запрос разрешений...');
    // print('[Permissions] Количество разрешений: ${permissions.length}');

    for (final permission in permissions) {
      try {
        final status = await permission.request();
        statuses[permission] = status;
        // print('[Permissions] ${permission.toString()}: $status');
      } catch (e) {
        // print('[Permissions] ❌ Ошибка запроса ${permission.toString()}: $e');
        statuses[permission] = PermissionStatus.denied;
      }
    }

    return statuses;
  }

  // Получить статус конкретного разрешения
  static Future<PermissionStatus> getPermissionStatus(Permission permission) async {
    return await permission.status;
  }

  // Запросить конкретное разрешение
  static Future<PermissionStatus> requestPermission(Permission permission) async {
    return await permission.request();
  }

  // Открыть настройки приложения
  static Future<bool> openSystemSettings() async {
    return await openAppSettings();
  }

  // Получить список разрешений, которые нужно запросить
  static Future<List<Permission>> getDeniedPermissions() async {
    final permissions = getRequiredPermissions();
    final denied = <Permission>[];

    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isDenied || status.isLimited) {
        denied.add(permission);
      }
    }

    return denied;
  }

  // Получить человекочитаемое название разрешения
  static String getPermissionName(Permission permission) {
    if (Platform.isAndroid) {
      switch (permission) {
        case Permission.camera:
          return 'Камера';
        case Permission.photos:
          return 'Фотографии';
        case Permission.storage:
          return 'Хранилище';
        case Permission.notification:
          return 'Уведомления';
        case Permission.microphone:
          return 'Микрофон';
        default:
          return permission.toString();
      }
    } else if (Platform.isIOS) {
      switch (permission) {
        case Permission.camera:
          return 'Камера';
        case Permission.photos:
          return 'Фотографии';
        case Permission.photosAddOnly:
          return 'Сохранение фото';
        case Permission.notification:
          return 'Уведомления';
        case Permission.microphone:
          return 'Микрофон';
        default:
          return permission.toString();
      }
    }
    return permission.toString();
  }

  // Получить описание разрешения
  static String getPermissionDescription(Permission permission) {
    if (Platform.isAndroid) {
      switch (permission) {
        case Permission.camera:
          return 'Для съемки фото и видео';
        case Permission.photos:
          return 'Для выбора фото из галереи';
        case Permission.storage:
          return 'Для сохранения файлов на устройство';
        case Permission.notification:
          return 'Для получения уведомлений о сообщениях и звонках';
        case Permission.microphone:
          return 'Для голосовых и видеозвонков';
        default:
          return '';
      }
    } else if (Platform.isIOS) {
      switch (permission) {
        case Permission.camera:
          return 'Для съемки фото и видео';
        case Permission.photos:
          return 'Для выбора фото из галереи';
        case Permission.photosAddOnly:
          return 'Для сохранения фото в галерею';
        case Permission.notification:
          return 'Для получения уведомлений о сообщениях и звонках';
        case Permission.microphone:
          return 'Для голосовых и видеозвонков';
        default:
          return '';
      }
    }
    return '';
  }
}

