// lib/services/media_storage_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'api_service.dart';

class MediaStorageService {
  static const String _prefAutoDownload = 'media_auto_download';
  static const String _prefStorageLimit = 'media_storage_limit';
  static const String _prefStorageLimitType = 'media_storage_limit_type'; // 'gb' or 'unlimited'
  
  static MediaStorageService? _instance;
  static MediaStorageService get instance {
    _instance ??= MediaStorageService._();
    return _instance!;
  }
  
  MediaStorageService._();
  
  // Получить директорию для хранения медиа
  Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(path.join(appDir.path, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }
  
  // Получить путь к файлу по URL
  String _getFileNameFromUrl(String url) {
    final uri = Uri.parse(url);
    final fileName = path.basename(uri.path);
    if (fileName.isEmpty || !fileName.contains('.')) {
      // Генерируем имя на основе хеша URL
      final hash = md5.convert(utf8.encode(url)).toString();
      return '$hash.jpg';
    }
    return fileName;
  }
  
  // Получить полный путь к сохраненному файлу
  Future<String?> getLocalPath(String imageUrl) async {
    try {
      // Сначала проверяем метаданные
      final prefs = await SharedPreferences.getInstance();
      final urlHash = md5.convert(utf8.encode(imageUrl)).toString();
      final metadataKey = 'media_metadata_$urlHash';
      final metadataJson = prefs.getString(metadataKey);
      
      if (metadataJson != null) {
        try {
          final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
          final filePath = metadata['path'] as String?;
          final savedUrl = metadata['url'] as String?;
          
          // print('[MediaStorage] 🔍 Найдены метаданные для: $imageUrl');
          // print('[MediaStorage]    Сохраненный URL: $savedUrl');
          // print('[MediaStorage]    Путь: $filePath');
          
          if (filePath != null) {
            final file = File(filePath);
            if (await file.exists()) {
              // print('[MediaStorage] ✅ Файл существует: $filePath');
              return filePath;
            } else {
              // print('[MediaStorage] ⚠️ Файл не существует по сохраненному пути: $filePath');
              // Файл не найден по сохраненному пути (возможно, изменился Application ID)
              // Ищем файл в текущей директории по имени
              final mediaDir = await _getMediaDirectory();
              final fileName = path.basename(filePath);
              final currentPath = path.join(mediaDir.path, fileName);
              final currentFile = File(currentPath);
              if (await currentFile.exists()) {
                // print('[MediaStorage] ✅ Файл найден в текущей директории: $currentPath');
                // Обновляем метаданные с новым путем
                await _saveMetadata(imageUrl, currentPath, await currentFile.length());
                return currentPath;
              }
            }
          }
        } catch (e) {
          // print('[MediaStorage] ⚠️ Ошибка чтения метаданных: $e');
        }
      } else {
        // print('[MediaStorage] ⚠️ Метаданные не найдены для ключа: $metadataKey');
      }
      
      // Fallback: ищем по имени файла из URL
      final mediaDir = await _getMediaDirectory();
      final fileName = _getFileNameFromUrl(imageUrl);
      final filePath = path.join(mediaDir.path, fileName);
      final file = File(filePath);
      
      if (await file.exists()) {
        // print('[MediaStorage] ✅ Файл найден по имени: $filePath');
        // Обновляем метаданные с актуальным путем
        await _saveMetadata(imageUrl, filePath, await file.length());
        return filePath;
      }
      
      // Если файл не найден по имени из URL, ищем все файлы в директории
      // и проверяем метаданные каждого файла
      try {
        final files = mediaDir.listSync();
        for (final entity in files) {
          if (entity is File) {
            final entityFileName = path.basename(entity.path);
            // Проверяем метаданные этого файла
            final entityMetadataKey = 'media_metadata_${md5.convert(utf8.encode(entityFileName)).toString()}';
            final entityMetadataJson = prefs.getString(entityMetadataKey);
            
            // Или проверяем по URL из метаданных
            if (entityMetadataJson != null) {
              try {
                final entityMetadata = jsonDecode(entityMetadataJson) as Map<String, dynamic>;
                final entityUrl = entityMetadata['url'] as String?;
                if (entityUrl == imageUrl) {
                  // print('[MediaStorage] ✅ Файл найден по метаданным: ${entity.path}');
                  // Обновляем метаданные с актуальным путем
                  await _saveMetadata(imageUrl, entity.path, await entity.length());
                  return entity.path;
                }
              } catch (e) {
                // Пропускаем ошибки
              }
            }
          }
        }
      } catch (e) {
        // print('[MediaStorage] ⚠️ Ошибка поиска файлов в директории: $e');
      }
      
      // print('[MediaStorage] ❌ Файл не найден: $filePath');
      return null;
    } catch (e) {
      // print('[MediaStorage] ❌ Ошибка получения пути: $e');
      return null;
    }
  }
  
  // Проверить, загружен ли файл локально
  Future<bool> isDownloaded(String imageUrl) async {
    try {
      final localPath = await getLocalPath(imageUrl);
      final result = localPath != null;
      if (result) {
        // print('[MediaStorage] ✅ Файл найден локально: $imageUrl -> $localPath');
      } else {
        // print('[MediaStorage] ❌ Файл не найден локально: $imageUrl');
      }
      return result;
    } catch (e) {
      // print('[MediaStorage] ❌ Ошибка проверки isDownloaded: $e');
      return false;
    }
  }
  
  // Скачать и сохранить изображение
  Future<bool> downloadImage(String imageUrl, {String? fileName}) async {
    try {
      // print('[MediaStorage] 📥 Скачивание: $imageUrl');
      
      // Проверяем, не загружено ли уже
      if (await isDownloaded(imageUrl)) {
        // print('[MediaStorage] ✅ Файл уже загружен');
        return true;
      }
      
      // Проверяем лимит хранилища
      if (!await _checkStorageLimit()) {
        // print('[MediaStorage] ⚠️ Достигнут лимит хранилища, очищаем старые файлы');
        await cleanupOldFiles();
        // Проверяем снова после очистки
        if (!await _checkStorageLimit()) {
          // print('[MediaStorage] ❌ Недостаточно места даже после очистки');
          return false;
        }
      }
      
      // Формируем полный URL
      String fullUrl = imageUrl;
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
        fullUrl = '$baseUrl$imageUrl';
      }
      
      // Скачиваем файл
      final dio = Dio();
      final response = await dio.get(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      if (response.statusCode == 200) {
        final bytes = Uint8List.fromList(response.data as List<int>);
        final mediaDir = await _getMediaDirectory();
        final finalFileName = fileName ?? _getFileNameFromUrl(imageUrl);
        final filePath = path.join(mediaDir.path, finalFileName);
        
        // Сохраняем файл
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        
        // Сохраняем метаданные (URL -> путь)
        await _saveMetadata(imageUrl, filePath, bytes.length);
        
        // print('[MediaStorage] ✅ Файл сохранен: $filePath (${bytes.length} bytes)');
        return true;
      } else {
        throw Exception('Ошибка скачивания: ${response.statusCode}');
      }
    } catch (e) {
      // print('[MediaStorage] ❌ Ошибка скачивания: $e');
      return false;
    }
  }
  
  // Сохранить метаданные файла
  Future<void> _saveMetadata(String url, String filePath, int fileSize) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadataKey = 'media_metadata_${md5.convert(utf8.encode(url)).toString()}';
      await prefs.setString(metadataKey, jsonEncode({
        'url': url,
        'path': filePath,
        'size': fileSize,
        'downloadedAt': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      // print('[MediaStorage] ⚠️ Ошибка сохранения метаданных: $e');
    }
  }
  
  // Получить размер всех сохраненных медиафайлов
  Future<int> getTotalStorageSize() async {
    try {
      final mediaDir = await _getMediaDirectory();
      int totalSize = 0;
      
      await for (final entity in mediaDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      // print('[MediaStorage] ❌ Ошибка подсчета размера: $e');
      return 0;
    }
  }
  
  // Проверить лимит хранилища
  Future<bool> _checkStorageLimit() async {
    final limitType = await getStorageLimitType();
    if (limitType == 'unlimited') {
      return true;
    }
    
    final limitBytes = await getStorageLimitBytes();
    final currentSize = await getTotalStorageSize();
    
    return currentSize < limitBytes;
  }
  
  // Очистить старые файлы
  Future<void> cleanupOldFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Получаем все метаданные
      final allKeys = prefs.getKeys().where((key) => key.startsWith('media_metadata_'));
      final files = <Map<String, dynamic>>[];
      
      for (final key in allKeys) {
        final metadataJson = prefs.getString(key);
        if (metadataJson != null) {
          try {
            final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
            files.add(metadata);
          } catch (e) {
            // Удаляем невалидные метаданные
            await prefs.remove(key);
          }
        }
      }
      
      // Сортируем по дате загрузки (старые первыми)
      files.sort((a, b) {
        final dateA = DateTime.parse(a['downloadedAt'] as String);
        final dateB = DateTime.parse(b['downloadedAt'] as String);
        return dateA.compareTo(dateB);
      });
      
      // Удаляем старые файлы пока не освободим место
      final limitBytes = await getStorageLimitBytes();
      var currentSize = await getTotalStorageSize();
      
      for (final fileData in files) {
        if (currentSize < limitBytes) break;
        
        final filePath = fileData['path'] as String;
        final file = File(filePath);
        
        if (await file.exists()) {
          final fileSize = await file.length();
          await file.delete();
          currentSize -= fileSize;
          
          // Удаляем метаданные
          final url = fileData['url'] as String;
          final metadataKey = 'media_metadata_${md5.convert(utf8.encode(url)).toString()}';
          await prefs.remove(metadataKey);
          
          // print('[MediaStorage] 🗑️ Удален старый файл: $filePath');
        }
      }
    } catch (e) {
      // print('[MediaStorage] ❌ Ошибка очистки: $e');
    }
  }
  
  // Настройки автозагрузки
  Future<bool> getAutoDownload() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefAutoDownload) ?? true; // По умолчанию включено
  }
  
  Future<void> setAutoDownload(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefAutoDownload, value);
  }
  
  // Настройки лимита хранилища
  Future<String> getStorageLimitType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefStorageLimitType) ?? 'gb';
  }
  
  Future<void> setStorageLimitType(String type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefStorageLimitType, type);
  }
  
  Future<int> getStorageLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefStorageLimit) ?? 5; // По умолчанию 5 ГБ
  }
  
  Future<void> setStorageLimit(int gb) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefStorageLimit, gb);
  }
  
  Future<int> getStorageLimitBytes() async {
    final limitType = await getStorageLimitType();
    if (limitType == 'unlimited') {
      return 0; // 0 означает без ограничений
    }
    
    final limitGB = await getStorageLimit();
    return limitGB * 1024 * 1024 * 1024; // Конвертируем ГБ в байты
  }
  
  // Удалить файл
  Future<void> deleteFile(String imageUrl) async {
    try {
      final localPath = await getLocalPath(imageUrl);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          
          // Удаляем метаданные
          final prefs = await SharedPreferences.getInstance();
          final metadataKey = 'media_metadata_${md5.convert(utf8.encode(imageUrl)).toString()}';
          await prefs.remove(metadataKey);
          
          // print('[MediaStorage] 🗑️ Файл удален: $localPath');
        }
      }
    } catch (e) {
      // print('[MediaStorage] ❌ Ошибка удаления файла: $e');
    }
  }
  
  // Очистить все медиафайлы
  Future<void> clearAllMedia() async {
    try {
      final mediaDir = await _getMediaDirectory();
      await for (final entity in mediaDir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
      
      // Удаляем все метаданные
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().where((key) => key.startsWith('media_metadata_'));
      for (final key in allKeys) {
        await prefs.remove(key);
      }
      
      // print('[MediaStorage] 🗑️ Все медиафайлы удалены');
    } catch (e) {
      // print('[MediaStorage] ❌ Ошибка очистки: $e');
    }
  }
}

