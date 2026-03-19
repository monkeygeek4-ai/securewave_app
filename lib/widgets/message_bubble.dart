// lib/widgets/message_bubble.dart

import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';
import '../utils/app_colors.dart';
import '../utils/image_utils.dart';
import '../services/api_service.dart';
import '../services/media_storage_service.dart';
import 'image_viewer.dart';
import 'multi_image_viewer.dart';
import 'voice_message_bubble.dart';
import 'media_viewer.dart';
import 'report_dialog.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final Function(bool deleteForEveryone)? onDelete;
  final String? currentUserId; // ⭐ НОВОЕ: ID текущего пользователя для определения статуса звонка
  final List<Message>? allMessages; // ⭐ НОВОЕ: Все сообщения чата для сбора медиа

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onDelete,
    this.currentUserId, // ⭐ НОВОЕ: Опциональный параметр
    this.allMessages, // ⭐ НОВОЕ: Опциональный параметр
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool? _isDownloaded;
  bool _isDownloading = false;
  bool _isChecking = false; // Флаг для предотвращения одновременных проверок
  Timer? _statusCheckTimer;
  String? _localPath;
  bool? _autoDownload; // Кэшированное значение настройки автозагрузки

  @override
  void initState() {
    super.initState();
    // Загружаем настройку автозагрузки сразу
    _loadAutoDownloadSetting();
    _checkDownloadStatus();
    // Периодически проверяем статус загрузки (для автоматической загрузки)
    // Только если файл еще не загружен
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted &&
          _isDownloaded == false &&
          !_isDownloading &&
          !_isChecking) {
        _checkDownloadStatus();
      } else if (mounted && _isDownloaded == true) {
        // Останавливаем таймер, если файл уже загружен
        _statusCheckTimer?.cancel();
        _statusCheckTimer = null;
      }
    });
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // НЕ проверяем повторно, если сообщение не изменилось
    // Проверка уже выполнена в initState
    // Проверяем только если сообщение действительно изменилось (новое сообщение)
    if (oldWidget.message.id != widget.message.id &&
        _isDownloaded == null &&
        !_isChecking) {
      _checkDownloadStatus();
    }
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  // Загрузить настройку автозагрузки
  Future<void> _loadAutoDownloadSetting() async {
    try {
      final autoDownload = await MediaStorageService.instance.getAutoDownload();
      if (mounted) {
        setState(() {
          _autoDownload = autoDownload;
          // Если автозагрузка выключена, сразу устанавливаем _isDownloaded = false
          // чтобы показать размытое превью
          if (!autoDownload && _isDownloaded == null) {
            _isDownloaded = false;
          }
        });
      }
    } catch (e) {
      // print('[MessageBubble] Ошибка загрузки настройки автозагрузки: $e');
      if (mounted) {
        setState(() {
          _autoDownload = false; // По умолчанию выключено
          // Устанавливаем _isDownloaded = false, чтобы показать размытое превью
          if (_isDownloaded == null) {
            _isDownloaded = false;
          }
        });
      }
    }
  }

  Future<void> _checkDownloadStatus() async {
    // Предотвращаем одновременные проверки
    if (_isChecking) {
      return;
    }

    if (widget.message.type != 'image' && widget.message.type != 'video') {
      return;
    }

    final metadata = widget.message.metadata ?? {};
    final imageUrl = metadata['fileUrl'] ??
        metadata['mediaUrl'] ??
        widget.message.mediaUrl ??
        '';

    if (imageUrl.isEmpty) {
      return;
    }

    // Проверяем статус загрузки и получаем локальный путь
    // Только если еще не определено или файл не загружен
    if (_isDownloaded == null || _isDownloaded == false) {
      _isChecking = true;
      try {
        final isDownloaded =
            await MediaStorageService.instance.isDownloaded(imageUrl);
        final localPath = isDownloaded
            ? await MediaStorageService.instance.getLocalPath(imageUrl)
            : null;

        if (mounted) {
          setState(() {
            _isDownloaded = isDownloaded;
            _localPath = localPath;
            _isChecking = false;
            // Останавливаем таймер, если файл загружен
            if (isDownloaded && _statusCheckTimer != null) {
              _statusCheckTimer?.cancel();
              _statusCheckTimer = null;
            }
          });
        } else {
          _isChecking = false;
        }
      } catch (e) {
        _isChecking = false;
        // print('[MessageBubble] ❌ Ошибка проверки статуса загрузки: $e');
      }
    }
  }

  // Получаем текст статуса звонка
  String _getCallStatusText() {
    final isVideo = widget.message.callType == 'video';
    
    // ⭐⭐⭐ НОВОЕ: Определяем статус на основе того, является ли текущий пользователь инициатором
    if (widget.message.callInitiatorId != null && widget.currentUserId != null) {
      final isInitiator = widget.message.callInitiatorId == widget.currentUserId;
      final callResult = widget.message.callResult ?? widget.message.callStatus ?? 'completed';
      
      // Если звонок завершен (completed), показываем "Входящий" или "Исходящий" в зависимости от роли
      if (callResult == 'completed') {
        return isInitiator 
            ? (isVideo ? 'Исходящий видеозвонок' : 'Исходящий звонок')
            : (isVideo ? 'Входящий видеозвонок' : 'Входящий звонок');
      } else {
        // Для других результатов
        switch (callResult) {
          case 'missed':
            return isVideo ? 'Пропущенный видеозвонок' : 'Пропущенный звонок';
          case 'rejected':
            return isVideo ? 'Отклоненный видеозвонок' : 'Отклоненный звонок';
          case 'cancelled':
            return isVideo ? 'Отмененный видеозвонок' : 'Отмененный звонок';
          default:
            return isVideo ? 'Видеозвонок' : 'Звонок';
        }
      }
    }
    
    // ⭐ Fallback: используем старую логику для обратной совместимости
    final status = widget.message.callStatus?.toLowerCase() ?? '';

    switch (status) {
      case 'outgoing':
        return isVideo ? 'Исходящий видеозвонок' : 'Исходящий звонок';
      case 'incoming':
        return isVideo ? 'Входящий видеозвонок' : 'Входящий звонок';
      case 'cancelled':
      case 'canceled':
        return isVideo ? 'Отмененный видеозвонок' : 'Отмененный звонок';
      case 'missed':
        return isVideo ? 'Пропущенный видеозвонок' : 'Пропущенный звонок';
      case 'rejected':
      case 'declined':
        return isVideo ? 'Отклоненный видеозвонок' : 'Отклоненный звонок';
      case 'ended':
        return widget.isMe 
            ? (isVideo ? 'Исходящий видеозвонок' : 'Исходящий звонок')
            : (isVideo ? 'Входящий видеозвонок' : 'Входящий звонок');
      default:
        return isVideo ? 'Видеозвонок' : 'Звонок';
    }
  }

  // Получаем иконку для звонка
  IconData _getCallIcon() {
    final isVideo = widget.message.callType == 'video';
    
    // ⭐⭐⭐ НОВОЕ: Определяем иконку на основе того, является ли текущий пользователь инициатором
    if (widget.message.callInitiatorId != null && widget.currentUserId != null) {
      final isInitiator = widget.message.callInitiatorId == widget.currentUserId;
      final callResult = widget.message.callResult ?? widget.message.callStatus ?? 'completed';
      
      if (callResult == 'completed') {
        return isInitiator 
            ? (isVideo ? Icons.videocam : Icons.call_made)
            : (isVideo ? Icons.videocam : Icons.call_received);
      } else if (callResult == 'missed') {
        return isVideo ? Icons.videocam_off : Icons.call_missed;
      } else if (callResult == 'rejected' || callResult == 'cancelled') {
        return isVideo ? Icons.videocam_off : Icons.call_end;
      }
    }
    
    // ⭐ Fallback: используем старую логику для обратной совместимости
    final status = widget.message.callStatus?.toLowerCase() ?? '';

    switch (status) {
      case 'ended':
        return Icons.check_circle;
      case 'cancelled':
      case 'canceled':
      case 'missed':
        return Icons.phone_missed;
      case 'declined':
        return Icons.cancel;
      default:
        return isVideo ? Icons.videocam : Icons.call;
    }
  }

  // Получаем цвет для статуса звонка
  Color _getCallStatusColor(BuildContext context) {
    // ⭐⭐⭐ НОВОЕ: Определяем цвет на основе результата звонка
    final callResult = widget.message.callResult ?? widget.message.callStatus ?? 'completed';
    
    switch (callResult) {
      case 'missed':
        return Colors.red;
      case 'rejected':
      case 'cancelled':
        return Colors.orange;
      case 'completed':
        // Для завершенных звонков используем зеленый для входящих и фиолетовый для исходящих
        if (widget.message.callInitiatorId != null && widget.currentUserId != null) {
          final isInitiator = widget.message.callInitiatorId == widget.currentUserId;
          return isInitiator ? AppColors.primaryPurple : Colors.green;
        }
        // Fallback для старых сообщений
        return widget.isMe ? Colors.white : AppColors.primaryPurple;
      default:
        return widget.isMe ? Colors.white : AppColors.primaryPurple;
    }
  }

  // ⭐⭐⭐ НОВОЕ: Собираем все медиа из чата (фото + видео)
  List<MediaItem> _collectAllMedia() {
    if (widget.allMessages == null) {
      // Если нет списка сообщений, возвращаем только медиа текущего сообщения
      return _collectMediaFromMessage(widget.message);
    }

    final List<MediaItem> allMedia = [];
    
    for (final message in widget.allMessages!) {
      if (message.type == 'image' || message.type == 'video') {
        allMedia.addAll(_collectMediaFromMessage(message));
      }
    }
    
    return allMedia;
  }

  // Собираем медиа из одного сообщения
  List<MediaItem> _collectMediaFromMessage(Message message) {
    final List<MediaItem> media = [];
    final metadata = message.metadata ?? {};
    
    // ⭐⭐⭐ ИЗМЕНЕНО: Проверяем объединенный массив media или отдельные массивы images и videos
    final mediaList = metadata['media'] as List<dynamic>?;
    if (mediaList != null && mediaList.isNotEmpty) {
      // Используем объединенный массив media (фото + видео)
      for (final item in mediaList) {
        if (item is Map<String, dynamic>) {
          final url = item['fileUrl'] ?? item['mediaUrl'] ?? '';
          final type = item['type'] as String? ?? 'image';
          final thumbnailUrl = item['thumbnailUrl'] as String?;
          
          if (url.isNotEmpty) {
            media.add(MediaItem(
              url: url,
              type: type == 'video' ? 'video' : 'image',
              thumbnailUrl: thumbnailUrl,
            ));
          }
        } else {
          final url = item.toString();
          if (url.isNotEmpty) {
            media.add(MediaItem(url: url, type: 'image'));
          }
        }
      }
    } else if (message.type == 'image') {
      // Проверяем, есть ли массив изображений
      final imagesList = metadata['images'] as List<dynamic>?;
      
      if (imagesList != null && imagesList.isNotEmpty) {
        // Множественные фото (или фото + видео)
        for (final img in imagesList) {
          if (img is Map<String, dynamic>) {
            final url = img['fileUrl'] ?? img['mediaUrl'] ?? '';
            final type = img['type'] as String? ?? 'image';
            final thumbnailUrl = img['thumbnailUrl'] as String?;
            
            if (url.isNotEmpty) {
              media.add(MediaItem(
                url: url,
                type: type == 'video' ? 'video' : 'image',
                thumbnailUrl: thumbnailUrl,
              ));
            }
          } else {
            final url = img.toString();
            if (url.isNotEmpty) {
              media.add(MediaItem(url: url, type: 'image'));
            }
          }
        }
      } else {
        // Одно фото
        final imageUrl = metadata['fileUrl'] ??
            metadata['mediaUrl'] ??
            message.mediaUrl ??
            '';
        if (imageUrl.isNotEmpty) {
          media.add(MediaItem(url: imageUrl, type: 'image'));
        }
      }
      
      // ⭐⭐⭐ НОВОЕ: Также проверяем массив videos, если сообщение типа 'image' (объединенное медиа)
      final videosList = metadata['videos'] as List<dynamic>?;
      if (videosList != null && videosList.isNotEmpty) {
        for (final vid in videosList) {
          if (vid is Map<String, dynamic>) {
            final url = vid['fileUrl'] ?? vid['mediaUrl'] ?? '';
            final thumbnailUrl = vid['thumbnailUrl'] as String?;
            
            if (url.isNotEmpty) {
              media.add(MediaItem(
                url: url,
                type: 'video',
                thumbnailUrl: thumbnailUrl,
              ));
            }
          } else {
            final url = vid.toString();
            if (url.isNotEmpty) {
              media.add(MediaItem(url: url, type: 'video'));
            }
          }
        }
      }
    } else if (message.type == 'video') {
      // Проверяем, есть ли массив видео (для групповой отправки)
      final videosList = metadata['videos'] as List<dynamic>?;
      
      if (videosList != null && videosList.isNotEmpty) {
        // Множественные видео
        for (final vid in videosList) {
          if (vid is Map<String, dynamic>) {
            final url = vid['fileUrl'] ?? vid['mediaUrl'] ?? '';
            final thumbnailUrl = vid['thumbnailUrl'] as String?;
            
            if (url.isNotEmpty) {
              media.add(MediaItem(
                url: url,
                type: 'video',
                thumbnailUrl: thumbnailUrl,
              ));
            }
          } else {
            final url = vid.toString();
            if (url.isNotEmpty) {
              media.add(MediaItem(url: url, type: 'video'));
            }
          }
        }
      } else {
        // Одно видео
        final videoUrl = metadata['fileUrl'] ??
            metadata['mediaUrl'] ??
            message.mediaUrl ??
            '';
        if (videoUrl.isNotEmpty) {
          final thumbnailUrl = metadata['thumbnailUrl'] as String?;
          media.add(MediaItem(
            url: videoUrl,
            type: 'video',
            thumbnailUrl: thumbnailUrl,
          ));
        }
      }
      
      // ⭐⭐⭐ НОВОЕ: Также проверяем массив images, если сообщение типа 'video' (объединенное медиа)
      final imagesList = metadata['images'] as List<dynamic>?;
      if (imagesList != null && imagesList.isNotEmpty) {
        for (final img in imagesList) {
          if (img is Map<String, dynamic>) {
            final url = img['fileUrl'] ?? img['mediaUrl'] ?? '';
            final type = img['type'] as String? ?? 'image';
            final thumbnailUrl = img['thumbnailUrl'] as String?;
            
            if (url.isNotEmpty) {
              media.add(MediaItem(
                url: url,
                type: type == 'video' ? 'video' : 'image',
                thumbnailUrl: thumbnailUrl,
              ));
            }
          } else {
            final url = img.toString();
            if (url.isNotEmpty) {
              media.add(MediaItem(url: url, type: 'image'));
            }
          }
        }
      }
    }
    
    return media;
  }

  // Находим индекс текущего медиа в общем списке
  int _findCurrentMediaIndex(List<MediaItem> allMedia) {
    final currentMedia = _collectMediaFromMessage(widget.message);
    if (currentMedia.isEmpty || allMedia.isEmpty) return 0;
    
    final currentUrl = currentMedia.first.url;
    for (int i = 0; i < allMedia.length; i++) {
      if (allMedia[i].url == currentUrl) {
        return i;
      }
    }
    
    return 0;
  }

  // Новый метод для контента сообщения
  Widget _buildMessageContent(BuildContext context) {
    if (widget.message.type == 'text') {
      return Text(
        widget.message.content,
        style: TextStyle(
          color: widget.isMe ? Colors.white : AppColors.getTextColor(context),
          fontSize: 15,
          height: 1.4,
        ),
      );
    } else if (widget.message.type == 'call') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCallIcon(),
            size: 20,
            color: _getCallStatusColor(context),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getCallStatusText(),
                style: TextStyle(
                  color: widget.isMe
                      ? Colors.white
                      : AppColors.getTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.message.callDuration != null &&
                  widget.message.callDuration! > 0)
                Text(
                  _formatDuration(widget.message.callDuration!),
                  style: TextStyle(
                    color: widget.isMe
                        ? Colors.white.withOpacity(0.8)
                        : AppColors.getSecondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      );
    } else if (widget.message.type == 'voice') {
      // Голосовые сообщения обрабатываются отдельным виджетом в build()
      return const SizedBox.shrink();
    } else if (widget.message.type == 'image') {
      return _buildImageWidget(context);
    } else if (widget.message.type == 'video') {
      return _buildVideoWidget();
    } else if (widget.message.type == 'file') {
      return _buildFileWidget();
    }
    return const SizedBox.shrink(); // Fallback на случай неподдерживаемого типа
  }

  @override
  Widget build(BuildContext context) {
    // ⭐⭐⭐ НОВОЕ: Для голосовых сообщений используем отдельный виджет
    if (widget.message.type == 'voice') {
      return VoiceMessageBubble(
        message: widget.message,
        isMe: widget.isMe,
      );
    }
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isMe)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.transparent,
                    child: widget.message.senderAvatar != null &&
                            widget.message.senderAvatar!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: ImageUtils.getAvatarUrl(
                                      widget.message.senderAvatar) ??
                                  '',
                              fit: BoxFit.cover,
                              width: 32,
                              height: 32,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                ),
                                child: Center(
                                  child: Text(
                                    widget.message.senderName?.isNotEmpty ==
                                            true
                                        ? widget.message.senderName![0]
                                            .toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                ),
                                child: Center(
                                  child: Text(
                                    widget.message.senderName?.isNotEmpty ==
                                            true
                                        ? widget.message.senderName![0]
                                            .toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Text(
                            widget.message.senderName?.isNotEmpty == true
                                ? widget.message.senderName![0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            Flexible(
              child: GestureDetector(
                onLongPress: () => _showDeleteDialog(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: widget.isMe ? AppColors.primaryGradient : null,
                    color:
                        !widget.isMe ? AppColors.getCardColor(context) : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: widget.isMe
                          ? const Radius.circular(20)
                          : const Radius.circular(4),
                      bottomRight: widget.isMe
                          ? const Radius.circular(4)
                          : const Radius.circular(20),
                    ),
                    boxShadow: [
                      widget.isMe
                          ? AppColors.messageShadow
                          : AppColors.cardShadow,
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.isMe && widget.message.senderName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            widget.message.senderName!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ),
                      _buildMessageContent(context),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.message.isEdited)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.isMe
                                      ? Colors.white.withOpacity(0.2)
                                      : AppColors.primaryPurple
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'изм.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: widget.isMe
                                        ? Colors.white.withOpacity(0.8)
                                        : AppColors.primaryPurple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          Text(
                            _formatTime(widget.message.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.isMe
                                  ? Colors.white.withOpacity(0.9)
                                  : AppColors.getSecondaryTextColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              widget.message.isRead
                                  ? Icons.done_all
                                  : Icons.done,
                              size: 16,
                              color: widget.message.isRead
                                  ? AppColors.online
                                  : Colors.white.withOpacity(0.7),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (e) {
      return '';
    }
  }

  // Форматирование длительности звонка
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  // Отображение файла
  Widget _buildFileWidget() {
    final metadata = widget.message.metadata ?? {};
    final fileName = metadata['fileName'] ?? widget.message.content ?? 'Файл';
    final fileUrl = metadata['fileUrl'] ?? '';
    final fileSize = metadata['fileSize'] ?? 0;
    final fileType = metadata['fileType'] ?? 'application/octet-stream';

    // Определяем иконку по типу файла
    IconData fileIcon = Icons.insert_drive_file;
    if (fileType.startsWith('image/')) {
      fileIcon = Icons.image;
    } else if (fileType.startsWith('video/')) {
      fileIcon = Icons.video_file;
    } else if (fileType.startsWith('audio/')) {
      fileIcon = Icons.audiotrack;
    } else if (fileType == 'application/pdf') {
      fileIcon = Icons.picture_as_pdf;
    } else if (fileType.contains('word') || fileType.contains('document')) {
      fileIcon = Icons.description;
    } else if (fileType.contains('excel') || fileType.contains('spreadsheet')) {
      fileIcon = Icons.table_chart;
    }

    // Форматируем размер файла
    String fileSizeText = _formatFileSize(fileSize);

    return InkWell(
      onTap: fileUrl.isNotEmpty ? () => _openFile(fileUrl) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.2)
              : AppColors.primaryPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isMe
                ? Colors.white.withOpacity(0.3)
                : AppColors.primaryPurple.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.primaryPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                fileIcon,
                size: 24,
                color: widget.isMe ? Colors.white : AppColors.primaryPurple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color:
                          widget.isMe ? Colors.white : AppColors.primaryPurple,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fileSizeText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      fileSizeText,
                      style: TextStyle(
                        color: widget.isMe
                            ? Colors.white70
                            : AppColors.primaryPurple.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download,
              size: 20,
              color: widget.isMe
                  ? Colors.white70
                  : AppColors.primaryPurple.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _openFile(String fileUrl) async {
    try {
      // Формируем полный URL
      final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
      final fullUrl = '$baseUrl$fileUrl';

      // print('[MessageBubble] 📎 Открываем файл: $fullUrl');

      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // print('[MessageBubble] ❌ Не удалось открыть файл: $fullUrl');
      }
    } catch (e) {
      // print('[MessageBubble] ❌ Ошибка открытия файла: $e');
    }
  }

  // Отображение изображения (поддержка множественных фото)
  Widget _buildImageWidget(BuildContext context) {
    final metadata = widget.message.metadata ?? {};

    // Проверяем, есть ли массив изображений
    final imagesList = metadata['images'] as List<dynamic>?;

    if (imagesList != null && imagesList.isNotEmpty) {
      // Множественные фото - показываем сетку
      return _buildMultipleImages(context, imagesList);
    }

    // Одно фото - показываем как раньше
    final imageUrl = metadata['fileUrl'] ??
        metadata['mediaUrl'] ??
        widget.message.mediaUrl ??
        '';

    // Формируем полный URL
    final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
    final fullUrl = imageUrl.isNotEmpty ? '$baseUrl$imageUrl' : '';

    if (fullUrl.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.2)
              : AppColors.primaryPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.broken_image, color: Colors.grey),
      );
    }

    // Используем кэшированный статус, если он уже определен
    if (_isDownloaded == true) {
      return _buildDownloadedImage(context, fullUrl, imageUrl, metadata);
    }

    if (_isDownloaded == false) {
      return _buildBlurredPreview(
          context, fullUrl, imageUrl, metadata, _isDownloading);
    }

    // Если статус еще не определен, используем настройку автозагрузки
    // Если автозагрузка выключена или еще не загружена, показываем размытое превью
    // (по умолчанию считаем, что автозагрузка выключена)
    if (_autoDownload == null || !_autoDownload!) {
      return _buildBlurredPreview(
          context, fullUrl, imageUrl, metadata, _isDownloading);
    }

    // Если автозагрузка включена, показываем изображение с сервера
    // (оно будет автоматически загружено)
    return Container(
      width: 250,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            // Открываем MediaViewer со всеми медиа из чата
            final allMedia = _collectAllMedia();
            final currentIndex = _findCurrentMediaIndex(allMedia);
            
            if (allMedia.isNotEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MediaViewer(
                    mediaItems: allMedia,
                    initialIndex: currentIndex,
                  ),
                ),
              );
            } else {
              // Fallback: открываем ImageViewer
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ImageViewer(
                    imageUrl: imageUrl,
                    fileName: metadata['fileName'] as String?,
                  ),
                ),
              );
            }
          },
          child: SizedBox(
            width: 250,
            height: 200,
            child: CachedNetworkImage(
              imageUrl: fullUrl,
              fit: BoxFit.cover,
              httpHeaders: {
                'Accept': 'image/*',
              },
              placeholder: (context, url) {
                return Container(
                  width: 250,
                  height: 200,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withOpacity(0.1)
                        : AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      color:
                          widget.isMe ? Colors.white : AppColors.primaryPurple,
                    ),
                  ),
                );
              },
              errorWidget: (context, url, error) {
                return Container(
                  width: 250,
                  height: 200,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? Colors.white.withOpacity(0.2)
                        : AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Отображение нескольких изображений и видео в сетке с правильными пропорциями
  Widget _buildMultipleImages(BuildContext context, List<dynamic> imagesList) {
    final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
    final metadata = widget.message.metadata ?? {};
    
    // ⭐⭐⭐ ИЗМЕНЕНО: Собираем все медиа из массива images и videos
    final List<Map<String, dynamic>> mediaItems = [];
    
    // Добавляем фото из массива images
    for (final item in imagesList) {
      if (item is Map<String, dynamic>) {
        final url = item['fileUrl'] ?? item['mediaUrl'] ?? '';
        if (url.isNotEmpty) {
          mediaItems.add({
            'url': url,
            'type': item['type'] ?? 'image',
            'thumbnailUrl': item['thumbnailUrl'],
          });
        }
      } else {
        final url = item.toString();
        if (url.isNotEmpty) {
          mediaItems.add({
            'url': url,
            'type': 'image',
          });
        }
      }
    }
    
    // ⭐⭐⭐ НОВОЕ: Добавляем видео из массива videos, если они есть
    final videosList = metadata['videos'] as List<dynamic>?;
    if (videosList != null && videosList.isNotEmpty) {
      for (final vid in videosList) {
        if (vid is Map<String, dynamic>) {
          final url = vid['fileUrl'] ?? vid['mediaUrl'] ?? '';
          if (url.isNotEmpty) {
            mediaItems.add({
              'url': url,
              'type': 'video',
              'thumbnailUrl': vid['thumbnailUrl'],
            });
          }
        } else {
          final url = vid.toString();
          if (url.isNotEmpty) {
            mediaItems.add({
              'url': url,
              'type': 'video',
            });
          }
        }
      }
    }

    if (mediaItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Определяем размер сетки в зависимости от количества медиа
    int crossAxisCount = 2;
    if (mediaItems.length == 1) {
      crossAxisCount = 1;
    } else if (mediaItems.length <= 4) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return GestureDetector(
      onTap: () {
        // Открываем MediaViewer со всеми медиа из чата
        final allMedia = _collectAllMedia();
        final currentIndex = _findCurrentMediaIndex(allMedia);
        
        if (allMedia.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MediaViewer(
                mediaItems: allMedia,
                initialIndex: currentIndex,
              ),
            ),
          );
        } else {
          // Fallback: открываем MultiImageViewer только для фото
          final imageOnlyItems = mediaItems
              .where((item) => item['type'] == 'image')
              .map((item) => item['url'].toString())
              .toList();
          if (imageOnlyItems.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MultiImageViewer(
                  imageUrls: imageOnlyItems,
                  initialIndex: 0,
                  messageId: widget.message.id,
                ),
              ),
            );
          }
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 1, // Квадратные ячейки
          ),
          itemCount: mediaItems.length > 9 ? 9 : mediaItems.length,
          itemBuilder: (context, index) {
            final mediaItem = mediaItems[index];
            final mediaUrl = mediaItem['url'] as String;
            final mediaType = mediaItem['type'] as String? ?? 'image';
            final thumbnailUrl = mediaItem['thumbnailUrl'] as String?;
            final fullUrl =
                mediaUrl.startsWith('http') ? mediaUrl : '$baseUrl$mediaUrl';
            final thumbnailFullUrl = thumbnailUrl != null
                ? (thumbnailUrl.startsWith('http') ? thumbnailUrl : '$baseUrl$thumbnailUrl')
                : null;

            return GestureDetector(
              onTap: () {
                // Открываем MediaViewer со всеми медиа из чата
                final allMedia = _collectAllMedia();
                // Находим индекс текущего медиа в общем списке
                int mediaIndex = 0;
                for (int i = 0; i < allMedia.length; i++) {
                  if (allMedia[i].url == mediaUrl || 
                      allMedia[i].url.endsWith(mediaUrl) ||
                      mediaUrl.endsWith(allMedia[i].url)) {
                    mediaIndex = i;
                    break;
                  }
                }
                
                if (allMedia.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MediaViewer(
                        mediaItems: allMedia,
                        initialIndex: mediaIndex,
                      ),
                    ),
                  );
                } else {
                  // Fallback: открываем MultiImageViewer только для фото
                  if (mediaType == 'image') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MultiImageViewer(
                          imageUrls: mediaItems
                              .where((item) => item['type'] == 'image')
                              .map((item) => item['url'].toString())
                              .toList(),
                          initialIndex: index,
                          messageId: widget.message.id,
                        ),
                      ),
                    );
                  }
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Превью медиа (фото или превью видео)
                    if (mediaType == 'video' && thumbnailFullUrl != null)
                      CachedNetworkImage(
                        imageUrl: thumbnailFullUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.gradientStart.withOpacity(0.3),
                                AppColors.gradientEnd.withOpacity(0.3),
                              ],
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.gradientStart.withOpacity(0.3),
                                AppColors.gradientEnd.withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: const Icon(Icons.videocam, color: Colors.white, size: 32),
                        ),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: fullUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.1)
                              : AppColors.primaryPurple.withOpacity(0.1),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: widget.isMe
                                  ? Colors.white
                                  : AppColors.primaryPurple,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.1)
                              : AppColors.primaryPurple.withOpacity(0.1),
                          child:
                              const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    // Иконка воспроизведения для видео
                    if (mediaType == 'video')
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    // Показываем счетчик, если медиа больше 9
                    if (index == 8 && mediaItems.length > 9)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '+${mediaItems.length - 9}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Обычное изображение (загружено)
  Widget _buildDownloadedImage(BuildContext context, String fullUrl,
      String imageUrl, Map<String, dynamic> metadata) {
    // Используем кэшированный локальный путь, если он уже определен
    if (_localPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ImageViewer(
                  imageUrl: imageUrl,
                  fileName: metadata['fileName'] as String?,
                ),
              ),
            );
          },
          child: Image.file(
            File(_localPath!),
            width: 250,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Если локальный файл поврежден, загружаем с сервера
              return CachedNetworkImage(
                imageUrl: fullUrl,
                width: 250,
                height: 200,
                fit: BoxFit.cover,
                httpHeaders: {
                  'Accept': 'image/*',
                },
                placeholder: (context, url) {
                  return Container(
                    width: 250,
                    height: 200,
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withOpacity(0.1)
                          : AppColors.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: widget.isMe
                            ? Colors.white
                            : AppColors.primaryPurple,
                      ),
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return Container(
                    width: 250,
                    height: 200,
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withOpacity(0.2)
                          : AppColors.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              );
            },
          ),
        ),
      );
    }

    // Если локальный путь еще не определен, показываем изображение с сервера
    // Путь будет установлен в _checkDownloadStatus, который уже выполняется
    // Не используем FutureBuilder, чтобы избежать лишних проверок при каждом рендере
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () {
          // Открываем MediaViewer со всеми медиа из чата
          final allMedia = _collectAllMedia();
          final currentIndex = _findCurrentMediaIndex(allMedia);
          
          if (allMedia.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MediaViewer(
                  mediaItems: allMedia,
                  initialIndex: currentIndex,
                ),
              ),
            );
          } else {
            // Fallback: открываем ImageViewer
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ImageViewer(
                  imageUrl: imageUrl,
                  fileName: metadata['fileName'] as String?,
                ),
              ),
            );
          }
        },
        child: CachedNetworkImage(
          imageUrl: fullUrl,
          width: 250,
          height: 200,
          fit: BoxFit.cover,
          httpHeaders: {
            'Accept': 'image/*',
          },
          placeholder: (context, url) {
            return Container(
              width: 250,
              height: 200,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.1)
                    : AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: widget.isMe ? Colors.white : AppColors.primaryPurple,
                ),
              ),
            );
          },
          errorWidget: (context, url, error) {
            return Container(
              width: 250,
              height: 200,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }

  // Мутное превью с кнопкой загрузки
  Widget _buildBlurredPreview(BuildContext context, String fullUrl,
      String imageUrl, Map<String, dynamic> metadata, bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 250,
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Мутное изображение
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5),
                BlendMode.darken,
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: SizedBox(
                  width: 250,
                  height: 200,
                  child: CachedNetworkImage(
                    imageUrl: fullUrl,
                    fit: BoxFit.cover,
                    httpHeaders: {
                      'Accept': 'image/*',
                    },
                    placeholder: (context, url) {
                      return Container(
                        width: 250,
                        height: 200,
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.1)
                              : AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    },
                    errorWidget: (context, url, error) {
                      return Container(
                        width: 250,
                        height: 200,
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? Colors.white.withOpacity(0.2)
                              : AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Кнопка загрузки по центру
            Positioned.fill(
              child: Center(
                child: GestureDetector(
                  onTap: isLoading
                      ? null
                      : () => _downloadImage(context, imageUrl, metadata),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 32,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Скачать изображение
  Future<void> _downloadImage(BuildContext context, String imageUrl,
      Map<String, dynamic> metadata) async {
    if (_isDownloading) return;

    try {
      setState(() {
        _isDownloading = true;
      });

      final success = await MediaStorageService.instance.downloadImage(
        imageUrl,
        fileName: metadata['fileName'] as String?,
      );

      if (mounted) {
        if (success) {
          // Обновляем статус
          setState(() {
            _isDownloaded = true;
            _isDownloading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Изображение загружено'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _isDownloading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка загрузки изображения'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Отображение видео
  Widget _buildVideoWidget() {
    final metadata = widget.message.metadata ?? {};
    final videoUrl = metadata['fileUrl'] ??
        metadata['mediaUrl'] ??
        widget.message.mediaUrl ??
        '';
    final fileName = metadata['fileName'] ?? 'Видео';
    final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
    final fullUrl = videoUrl.isNotEmpty ? '$baseUrl$videoUrl' : '';

    if (fullUrl.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(0.2)
              : AppColors.primaryPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_file,
              color: widget.isMe ? Colors.white : AppColors.primaryPurple,
            ),
            const SizedBox(width: 8),
            Text(
              fileName,
              style: TextStyle(
                color: widget.isMe ? Colors.white : AppColors.primaryPurple,
              ),
            ),
          ],
        ),
      );
    }

    // Проверяем наличие превью
    final thumbnailUrl = metadata['thumbnailUrl'] as String?;
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;
    final thumbnailFullUrl = hasThumbnail 
        ? (thumbnailUrl.startsWith('http') ? thumbnailUrl : '$baseUrl$thumbnailUrl')
        : null;

    return InkWell(
      onTap: () {
        // Открываем MediaViewer со всеми медиа из чата
        final allMedia = _collectAllMedia();
        final currentIndex = _findCurrentMediaIndex(allMedia);
        
        if (allMedia.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => MediaViewer(
                mediaItems: allMedia,
                initialIndex: currentIndex,
              ),
            ),
          );
        } else {
          // Fallback: открываем файл
          _openFile(videoUrl);
        }
      },
      child: Container(
        width: 250,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Превью видео или градиент
              if (hasThumbnail && thumbnailFullUrl != null)
                CachedNetworkImage(
                  imageUrl: thumbnailFullUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gradientStart.withOpacity(0.3),
                          AppColors.gradientEnd.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.gradientStart.withOpacity(0.3),
                          AppColors.gradientEnd.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gradientStart.withOpacity(0.3),
                        AppColors.gradientEnd.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              // Затемнение для лучшей видимости иконки
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
              // Иконка воспроизведения
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              // Название файла внизу (если нет превью)
              if (!hasThumbnail)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Диалог действий с сообщением
  void _showDeleteDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Жалоба (только для чужих сообщений)
            if (!widget.isMe)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: const Text('Пожаловаться'),
                subtitle: const Text('Сообщить о нарушении'),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(context);
                },
              ),

            // Удаление (если есть callback)
            if (widget.onDelete != null) ...[
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.orange),
                title: const Text('Удалить у меня'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete?.call(false);
                },
              ),
              if (widget.isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Удалить у всех'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDelete?.call(true);
                  },
                ),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Диалог жалобы на сообщение
  void _showReportDialog(BuildContext context) {
    final senderId = widget.message.senderId;

    ReportDialog.show(
      context,
      reportedUserId: int.tryParse(senderId) ?? 0,
      reportedUsername: widget.message.senderName ?? 'Пользователь',
      messageId: int.tryParse(widget.message.id),
      messageContent: widget.message.content,
      messageIdString: widget.message.id, // Для скрытия сообщения после жалобы
    );
  }
}
