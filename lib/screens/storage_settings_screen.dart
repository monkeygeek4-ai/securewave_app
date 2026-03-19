// lib/screens/storage_settings_screen.dart

import 'package:flutter/material.dart';
import '../services/media_storage_service.dart';
import '../utils/app_colors.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final _mediaStorage = MediaStorageService.instance;
  bool _autoDownload = false;
  int _storageLimit = 5;
  String _storageLimitType = 'gb';
  int _currentStorageSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _autoDownload = await _mediaStorage.getAutoDownload();
      _storageLimit = await _mediaStorage.getStorageLimit();
      _storageLimitType = await _mediaStorage.getStorageLimitType();
      _currentStorageSize = await _mediaStorage.getTotalStorageSize();
    } catch (e) {
      // print('[StorageSettings] ❌ Ошибка загрузки настроек: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  
  Future<void> _checkAndCleanup() async {
    // Проверяем лимит и очищаем при необходимости
    final limitType = await _mediaStorage.getStorageLimitType();
    if (limitType == 'gb') {
      final limitBytes = await _mediaStorage.getStorageLimitBytes();
      final currentSize = await _mediaStorage.getTotalStorageSize();
      
      if (currentSize > limitBytes) {
        await _mediaStorage.cleanupOldFiles();
      }
    }
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Загрузка и хранение'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Автоматическая загрузка
                Card(
                  child: SwitchListTile(
                    title: const Text(
                      'Автоматическая загрузка изображений',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _autoDownload
                          ? 'Изображения автоматически загружаются на устройство'
                          : 'Изображения загружаются только при нажатии',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    value: _autoDownload,
                    onChanged: (value) async {
                      await _mediaStorage.setAutoDownload(value);
                      setState(() {
                        _autoDownload = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                
                // Лимит хранилища
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ограничение места на устройстве',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Использовано: ${_formatBytes(_currentStorageSize)}',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      
                      // Радио-кнопки для выбора типа лимита
                      RadioListTile<String>(
                        title: const Text('3 ГБ'),
                        value: '3',
                        groupValue: _storageLimitType == 'gb' ? _storageLimit.toString() : null,
                        onChanged: (value) async {
                          await _mediaStorage.setStorageLimit(3);
                          await _mediaStorage.setStorageLimitType('gb');
                          setState(() {
                            _storageLimit = 3;
                            _storageLimitType = 'gb';
                          });
                          // Проверяем лимит и очищаем при необходимости
                          await _checkAndCleanup();
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('5 ГБ'),
                        value: '5',
                        groupValue: _storageLimitType == 'gb' ? _storageLimit.toString() : null,
                        onChanged: (value) async {
                          await _mediaStorage.setStorageLimit(5);
                          await _mediaStorage.setStorageLimitType('gb');
                          setState(() {
                            _storageLimit = 5;
                            _storageLimitType = 'gb';
                          });
                          await _checkAndCleanup();
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('10 ГБ'),
                        value: '10',
                        groupValue: _storageLimitType == 'gb' ? _storageLimit.toString() : null,
                        onChanged: (value) async {
                          await _mediaStorage.setStorageLimit(10);
                          await _mediaStorage.setStorageLimitType('gb');
                          setState(() {
                            _storageLimit = 10;
                            _storageLimitType = 'gb';
                          });
                          await _checkAndCleanup();
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Все свободное место'),
                        value: 'unlimited',
                        groupValue: _storageLimitType == 'unlimited' ? 'unlimited' : null,
                        onChanged: (value) async {
                          await _mediaStorage.setStorageLimitType('unlimited');
                          setState(() {
                            _storageLimitType = 'unlimited';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Кнопка очистки
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text(
                      'Очистить все медиафайлы',
                      style: TextStyle(color: Colors.red),
                    ),
                    subtitle: const Text('Удалить все загруженные изображения'),
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Очистить все медиафайлы?'),
                          content: const Text(
                            'Все загруженные изображения будут удалены с устройства. '
                            'Вы сможете загрузить их заново из сообщений.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Очистить'),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirmed == true) {
                        await _mediaStorage.clearAllMedia();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Все медиафайлы удалены'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          await _loadSettings();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

