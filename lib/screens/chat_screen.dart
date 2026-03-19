// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/delete_particles_animation.dart';
import '../widgets/voice_message_recorder.dart';
import '../widgets/report_dialog.dart';
import '../utils/app_colors.dart';
import '../utils/image_utils.dart';
import '../services/api_service.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final Chat chat;

  const ChatScreen({super.key, required this.chat});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;
  bool _isSending = false;
  bool _messagesLoaded = false;
  int _previousMessageCount = 0;
  Timer? _typingTimer;
  Timer? _refreshTimer;
  ChatProvider? _chatProvider;
  final Map<String, GlobalKey> _messageKeys = {};
  final Set<String> _deletingMessages = {}; // Сообщения, которые удаляются
  final Set<String> _remoteDeletedMessages = {}; // Сообщения, удаленные другими пользователями
  bool _showScrollToBottomButton = false; // ⭐ НОВОЕ: Видимость кнопки прокрутки вниз
  bool _showVoiceRecorder = false; // ⭐ НОВОЕ: Показывать ли виджет записи голосовых сообщений

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // print('[ChatScreen] Инициализация для чата: ${widget.chat.id}');
    _messageController.addListener(_onTextChanged);

    // ⭐⭐⭐ КРИТИЧНО: Отправляем join_chat СРАЗУ при открытии экрана
    // Это нужно для того, чтобы backend знал об открытом чате ДО получения сообщений
    // ⭐⭐⭐ ИСПРАВЛЕНО: Устанавливаем currentChatId СРАЗУ, до addPostFrameCallback
    if (mounted) {
      final chatProvider = context.read<ChatProvider>();
      _chatProvider = chatProvider;
      
      // ⭐⭐⭐ КРИТИЧНО: Устанавливаем currentChatId СРАЗУ, синхронно
      chatProvider.setCurrentChatId(widget.chat.id);
      // print('[ChatScreen] ✅ setCurrentChatId вызван СРАЗУ для чата: ${widget.chat.id}');
      
      // Устанавливаем callback для обработки удаления сообщений от других пользователей
      _chatProvider?.setOnMessageDeletedForAnimation((messageId) {
        if (mounted) {
          _showDeleteAnimationForMessage(messageId);
        }
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMessages();
        _startAutoRefresh();
      }
    });
    
    // ⭐⭐⭐ НОВОЕ: Добавляем listener для отслеживания позиции прокрутки
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // print('[ChatScreen] Приложение вернулось на передний план');
      context.read<ChatProvider>().markMessagesAsRead(widget.chat.id);
      _refreshMessages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll); // ⭐ НОВОЕ: Удаляем listener
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _stopAutoRefresh();

    // ⭐⭐⭐ КРИТИЧНО: Отправляем leave_chat при закрытии экрана чата
    if (_chatProvider != null && widget.chat.id == _chatProvider!.currentChatId) {
      _chatProvider!.setCurrentChatId(null);
      // print('[ChatScreen] ✅ leave_chat отправлен для чата: ${widget.chat.id}');
    }

    // Используем сохраненную ссылку на ChatProvider вместо context.read
    // так как контекст может быть уже недействителен в dispose
    if (_chatProvider != null && _chatProvider!.currentChatId == widget.chat.id) {
      _chatProvider!.setCurrentChatId(null);
    }

    super.dispose();
  }

  void _startAutoRefresh() {
    // Отменяем предыдущий таймер, если он существует
    _refreshTimer?.cancel();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      // Проверяем mounted перед вызовом
      if (!mounted) {
        timer.cancel();
        // print('[ChatScreen] ⚠️ Таймер отменен: виджет размонтирован');
        return;
      }
      _refreshMessages();
    });
    // print('[ChatScreen] ✅ Автообновление запущено (каждые 2 сек)');
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    // print('[ChatScreen] ❌ Автообновление остановлено');
  }

  Future<void> _refreshMessages() async {
    // Проверяем, что виджет еще смонтирован
    if (!mounted) {
      // print('[ChatScreen] ⚠️ Попытка обновления после unmount, пропускаем');
      return;
    }

    try {
      // Используем сохраненную ссылку на ChatProvider или получаем через context
      final chatProvider = _chatProvider ?? context.read<ChatProvider>();
      
      // Дополнительная проверка на mounted после асинхронной операции
      if (!mounted) {
        // print('[ChatScreen] ⚠️ Виджет размонтирован во время обновления');
        return;
      }

      final oldCount = chatProvider.messages.length;

      await chatProvider.loadMessages(widget.chat.id);

      // Проверяем mounted после загрузки сообщений
      if (!mounted) {
        // print('[ChatScreen] ⚠️ Виджет размонтирован после загрузки сообщений');
        return;
      }

      final newCount = chatProvider.messages.length;

      if (newCount > oldCount) {
        // print(           // '[ChatScreen] 🆕 НОВОЕ СООБЩЕНИЕ! Было: $oldCount, стало: $newCount');

        await chatProvider.markMessagesAsRead(widget.chat.id);

        if (mounted) {
          setState(() {
            _previousMessageCount = newCount;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      // Не логируем ошибку, если виджет уже размонтирован
      if (mounted) {
        // print('[ChatScreen] ❌ Ошибка автообновления: $e');
      }
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadMessages() async {
    if (_messagesLoaded) {
      // print('[ChatScreen] ⏭️ Сообщения уже загружены, пропускаем');
      return;
    }

    // print(       // '[ChatScreen] 📥 Первоначальная загрузка сообщений для чата: ${widget.chat.id}');
    final chatProvider = context.read<ChatProvider>();

    // ⭐⭐⭐ ИСПРАВЛЕНО: setCurrentChatId уже вызван в initState, не вызываем повторно
    // chatProvider.setCurrentChatId(widget.chat.id); // Убрано - уже вызвано в initState

    await chatProvider.loadMessages(widget.chat.id);

    await chatProvider.markMessagesAsRead(widget.chat.id);

    // print(       // '[ChatScreen] ✅ Первоначальная загрузка завершена: ${chatProvider.messages.length} сообщений');

    if (mounted) {
      setState(() {
        _messagesLoaded = true;
        _previousMessageCount = chatProvider.messages.length;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  // ⭐⭐⭐ НОВОЕ: Обработчик изменения позиции прокрутки
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = 100.0; // Порог в пикселях для показа кнопки
    
    // Показываем кнопку, если не прокручено до конца (с учетом порога)
    final shouldShow = maxScroll - currentScroll > threshold;
    
    if (shouldShow != _showScrollToBottomButton) {
      setState(() {
        _showScrollToBottomButton = shouldShow;
      });
    }
  }

  // ⭐⭐⭐ НОВОЕ: Показать меню вариантов отправки при зажатии кнопки отправки
  Future<void> _showSendOptions(BuildContext context) async {
    if (_isSending) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Обычное сообщение
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.text_fields, color: AppColors.primaryPurple),
                ),
                title: const Text('Обычное сообщение'),
                onTap: () {
                  Navigator.pop(context);
                  _sendMessage();
                },
              ),
              // Голосовое сообщение
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.mic, color: AppColors.primaryPurple),
                ),
                title: const Text('Голосовое сообщение'),
                onTap: () async {
                  Navigator.pop(context);
                  final hasPermission = await _requestMicrophonePermission();
                  if (hasPermission && mounted) {
                    setState(() {
                      _showVoiceRecorder = true;
                      _focusNode.unfocus();
                    });
                  }
                },
              ),
              // Кружок (видео)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, color: AppColors.primaryPurple),
                ),
                title: const Text('Записать кружок'),
                onTap: () async {
                  Navigator.pop(context);
                  final hasPermission = await _requestCameraAndMicrophonePermissions();
                  if (hasPermission && mounted) {
                    // TODO: Реализовать запись видео-кружка
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Функция записи кружка будет реализована позже'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐⭐⭐ НОВОЕ: Запрос разрешения на микрофон
  Future<bool> _requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Разрешение на микрофон'),
              content: const Text(
                'Для записи голосовых сообщений необходимо разрешение на использование микрофона. Пожалуйста, включите его в настройках приложения.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Настройки'),
                ),
              ],
            ),
          );
        }
        return false;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Разрешение на микрофон отклонено'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка запроса разрешения на микрофон: $e');
      return false;
    }
  }

  // Обработка действий из меню (три точки)
  void _handleMenuAction(String action) {
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = chatProvider.currentUserId;

    if (currentUserId == null) return;

    final otherUserId = widget.chat.getOtherParticipantId(currentUserId);
    if (otherUserId == null) return;

    final otherUserIdInt = int.tryParse(otherUserId);
    if (otherUserIdInt == null) return;

    switch (action) {
      case 'report':
        ReportDialog.show(
          context,
          reportedUserId: otherUserIdInt,
          reportedUsername: widget.chat.name,
          chatId: int.tryParse(widget.chat.id),
        );
        break;
      case 'block':
        _showBlockConfirmation(otherUserIdInt, widget.chat.name);
        break;
    }
  }

  void _showBlockConfirmation(int userId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заблокировать пользователя'),
        content: Text('Вы уверены, что хотите заблокировать $username?\n\nВы не сможете получать от него сообщения и звонки.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _blockUser(userId, username);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(int userId, String username) async {
    try {
      final response = await ApiService.instance.blockUser(userId);

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$username заблокирован'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Ошибка блокировки'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ⭐⭐⭐ НОВОЕ: Запрос разрешений на камеру и микрофон
  Future<bool> _requestCameraAndMicrophonePermissions() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();
      
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        return true;
      }
      
      if (mounted) {
        final deniedPermissions = <String>[];
        if (!cameraStatus.isGranted) deniedPermissions.add('камеру');
        if (!microphoneStatus.isGranted) deniedPermissions.add('микрофон');
        
        if (cameraStatus.isPermanentlyDenied || microphoneStatus.isPermanentlyDenied) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Разрешения'),
              content: Text(
                'Для записи видео необходимо разрешение на использование ${deniedPermissions.join(' и ')}. Пожалуйста, включите их в настройках приложения.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Настройки'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Разрешение на ${deniedPermissions.join(' и ')} отклонено'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return false;
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка запроса разрешений: $e');
      return false;
    }
  }

  // Показать диалог выбора источника (камера/галерея/файл)
  Future<void> _showAttachmentOptions() async {
    if (_isSending) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primaryPurple),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primaryPurple),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file, color: AppColors.primaryPurple),
              title: const Text('Выбрать файл'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Сделать фото с камеры
  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        await _sendImageFile(photo.path, photo.name);
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка съемки фото: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка съемки фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Выбрать фото и видео из галереи (множественный выбор)
  Future<void> _pickImageFromGallery() async {
    try {
      // ⭐⭐⭐ ИЗМЕНЕНО: Используем file_picker для множественного выбора фото и видео
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.media, // Позволяет выбрать и фото, и видео
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        // Разделяем на фото и видео
        final List<XFile> imageFiles = [];
        final List<XFile> videoFiles = [];
        
        for (final platformFile in result.files) {
          final path = platformFile.path;
          if (path == null) continue;
          
          // Проверяем тип файла по расширению
          final lowerPath = path.toLowerCase();
          if (lowerPath.endsWith('.mp4') || 
              lowerPath.endsWith('.mov') || 
              lowerPath.endsWith('.avi') ||
              lowerPath.endsWith('.mkv') ||
              lowerPath.endsWith('.m4v') ||
              lowerPath.endsWith('.3gp') ||
              lowerPath.endsWith('.webm')) {
            videoFiles.add(XFile(path, name: platformFile.name));
          } else {
            imageFiles.add(XFile(path, name: platformFile.name));
          }
        }
        
        // ⭐⭐⭐ ИЗМЕНЕНО: Отправляем фото и видео в одном сообщении
        if (imageFiles.isNotEmpty || videoFiles.isNotEmpty) {
          await _sendMultipleMedia(imageFiles, videoFiles);
        }
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка выбора медиа: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора медиа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ⭐⭐⭐ НОВОЕ: Отправить фото и видео в одном сообщении
  Future<void> _sendMultipleMedia(List<XFile> images, List<XFile> videos) async {
    if (images.isEmpty && videos.isEmpty) return;

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    try {
      final List<Map<String, dynamic>> uploadedImages = [];
      final List<Map<String, dynamic>> uploadedVideos = [];
      final api = ApiService();

      // Загружаем все фото на сервер
      for (final image in images) {
        try {
          // Сжимаем изображение
          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            image.path,
            image.path + '_compressed.jpg',
            quality: 85,
            format: CompressFormat.jpeg,
          );

          if (compressedFile == null) {
            // print('[ChatScreen] ⚠️ Не удалось сжать изображение: ${image.name}');
            continue;
          }

          final fileBytes = await compressedFile.readAsBytes();
          final base64File = base64Encode(fileBytes);
          final mimeType = 'image/jpeg';
          final fileName = image.name.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
          final dataUrl = 'data:$mimeType;base64,$base64File';

          // Загружаем на сервер
          final response = await api.post('/files/upload', data: {
            'file': dataUrl,
            'filename': fileName,
            'fileType': mimeType,
          });

          if (response['success'] == true) {
            final fileUrl = response['fileUrl'];
            uploadedImages.add({
              'fileUrl': fileUrl,
              'fileName': fileName,
              'fileSize': fileBytes.length,
              'fileType': mimeType,
              'mediaUrl': fileUrl,
              'type': 'image',
            });
            // print('[ChatScreen] ✅ Изображение загружено: $fileUrl');
          }
        } catch (e) {
          // print('[ChatScreen] ❌ Ошибка загрузки изображения ${image.name}: $e');
        }
      }

      // Загружаем все видео на сервер
      for (final video in videos) {
        try {
          final file = File(video.path);
          final fileBytes = await file.readAsBytes();
          final base64File = base64Encode(fileBytes);
          
          // Определяем MIME тип по расширению
          String mimeType = 'video/mp4';
          final ext = video.path.toLowerCase().split('.').last;
          if (ext == 'mov') {
            mimeType = 'video/quicktime';
          } else if (ext == 'avi') {
            mimeType = 'video/x-msvideo';
          } else if (ext == 'mkv') {
            mimeType = 'video/x-matroska';
          } else if (ext == 'm4v' || ext == '3gp') {
            mimeType = 'video/mp4';
          }
          
          final fileName = video.name;
          final dataUrl = 'data:$mimeType;base64,$base64File';

          // ⭐⭐⭐ НОВОЕ: Генерируем thumbnail из первого кадра видео
          String? thumbnailUrl;
          try {
            final thumbnailPath = await VideoThumbnail.thumbnailFile(
              video: video.path,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 512,
              quality: 75,
            );
            
            if (thumbnailPath != null) {
              final thumbnailFile = File(thumbnailPath);
              final thumbnailBytes = await thumbnailFile.readAsBytes();
              final thumbnailBase64 = base64Encode(thumbnailBytes);
              final thumbnailDataUrl = 'data:image/jpeg;base64,$thumbnailBase64';
              
              // Загружаем thumbnail на сервер
              final thumbnailResponse = await api.post('/files/upload', data: {
                'file': thumbnailDataUrl,
                'filename': '${path.basenameWithoutExtension(fileName)}_thumb.jpg',
                'fileType': 'image/jpeg',
              });
              
              if (thumbnailResponse['success'] == true) {
                thumbnailUrl = thumbnailResponse['fileUrl'];
                // print('[ChatScreen] ✅ Thumbnail для видео загружен: $thumbnailUrl');
              }
              
              // Удаляем временный файл thumbnail
              try {
                await thumbnailFile.delete();
              } catch (e) {
                // print('[ChatScreen] ⚠️ Ошибка удаления временного thumbnail: $e');
              }
            }
          } catch (e) {
            // print('[ChatScreen] ⚠️ Ошибка генерации thumbnail для видео: $e');
            // Продолжаем без thumbnail
          }

          // Загружаем видео на сервер
          final response = await api.post('/files/upload', data: {
            'file': dataUrl,
            'filename': fileName,
            'fileType': mimeType,
          });

          if (response['success'] == true) {
            final fileUrl = response['fileUrl'];
            uploadedVideos.add({
              'fileUrl': fileUrl,
              'fileName': fileName,
              'fileSize': fileBytes.length,
              'fileType': mimeType,
              'mediaUrl': fileUrl,
              'type': 'video',
              if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
            });
            // print('[ChatScreen] ✅ Видео загружено: $fileUrl');
          }
        } catch (e) {
          // print('[ChatScreen] ❌ Ошибка загрузки видео ${video.name}: $e');
        }
      }

      if (uploadedImages.isEmpty && uploadedVideos.isEmpty) {
        throw Exception('Не удалось загрузить ни одно медиа');
      }

      // Определяем тип сообщения: если есть и фото и видео, используем 'image' (для обратной совместимости)
      final messageType = uploadedVideos.isEmpty ? 'image' : (uploadedImages.isEmpty ? 'video' : 'image');
      
      // Объединяем все медиа в один массив для отображения
      final List<Map<String, dynamic>> allMedia = [];
      allMedia.addAll(uploadedImages);
      allMedia.addAll(uploadedVideos);

      // Отправляем все медиа в одном сообщении
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.sendMessage(
        '', // Пустой текст
        chatId: widget.chat.id,
        type: messageType,
        metadata: {
          'images': uploadedImages, // Массив изображений
          'videos': uploadedVideos, // Массив видео
          'media': allMedia, // Объединенный массив всех медиа
          'count': allMedia.length,
          // Для обратной совместимости оставляем первый элемент
          'fileUrl': allMedia.first['fileUrl'],
          'fileName': allMedia.first['fileName'],
          'fileSize': allMedia.first['fileSize'],
          'fileType': allMedia.first['fileType'],
          'mediaUrl': allMedia.first['mediaUrl'],
        },
      );

      // print('[ChatScreen] ✅ Отправлено ${uploadedImages.length} фото и ${uploadedVideos.length} видео в одном сообщении');
      
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        final totalCount = uploadedImages.length + uploadedVideos.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Отправлено $totalCount медиа (${uploadedImages.length} фото, ${uploadedVideos.length} видео)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка отправки медиа: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки медиа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Отправить несколько изображений (группировка по 10 штук) - для обратной совместимости
  Future<void> _sendMultipleImages(List<XFile> images) async {
    if (images.isEmpty) return;

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    try {
      // Группируем фото по 10 штук
      const int groupSize = 10;
      for (int i = 0; i < images.length; i += groupSize) {
        final group = images.sublist(
          i,
          i + groupSize > images.length ? images.length : i + groupSize,
        );
        
        await _sendImageGroup(group);
      }

      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Отправлено ${images.length} фото'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка отправки изображений: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Отправить группу изображений в одном сообщении
  Future<void> _sendImageGroup(List<XFile> images) async {
    if (images.isEmpty) return;

    try {
      final List<Map<String, dynamic>> uploadedImages = [];
      final api = ApiService();

      // Загружаем все фото на сервер
      for (final image in images) {
        try {
          // Сжимаем изображение
          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            image.path,
            image.path + '_compressed.jpg',
            quality: 85,
            format: CompressFormat.jpeg,
          );

          if (compressedFile == null) {
            // print('[ChatScreen] ⚠️ Не удалось сжать изображение: ${image.name}');
            continue;
          }

          final fileBytes = await compressedFile.readAsBytes();
          final base64File = base64Encode(fileBytes);
          final mimeType = 'image/jpeg';
          final fileName = image.name.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
          final dataUrl = 'data:$mimeType;base64,$base64File';

          // Загружаем на сервер
          final response = await api.post('/files/upload', data: {
            'file': dataUrl,
            'filename': fileName,
            'fileType': mimeType,
          });

          if (response['success'] == true) {
            final fileUrl = response['fileUrl'];
            uploadedImages.add({
              'fileUrl': fileUrl,
              'fileName': fileName,
              'fileSize': fileBytes.length,
              'fileType': mimeType,
              'mediaUrl': fileUrl,
            });
            // print('[ChatScreen] ✅ Изображение загружено: $fileUrl');
          }
        } catch (e) {
          // print('[ChatScreen] ❌ Ошибка загрузки изображения ${image.name}: $e');
        }
      }

      if (uploadedImages.isEmpty) {
        throw Exception('Не удалось загрузить ни одно изображение');
      }

      // Отправляем все фото в одном сообщении
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.sendMessage(
        '', // Пустой текст
        chatId: widget.chat.id,
        type: 'image',
        metadata: {
          'images': uploadedImages, // Массив изображений
          'count': uploadedImages.length,
          // Для обратной совместимости оставляем первое изображение
          'fileUrl': uploadedImages.first['fileUrl'],
          'fileName': uploadedImages.first['fileName'],
          'fileSize': uploadedImages.first['fileSize'],
          'fileType': uploadedImages.first['fileType'],
          'mediaUrl': uploadedImages.first['mediaUrl'],
        },
      );

      // print('[ChatScreen] ✅ Отправлено ${uploadedImages.length} фото в одном сообщении');
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка отправки группы изображений: $e');
      rethrow;
    }
  }

  // ⭐⭐⭐ НОВОЕ: Отправить несколько видео
  Future<void> _sendMultipleVideos(List<XFile> videos) async {
    if (videos.isEmpty) return;

    if (mounted) {
      setState(() {
        _isSending = true;
      });
    }

    try {
      final List<Map<String, dynamic>> uploadedVideos = [];
      final api = ApiService();

      // Загружаем все видео на сервер
      for (final video in videos) {
        try {
          final file = File(video.path);
          final fileBytes = await file.readAsBytes();
          final base64File = base64Encode(fileBytes);
          
          // Определяем MIME тип по расширению
          String mimeType = 'video/mp4';
          final ext = video.path.toLowerCase().split('.').last;
          if (ext == 'mov') {
            mimeType = 'video/quicktime';
          } else if (ext == 'avi') {
            mimeType = 'video/x-msvideo';
          } else if (ext == 'mkv') {
            mimeType = 'video/x-matroska';
          } else if (ext == 'm4v' || ext == '3gp') {
            mimeType = 'video/mp4';
          }
          
          final fileName = video.name;
          final dataUrl = 'data:$mimeType;base64,$base64File';

          // ⭐⭐⭐ НОВОЕ: Генерируем thumbnail из первого кадра видео
          String? thumbnailUrl;
          try {
            final thumbnailPath = await VideoThumbnail.thumbnailFile(
              video: video.path,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 512,
              quality: 75,
            );
            
            if (thumbnailPath != null) {
              final thumbnailFile = File(thumbnailPath);
              final thumbnailBytes = await thumbnailFile.readAsBytes();
              final thumbnailBase64 = base64Encode(thumbnailBytes);
              final thumbnailDataUrl = 'data:image/jpeg;base64,$thumbnailBase64';
              
              // Загружаем thumbnail на сервер
              final thumbnailResponse = await api.post('/files/upload', data: {
                'file': thumbnailDataUrl,
                'filename': '${path.basenameWithoutExtension(fileName)}_thumb.jpg',
                'fileType': 'image/jpeg',
              });
              
              if (thumbnailResponse['success'] == true) {
                thumbnailUrl = thumbnailResponse['fileUrl'];
                // print('[ChatScreen] ✅ Thumbnail для видео загружен: $thumbnailUrl');
              }
              
              // Удаляем временный файл thumbnail
              try {
                await thumbnailFile.delete();
              } catch (e) {
                // print('[ChatScreen] ⚠️ Ошибка удаления временного thumbnail: $e');
              }
            }
          } catch (e) {
            // print('[ChatScreen] ⚠️ Ошибка генерации thumbnail для видео: $e');
            // Продолжаем без thumbnail
          }

          // Загружаем видео на сервер
          final response = await api.post('/files/upload', data: {
            'file': dataUrl,
            'filename': fileName,
            'fileType': mimeType,
          });

          if (response['success'] == true) {
            final fileUrl = response['fileUrl'];
            uploadedVideos.add({
              'fileUrl': fileUrl,
              'fileName': fileName,
              'fileSize': fileBytes.length,
              'fileType': mimeType,
              'mediaUrl': fileUrl,
              'type': 'video',
              if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
            });
            // print('[ChatScreen] ✅ Видео загружено: $fileUrl');
          }
        } catch (e) {
          // print('[ChatScreen] ❌ Ошибка загрузки видео ${video.name}: $e');
        }
      }

      if (uploadedVideos.isEmpty) {
        throw Exception('Не удалось загрузить ни одно видео');
      }

      // Отправляем все видео в одном сообщении
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.sendMessage(
        '', // Пустой текст
        chatId: widget.chat.id,
        type: 'video',
        metadata: {
          'videos': uploadedVideos, // Массив видео
          'count': uploadedVideos.length,
          // Для обратной совместимости оставляем первое видео
          'fileUrl': uploadedVideos.first['fileUrl'],
          'fileName': uploadedVideos.first['fileName'],
          'fileSize': uploadedVideos.first['fileSize'],
          'fileType': uploadedVideos.first['fileType'],
          'mediaUrl': uploadedVideos.first['mediaUrl'],
        },
      );

      // print('[ChatScreen] ✅ Отправлено ${uploadedVideos.length} видео в одном сообщении');
      
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Отправлено ${uploadedVideos.length} видео'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка отправки видео: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки видео: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Отправить одно изображение (для обратной совместимости)
  Future<void> _sendImageFile(String filePath, String fileName) async {
    try {
      // print('[ChatScreen] 📸 Отправка изображения: $fileName');

      // Показываем индикатор загрузки
      if (mounted) {
        setState(() {
          _isSending = true;
        });
      }

      // ⭐⭐⭐ СЖИМАЕМ ИЗОБРАЖЕНИЕ КАК В TELEGRAM
      File? compressedFile;
      try {
        // print('[ChatScreen] 🔄 Сжатие изображения...');
        // print('[ChatScreen] Исходный файл: $filePath');
        
        // Проверяем, что файл существует
        final originalFile = File(filePath);
        if (!await originalFile.exists()) {
          throw Exception('Файл не найден: $filePath');
        }
        
        final originalSize = await originalFile.length();
        // print('[ChatScreen] Размер оригинала: ${(originalSize / 1024).toStringAsFixed(1)} KB');
        
        // Получаем временную директорию
        final tempDir = await getTemporaryDirectory();
        final targetPath = path.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
        );
        
        // print('[ChatScreen] Путь для сжатого файла: $targetPath');
        
        // Сжимаем изображение
        final result = await FlutterImageCompress.compressAndGetFile(
          filePath,
          targetPath,
          quality: 85, // Качество как в Telegram (85%)
          minWidth: 1920, // Максимальная ширина
          minHeight: 1920, // Максимальная высота
          format: CompressFormat.jpeg, // Всегда JPEG для лучшего сжатия
        );
        
        if (result != null) {
          compressedFile = File(result.path);
          if (await compressedFile.exists()) {
            final compressedSize = await compressedFile.length();
            // print('[ChatScreen] ✅ Изображение сжато: ${(originalSize / 1024).toStringAsFixed(1)} KB -> ${(compressedSize / 1024).toStringAsFixed(1)} KB');
          } else {
            // print('[ChatScreen] ⚠️ Сжатый файл не создан, используем оригинал');
            compressedFile = originalFile;
          }
        } else {
          // print('[ChatScreen] ⚠️ Не удалось сжать, используем оригинал');
          compressedFile = originalFile;
        }
      } catch (e, stackTrace) {
        // print('[ChatScreen] ⚠️ Ошибка сжатия: $e');
        // print('[ChatScreen] Stack trace: $stackTrace');
        // print('[ChatScreen] Используем оригинал');
        try {
          compressedFile = File(filePath);
          if (!await compressedFile.exists()) {
            throw Exception('Оригинальный файл также не найден');
          }
        } catch (e2) {
          // print('[ChatScreen] ❌ Критическая ошибка: $e2');
          if (mounted) {
            setState(() {
              _isSending = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ошибка загрузки файла: $e2'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Загружаем сжатый файл на сервер
      // print('[ChatScreen] 📤 Чтение файла для загрузки...');
      List<int> fileBytes;
      try {
        fileBytes = await compressedFile.readAsBytes();
        // print('[ChatScreen] ✅ Файл прочитан: ${fileBytes.length} bytes');
      } catch (e) {
        // print('[ChatScreen] ❌ Ошибка чтения файла: $e');
        if (mounted) {
          setState(() {
            _isSending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка чтения файла: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // print('[ChatScreen] 🔄 Кодирование в base64...');
      final base64File = base64Encode(fileBytes);
      // print('[ChatScreen] ✅ Base64 длина: ${base64File.length}');

      // Всегда используем JPEG для сжатых изображений
      String mimeType = 'image/jpeg';
      String finalFileName = fileName;
      
      // Если оригинал был не JPEG, меняем расширение
      final ext = fileName.toLowerCase().split('.').last;
      if (ext != 'jpg' && ext != 'jpeg') {
        finalFileName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '.jpg');
      }

      // Формируем data URL
      final dataUrl = 'data:$mimeType;base64,$base64File';

      // Загружаем файл на сервер
      final api = ApiService();
      final response = await api.post('/files/upload', data: {
        'file': dataUrl,
        'filename': finalFileName,
        'fileType': mimeType,
      });

      if (response['success'] == true) {
        final fileUrl = response['fileUrl'];
        // print('[ChatScreen] ✅ Изображение загружено: $fileUrl');

        // Отправляем через WebSocket
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.sendMessage(
          '', // Пустой текст, так как это изображение
          chatId: widget.chat.id,
          type: 'image',
          metadata: {
            'fileUrl': fileUrl,
            'fileName': finalFileName,
            'fileSize': fileBytes.length,
            'fileType': mimeType,
            'mediaUrl': fileUrl,
          },
        );

        if (mounted) {
          setState(() {
            _isSending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Фото отправлено'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception(response['error'] ?? 'Ошибка загрузки фото');
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка отправки изображения: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;
        final fileExtension = result.files.single.extension ?? '';

        // print('[ChatScreen] 📎 Выбран файл: $fileName ($fileSize bytes)');

        // Показываем индикатор загрузки
        if (mounted) {
          setState(() {
            _isSending = true;
          });
        }

        // Загружаем файл на сервер
        final file = File(filePath);
        final fileBytes = await file.readAsBytes();
        final base64File = base64Encode(fileBytes);

        // Определяем MIME тип и тип сообщения
        String mimeType = 'application/octet-stream';
        String messageType = 'file';
        
        if (fileExtension.isNotEmpty) {
          final ext = fileExtension.toLowerCase();
          final mimeTypes = {
            'jpg': 'image/jpeg',
            'jpeg': 'image/jpeg',
            'png': 'image/png',
            'gif': 'image/gif',
            'webp': 'image/webp',
            'heic': 'image/heic', // iOS формат
            'heif': 'image/heif', // iOS формат
            'pdf': 'application/pdf',
            'doc': 'application/msword',
            'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xls': 'application/vnd.ms-excel',
            'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'txt': 'text/plain',
            'mp4': 'video/mp4',
            'mov': 'video/quicktime', // iOS формат
            'avi': 'video/x-msvideo',
            'mp3': 'audio/mpeg',
            'wav': 'audio/wav',
          };
          mimeType = mimeTypes[ext] ?? 'application/octet-stream';
          
          // Определяем тип сообщения
          if (mimeType.startsWith('image/')) {
            messageType = 'image';
          } else if (mimeType.startsWith('video/')) {
            messageType = 'video';
          } else if (mimeType.startsWith('audio/')) {
            messageType = 'audio';
          } else {
            messageType = 'file';
          }
        }

        // Формируем data URL
        final dataUrl = 'data:$mimeType;base64,$base64File';

        // Загружаем файл на сервер
        final api = ApiService();
        final response = await api.post('/files/upload', data: {
          'file': dataUrl,
          'filename': fileName,
          'fileType': mimeType,
        });

        if (response['success'] == true) {
          final fileUrl = response['fileUrl'];
          // print('[ChatScreen] ✅ Файл загружен: $fileUrl');
          // print('[ChatScreen] Тип сообщения: $messageType');

          // Отправляем через WebSocket
          final chatProvider = context.read<ChatProvider>();
          await chatProvider.sendMessage(
            messageType == 'image' || messageType == 'video' 
                ? '📎 ${messageType == 'image' ? 'Изображение' : 'Видео'}'
                : fileName,
            chatId: widget.chat.id,
            type: messageType,
            metadata: {
              'fileUrl': fileUrl,
              'fileName': fileName,
              'fileSize': fileSize,
              'fileType': mimeType,
              'mediaUrl': fileUrl, // Для обратной совместимости
            },
          );

          if (mounted) {
            setState(() {
              _isSending = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Файл отправлен'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          throw Exception(response['error'] ?? 'Ошибка загрузки файла');
        }
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка загрузки файла: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки файла: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();
    _stopTyping();

    try {
      final chatProvider = context.read<ChatProvider>();
      // print('[ChatScreen] 📤 Отправка сообщения...');

      await chatProvider.sendMessage(text, chatId: widget.chat.id);

      // print(         // '[ChatScreen] ✅ Сообщение отправлено, принудительно обновляем список');

      await chatProvider.loadMessages(widget.chat.id);

      if (mounted) {
        setState(() {
          _isSending = false;
          _previousMessageCount = chatProvider.messages.length;
        });
        _scrollToBottom();
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка отправки сообщения: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка отправки сообщения'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleTyping() {
    final chatProvider = context.read<ChatProvider>();

    if (!_isTyping) {
      _isTyping = true;
      chatProvider.sendTypingStatus(widget.chat.id, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping && mounted) {
      _isTyping = false;
      context.read<ChatProvider>().sendTypingStatus(widget.chat.id, false);
    }
    _typingTimer?.cancel();
  }

  void _startCall(String callType) {
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = chatProvider.currentUserId;

    // print('[ChatScreen] 📞 Инициация звонка');
    // print('[ChatScreen] Текущий пользователь: $currentUserId');
    // print('[ChatScreen] Чат: ${widget.chat}');

    if (currentUserId == null || currentUserId.isEmpty) {
      // print('[ChatScreen] ❌ Текущий пользователь не определен');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: пользователь не авторизован'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // УЛУЧШЕНО: Используем метод из модели Chat
    // print('[ChatScreen] ========================================');
    // print('[ChatScreen] 🔍 ДИАГНОСТИКА ПЕРЕД ЗВОНКОМ');
    // print('[ChatScreen] currentUserId: "$currentUserId" (тип: ${currentUserId.runtimeType})');
    // print('[ChatScreen] chat.id: "${widget.chat.id}"');
    // print('[ChatScreen] chat.participants: ${widget.chat.participants}');
    // print('[ChatScreen] chat.receiverId: "${widget.chat.receiverId}"');
    // print('[ChatScreen] ========================================');
    
    final receiverId = widget.chat.getOtherParticipantId(currentUserId);

    // print('[ChatScreen] ========================================');
    // print('[ChatScreen] 📞 РЕЗУЛЬТАТ ОПРЕДЕЛЕНИЯ ПОЛУЧАТЕЛЯ');
    // print('[ChatScreen] receiverId: "$receiverId" (тип: ${receiverId?.runtimeType})');
    // print('[ChatScreen] currentUserId: "$currentUserId" (тип: ${currentUserId.runtimeType})');
    // print('[ChatScreen] Сравнение: "$receiverId" == "$currentUserId" = ${receiverId == currentUserId}');
    // print('[ChatScreen] ========================================');

    if (receiverId == null || receiverId.isEmpty) {
      // print('[ChatScreen] ❌ Не удалось определить получателя');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось определить получателя звонка'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Проверяем что не звоним сами себе
    // ⭐⭐⭐ КРИТИЧНО: Приводим к строке и обрезаем пробелы для корректного сравнения
    final cleanReceiverId = receiverId.trim();
    final cleanCurrentUserId = currentUserId.trim();
    
    if (cleanReceiverId == cleanCurrentUserId) {
      // print('[ChatScreen] ========================================');
      // print('[ChatScreen] ❌❌❌ ПОПЫТКА ПОЗВОНИТЬ САМОМУ СЕБЕ!');
      // print('[ChatScreen] receiverId: "$cleanReceiverId"');
      // print('[ChatScreen] currentUserId: "$cleanCurrentUserId"');
      // print('[ChatScreen] Они равны! Звонок заблокирован.');
      // print('[ChatScreen] ========================================');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя позвонить самому себе'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // print('[ChatScreen] ✅ Открываем CallScreen');
    // print('[ChatScreen] - chatId: ${widget.chat.id}');
    // print('[ChatScreen] - receiverId: $receiverId');
    // print('[ChatScreen] - receiverName: ${widget.chat.name}');
    // print('[ChatScreen] - callType: $callType');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          chatId: widget.chat.id,
          receiverId: receiverId,
          receiverName: widget.chat.name,
          receiverAvatar: widget.chat.avatarUrl,
          callType: callType,
        ),
      ),
    );
  }

  // Показать анимацию удаления для сообщения, удаленного другим пользователем
  void _showDeleteAnimationForMessage(String messageId) {
    // print('[ChatScreen] 🎬 Показ анимации удаления для сообщения: $messageId');
    // print('[ChatScreen]   - Available keys: ${_messageKeys.keys.take(5).join(", ")}');
    
    // Пробуем найти ключ по разным форматам messageId
    GlobalKey? messageKey = _messageKeys[messageId];
    if (messageKey == null) {
      // Пробуем найти по числовому формату
      final numericId = int.tryParse(messageId);
      if (numericId != null) {
        messageKey = _messageKeys[numericId.toString()];
        // print('[ChatScreen]   - Tried numeric format: ${numericId.toString()}');
      }
    }
    
    // Если все еще не найдено, ищем по всем ключам
    if (messageKey == null) {
      for (final key in _messageKeys.keys) {
        if (key.toString() == messageId || key == messageId) {
          messageKey = _messageKeys[key];
          // print('[ChatScreen]   - Found by iteration: $key');
          break;
        }
      }
    }
    
    if (messageKey == null || !mounted) {
      // print('[ChatScreen]   - ❌ Ключ не найден или виджет не смонтирован');
      // print('[ChatScreen]   - MessageKey is null: ${messageKey == null}');
      // print('[ChatScreen]   - Mounted: $mounted');
      return;
    }

    // print('[ChatScreen]   - ✅ Ключ найден, показываем анимацию');

    // Помечаем сообщение как удаляемое (скроем его в UI)
    setState(() {
      _remoteDeletedMessages.add(messageId);
    });

    // Показываем анимацию частиц
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => DeleteParticlesOverlay(
        messageKey: messageKey!,
        onComplete: () {
          overlayEntry?.remove();
          setState(() {
            _remoteDeletedMessages.remove(messageId);
            // Не удаляем ключ, так как он может использоваться для других операций
          });
        },
      ),
    );
    Overlay.of(context).insert(overlayEntry);
    // print('[ChatScreen]   - ✅ Анимация запущена');
  }

  Future<void> _deleteMessage(Message message, ChatProvider chatProvider, bool deleteForEveryone) async {
    try {
      // print('[ChatScreen] ========================================');
      // print('[ChatScreen] 🗑️ УДАЛЕНИЕ СООБЩЕНИЯ');
      // print('[ChatScreen] Message ID: ${message.id} (type: ${message.id.runtimeType})');
      // print('[ChatScreen] Chat ID: ${widget.chat.id} (type: ${widget.chat.id.runtimeType})');
      // print('[ChatScreen] Message Type: ${message.type}');
      // print('[ChatScreen] Sender ID: ${message.senderId}');
      // print('[ChatScreen] ========================================');
      
      // Получаем ключ сообщения для анимации
      final messageIdStr = message.id.toString();
      final messageKey = _messageKeys[messageIdStr];
      
      // Показываем анимацию частиц через Overlay
      if (messageKey != null && mounted) {
        // Помечаем сообщение как удаляемое (скроем его в UI)
        setState(() {
          _deletingMessages.add(messageIdStr);
        });
        
        OverlayEntry? overlayEntry;
        overlayEntry = OverlayEntry(
          builder: (context) => DeleteParticlesOverlay(
            messageKey: messageKey,
            onComplete: () {
              overlayEntry?.remove();
              setState(() {
                _deletingMessages.remove(message.id);
              });
              _performDelete(message, chatProvider, deleteForEveryone);
            },
          ),
        );
        Overlay.of(context).insert(overlayEntry);
        
        // Небольшая задержка для начала анимации
        await Future.delayed(const Duration(milliseconds: 50));
      } else {
        // Если нет ключа, удаляем сразу
        await _performDelete(message, chatProvider, deleteForEveryone);
      }
    } catch (e, stackTrace) {
      // print('[ChatScreen] ========================================');
      // print('[ChatScreen] ❌ ОШИБКА УДАЛЕНИЯ СООБЩЕНИЯ');
      // print('[ChatScreen] Error: $e');
      // print('[ChatScreen] Stack Trace: $stackTrace');
      // print('[ChatScreen] ========================================');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _performDelete(Message message, ChatProvider chatProvider, bool deleteForEveryone) async {
    try {
      // Если сообщение содержит файл, удаляем его с сервера
      if (message.type == 'image' || message.type == 'video' || message.type == 'file') {
        final metadata = message.metadata ?? {};
        final fileUrl = metadata['fileUrl'] ?? message.mediaUrl;
        
        if (fileUrl != null && fileUrl.isNotEmpty) {
          // print('[ChatScreen] 🗑️ Удаление файла с сервера: $fileUrl');
          try {
            final api = ApiService();
            await api.delete('/files/delete', data: {
              'fileUrl': fileUrl,
            });
            // print('[ChatScreen] ✅ Файл удален с сервера');
          } catch (e) {
            // print('[ChatScreen] ⚠️ Ошибка удаления файла с сервера: $e');
            // Продолжаем удаление сообщения даже если файл не удалился
          }
        }
      }
      
      // Удаляем сообщение через API
      final api = ApiService();
      // print('[ChatScreen] Вызов api.deleteMessage...');
      // print('[ChatScreen] Delete for everyone: $deleteForEveryone');
      final success = await api.deleteMessage(widget.chat.id, message.id, deleteForEveryone: deleteForEveryone);
      // print('[ChatScreen] Результат deleteMessage: $success');
      
      if (success) {
        // print('[ChatScreen] ✅ Сообщение удалено успешно');
        // Удаляем ключ сообщения
        final messageIdStr = message.id.toString();
        _messageKeys.remove(messageIdStr);
        
        if (deleteForEveryone) {
          // Если удалено для всех, обновляем список сообщений
          // print('[ChatScreen] Обновляем список сообщений (удалено для всех)...');
          await chatProvider.loadMessages(widget.chat.id);
        } else {
          // Если удалено только у меня, просто удаляем из локального списка
          // print('[ChatScreen] Удаляем сообщение из локального списка (только у меня)...');
          chatProvider.removeMessage(message.id);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(deleteForEveryone 
                  ? 'Сообщение удалено для всех' 
                  : 'Сообщение удалено у вас'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // print('[ChatScreen] ========================================');
      } else {
        // print('[ChatScreen] ❌ deleteMessage вернул false');
        // print('[ChatScreen] ========================================');
        throw Exception('Не удалось удалить сообщение');
      }
    } catch (e, stackTrace) {
      // print('[ChatScreen] ========================================');
      // print('[ChatScreen] ❌ ОШИБКА ПРИ УДАЛЕНИИ СООБЩЕНИЯ');
      // print('[ChatScreen] Error: $e');
      // print('[ChatScreen] Stack Trace: $stackTrace');
      // print('[ChatScreen] ========================================');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool _shouldShowDate(Message currentMessage, Message? previousMessage) {
    if (previousMessage == null) return true;

    final currentDate = DateTime.tryParse(currentMessage.timestamp);
    final previousDate = DateTime.tryParse(previousMessage.timestamp);

    if (currentDate == null || previousDate == null) return false;

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  String _formatDate(String timestamp) {
    final date = DateTime.tryParse(timestamp);
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Сегодня';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Вчера';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        await context.read<ChatProvider>().markMessagesAsRead(widget.chat.id);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: isDarkMode ? null : AppColors.primaryGradient,
            ),
          ),
          backgroundColor:
              isDarkMode ? AppColors.darkSurface : Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await context
                  .read<ChatProvider>()
                  .markMessagesAsRead(widget.chat.id);
              Navigator.pop(context);
            },
          ),
          title: Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.chat.avatarUrl == null
                          ? AppColors.primaryGradient
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPurple.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.transparent,
                      child: widget.chat.avatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: ImageUtils.getAvatarUrl(
                                        widget.chat.avatarUrl) ??
                                    '',
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                                placeholder: (context, url) => Container(
                                  decoration: BoxDecoration(
                                    gradient: widget.chat.avatarUrl == null
                                        ? AppColors.primaryGradient
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      widget.chat.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                                      widget.chat.name[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              widget.chat.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  if (widget.chat.isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.online,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chat.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        final typingUser =
                            chatProvider.getTypingUserName(widget.chat.id);
                        if (typingUser != null) {
                          return const Text(
                            'печатает...',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.white70,
                            ),
                          );
                        }
                        return Text(
                          widget.chat.isOnline ? 'В сети' : 'Не в сети',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.videocam),
              onPressed: () => _startCall('video'),
              tooltip: 'Видеозвонок',
            ),
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () => _startCall('audio'),
              tooltip: 'Аудиозвонок',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => _handleMenuAction(value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Пожаловаться'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Заблокировать'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppColors.getBackgroundGradient(context),
          ),
          child: Column(
            children: [
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, chatProvider, _) {
                    final messages = chatProvider.messages;
                    final isLoading = chatProvider.isLoading;

                    if (messages.length > _previousMessageCount &&
                        _previousMessageCount > 0) {
                      // print(                         // '[ChatScreen] 📜 Обнаружено новое сообщение в UI, прокручиваем вниз');
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _previousMessageCount = messages.length;
                        _scrollToBottom();
                      });
                    }

                    // // print(
                    //     '[ChatScreen] 🎨 Рендерим ${messages.length} сообщений');

                    if (isLoading && messages.isEmpty && !_messagesLoaded) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Загрузка сообщений...',
                              style: TextStyle(
                                color: AppColors.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                                boxShadow: [AppColors.primaryShadow],
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Нет сообщений',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Начните разговор!',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.getSecondaryTextColor(context),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                        final message = messages[index];
                        final previousMessage =
                            index > 0 ? messages[index - 1] : null;

                        return Column(
                          children: [
                            if (_shouldShowDate(message, previousMessage))
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? Colors.white12
                                        : Colors.black12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDate(message.timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.getSecondaryTextColor(
                                          context),
                                    ),
                                  ),
                                ),
                              ),
                            Builder(
                              builder: (context) {
                                // Создаем или получаем ключ для сообщения
                                // Используем строковый ключ для единообразия
                                final messageIdStr = message.id.toString();
                                if (!_messageKeys.containsKey(messageIdStr)) {
                                  _messageKeys[messageIdStr] = GlobalKey();
                                }
                                final messageKey = _messageKeys[messageIdStr]!;
                                final isDeleting = _deletingMessages.contains(messageIdStr);
                                final isRemoteDeleting = _remoteDeletedMessages.contains(messageIdStr);
                                
                                final isMe = message.senderId.toString() ==
                                    (chatProvider.currentUserId?.toString() ?? '');
                                
                                return Opacity(
                                  opacity: (isDeleting || isRemoteDeleting) ? 0.0 : 1.0,
                                  child: Container(
                                    key: messageKey,
                                    child: MessageBubble(
                                      message: message,
                                      isMe: isMe,
                                      currentUserId: chatProvider.currentUserId?.toString(), // ⭐ НОВОЕ: Передаем currentUserId
                                      allMessages: messages, // ⭐ НОВОЕ: Передаем все сообщения для сбора медиа
                                      onDelete: isMe
                                          ? (deleteForEveryone) => _deleteMessage(message, chatProvider, deleteForEveryone)
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    // ⭐⭐⭐ НОВОЕ: Кнопка прокрутки вниз
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        opacity: _showScrollToBottomButton ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: IgnorePointer(
                          ignoring: !_showScrollToBottomButton,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(28),
                            color: AppColors.primaryPurple,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: _scrollToBottom,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_downward,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                    );
                  },
                ),
              ),
              Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  final typingUser =
                      chatProvider.getTypingUserName(widget.chat.id);
                  if (typingUser != null) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          TypingIndicator(),
                          const SizedBox(width: 8),
                          Text(
                            '$typingUser печатает...',
                            style: TextStyle(
                              color: AppColors.getSecondaryTextColor(context),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // ⭐⭐⭐ НОВОЕ: Виджет записи голосовых сообщений
              if (_showVoiceRecorder)
                VoiceMessageRecorder(
                  onRecordingComplete: (filePath, duration) async {
                    await _sendVoiceMessage(filePath, duration);
                    setState(() {
                      _showVoiceRecorder = false;
                    });
                  },
                  onCancel: () {
                    setState(() {
                      _showVoiceRecorder = false;
                    });
                  },
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.getSurfaceColor(context),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.attach_file,
                          color: AppColors.primaryPurple,
                        ),
                        onPressed: _isSending ? null : _showAttachmentOptions,
                        tooltip: 'Прикрепить файл или фото',
                      ),
                      // ⭐⭐⭐ ИЗМЕНЕНО: Убрана кнопка микрофона, теперь используется меню при зажатии кнопки отправки
                      // Кнопка микрофона оставлена только для переключения на клавиатуру, если открыт рекордер
                      if (_showVoiceRecorder)
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard,
                            color: AppColors.primaryPurple,
                          ),
                          onPressed: () {
                            setState(() {
                              _showVoiceRecorder = false;
                            });
                          },
                          tooltip: 'Клавиатура',
                        ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.getInputColor(context),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                            ),
                            onChanged: (text) {
                              if (text.isNotEmpty) {
                                _handleTyping();
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'Сообщение',
                              hintStyle: TextStyle(
                                color: AppColors.getSecondaryTextColor(context),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ⭐⭐⭐ ИЗМЕНЕНО: Кнопка отправки с меню при нажатии (если поле пустое) или отправка (если есть текст)
                      Container(
                        decoration: BoxDecoration(
                          gradient: _messageController.text.trim().isEmpty
                              ? null
                              : AppColors.primaryGradient,
                          color: _messageController.text.trim().isEmpty
                              ? (isDarkMode ? Colors.white24 : Colors.grey[300])
                              : null,
                          shape: BoxShape.circle,
                          boxShadow: _messageController.text.trim().isEmpty
                              ? null
                              : [AppColors.primaryShadow],
                        ),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.send,
                                  color: _messageController.text.trim().isEmpty
                                      ? (isDarkMode
                                          ? Colors.white38
                                          : Colors.grey[600])
                                      : Colors.white,
                                  size: 20,
                                ),
                          onPressed: _isSending
                              ? null
                              : (_messageController.text.trim().isEmpty
                                  ? () => _showSendOptions(context) // Показываем меню, если поле пустое
                                  : _sendMessage), // Отправляем сообщение, если есть текст
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ⭐⭐⭐ НОВОЕ: Отправка голосового сообщения
  Future<void> _sendVoiceMessage(String filePath, int duration) async {
    try {
      setState(() {
        _isSending = true;
      });

      final file = File(filePath);
      final fileBytes = await file.readAsBytes();
      final base64File = base64Encode(fileBytes);
      final fileName = path.basename(filePath);

      // Формируем data URL
      final dataUrl = 'data:audio/m4a;base64,$base64File';

      // Загружаем файл на сервер
      final api = ApiService();
      final response = await api.post('/files/upload', data: {
        'file': dataUrl,
        'filename': fileName,
        'fileType': 'audio/m4a',
      });

      if (response['success'] == true) {
        final fileUrl = response['fileUrl'];
        // print('[ChatScreen] ✅ Голосовое сообщение загружено: $fileUrl');

        // Отправляем через WebSocket
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.sendMessage(
          '', // Пустой текст, так как это голосовое сообщение
          chatId: widget.chat.id,
          type: 'voice',
          metadata: {
            'fileUrl': fileUrl,
            'fileName': fileName,
            'fileSize': fileBytes.length,
            'fileType': 'audio/m4a',
            'mediaUrl': fileUrl,
            'duration': duration, // Длительность в секундах
          },
        );

        // Удаляем временный файл
        try {
          await file.delete();
        } catch (e) {
          // print('[ChatScreen] ⚠️ Ошибка удаления временного файла: $e');
        }

        if (mounted) {
          setState(() {
            _isSending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Голосовое сообщение отправлено'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception(response['error'] ?? 'Ошибка загрузки голосового сообщения');
      }
    } catch (e) {
      // print('[ChatScreen] ❌ Ошибка отправки голосового сообщения: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки голосового сообщения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
