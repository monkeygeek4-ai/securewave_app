// lib/providers/chat_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_manager.dart';
import '../services/title_notification_service.dart';
import '../services/media_storage_service.dart';
import '../services/fcm_service.dart';

// ⭐ ИСПРАВЛЕНО: Условный импорт для Web и Mobile
// Этот файл будет выбран автоматически в зависимости от платформы
import 'web_visibility_stub.dart'
    if (dart.library.html) 'web_visibility_web.dart'
    if (dart.library.io) 'web_visibility_mobile.dart';

class ChatProvider with ChangeNotifier, WidgetsBindingObserver {
  final ApiService _api = ApiService.instance;
  final WebSocketManager _wsManager = WebSocketManager.instance;

  List<Chat> _chats = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentChatId;
  String? _currentUserId;
  final Map<String, bool> _typingStatus = {};
  bool _isWindowFocused = true;
  final Set<String> _locallyDeletedMessages = {}; // Локально удаленные сообщения (только у меня)
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed; // ⭐⭐⭐ НОВОЕ: Отслеживаем состояние приложения
  
  // ⭐⭐⭐ НОВОЕ: Отслеживание времени последнего перехода из background в foreground
  // Это нужно для предотвращения дублирования уведомлений при открытии приложения из фона
  DateTime? _lastResumedFromBackground;

  StreamSubscription? _wsSubscription;
  StreamSubscription? _focusSubscription;
  StreamSubscription? _blurSubscription;

  Function(Map<String, dynamic>)? _onIncomingCall;

  List<Chat> get chats => _chats;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentChatId => _currentChatId;
  String? get currentUserId => _currentUserId;

  ChatProvider() {
    // print('[ChatProvider] ========================================');
    // print('[ChatProvider] Конструктор ChatProvider вызван');
    // print('[ChatProvider] ========================================');
    _subscribeToWebSocket();
    _subscribeToAppLifecycle();
    // ⭐⭐⭐ НОВОЕ: Регистрируем observer для отслеживания lifecycle на мобильных платформах
    if (!kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
    }
  }
  
  @override
  void dispose() {
    // ⭐⭐⭐ НОВОЕ: Удаляем observer при dispose
    if (!kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _wsSubscription?.cancel();
    _focusSubscription?.cancel();
    _blurSubscription?.cancel();
    super.dispose();
  }
  
  // ⭐⭐⭐ НОВОЕ: Обработка изменений lifecycle приложения
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    
    _appLifecycleState = state; // ⭐⭐⭐ НОВОЕ: Сохраняем состояние приложения
    
    _log('========================================');
    _log('📱 AppLifecycleState изменился: $state');
    _log('========================================');
    
    if (state == AppLifecycleState.resumed) {
      // ⭐⭐⭐ КРИТИЧНО: Запоминаем время перехода из background в foreground
      // Это нужно для предотвращения дублирования уведомлений
      _lastResumedFromBackground = DateTime.now();
      _log('✅ Приложение перешло в resumed (foreground)');
      _log('   Время: $_lastResumedFromBackground');
      _log('   Уведомления будут скрыты в течение 5 секунд');
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _log('📱 Приложение перешло в background/inactive');
    } else if (state == AppLifecycleState.detached) {
      _log('📱 Приложение detached');
    }
  }

  void _log(String message) {
    // ⭐⭐⭐ ВКЛЮЧЕНО: Ключевые логи для отладки
    print('[ChatProvider] $message');
  }

  void _subscribeToWebSocket() {
    // print('[ChatProvider] ========================================');
    // print('[ChatProvider] Инициализация подписки на WebSocket');
    // print('[ChatProvider] ========================================');

    _wsSubscription?.cancel();

    // ⭐⭐⭐ НОВОЕ: Устанавливаем callback для получения currentChatId
    // Это нужно для отправки join_chat сразу после авторизации
    _wsManager.setCurrentChatIdCallback(() => _currentChatId);

    // print('[ChatProvider] 🔌 Подписываемся на WebSocketManager.messages...');

    _wsSubscription = _wsManager.messages.listen(
      (data) async {
        // print('[ChatProvider] ========================================');
        // print('[ChatProvider] 📨 ПОЛУЧЕНО СООБЩЕНИЕ ОТ WEBSOCKET!');
        // print('[ChatProvider] Тип: ${data['type']}');
        // print('[ChatProvider] Полные данные: $data');
        // print('[ChatProvider] ========================================');

        // ⭐⭐⭐ ДИАГНОСТИКА: Логируем ВСЕ типы сообщений для отладки
        if (data['type'] != 'pong' && data['type'] != 'ping') {
          _log('🔍 Получено сообщение типа: ${data['type']}');
          if (data['type'] == 'new_message' || data['type'] == 'message' || data['type'] == 'chat_message') {
            _log('⚠️⚠️⚠️ ЭТО СООБЩЕНИЕ! Должно обработаться!');
          }
        }

        await _handleWebSocketMessage(data);
      },
      onError: (error) {
        // print('[ChatProvider] ❌ ОШИБКА в WebSocket подписке: $error');
      },
      cancelOnError: false,
    );

    // print('[ChatProvider] ✅ Подписка на WebSocket активирована');
    // print('[ChatProvider] ========================================');
  }

  // ⭐ ИСПРАВЛЕНО: Используем условную функцию вместо прямого импорта html
  void _subscribeToAppLifecycle() {
    if (kIsWeb) {
      try {
        _log('🌐 Настройка Web lifecycle listeners');

        // Используем функцию из условного импорта
        setupWebVisibilityListener(
          onFocus: () {
            _isWindowFocused = true;
            _log('🔍 Окно в фокусе');

            // Сбрасываем уведомления ТОЛЬКО если есть что сбрасывать
            if (TitleNotificationService.instance.unreadCount > 0) {
              TitleNotificationService.instance.clearUnread();
              _log('✅ Title notifications сброшены');
            }

            // Помечаем текущий чат как прочитанный
            if (_currentChatId != null) {
              final chatIndex =
                  _chats.indexWhere((c) => c.id == _currentChatId);
              if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
                _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
                notifyListeners();
              }
              markMessagesAsRead(_currentChatId!);
            }
          },
          onBlur: () {
            _isWindowFocused = false;
            _log('🔍 Окно потеряло фокус');
          },
          onVisibilityChange: (isVisible) {
            _isWindowFocused = isVisible;
            _log('📱 Видимость страницы: ${isVisible ? "видима" : "скрыта"}');

            if (isVisible) {
              // Сбрасываем уведомления ТОЛЬКО если есть что сбрасывать
              if (TitleNotificationService.instance.unreadCount > 0) {
                TitleNotificationService.instance.clearUnread();
                _log('✅ Title notifications сброшены при возврате на вкладку');
              }

              if (_currentChatId != null) {
                final chatIndex =
                    _chats.indexWhere((c) => c.id == _currentChatId);
                if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
                  _chats[chatIndex] =
                      _chats[chatIndex].copyWith(unreadCount: 0);
                  notifyListeners();
                }
                markMessagesAsRead(_currentChatId!);
              }
            }
          },
        );

        _log('✅ Window focus listeners инициализированы');
      } catch (e) {
        _log('⚠️ Ошибка инициализации focus listeners: $e');
      }
    } else {
      _log('📱 Mobile платформа - Web visibility listeners не нужны');
    }
  }

  void setIncomingCallHandler(Function(Map<String, dynamic>) handler) {
    _onIncomingCall = handler;
  }

  Future<void> _handleWebSocketMessage(Map<String, dynamic> data) async {
    final type = data['type'];

    _log('========================================');
    _log('🔍 _handleWebSocketMessage вызван');
    _log('Тип сообщения: $type');
    _log('========================================');

    switch (type) {
      case 'new_message':
      case 'message':
      case 'chat_message':
        _log('✅✅✅ ЭТО NEW_MESSAGE! Вызываем _handleNewMessage');
        _log('Данные сообщения: $data');
        await _handleNewMessage(data);
        break;
      case 'message_read':
        // print('[ChatProvider] ✅ Обработка message_read');
        _handleMessageRead(data);
        break;
      case 'typing':
        // print('[ChatProvider] ⌨️ Обработка typing');
        _handleTyping(data);
        break;
      case 'stopped_typing':
        // print('[ChatProvider] ⌨️ Обработка stopped_typing');
        _handleStoppedTyping(data);
        break;
      case 'chat_created':
        // print('[ChatProvider] 💬 Обработка chat_created');
        _handleChatCreated(data);
        break;
      case 'chat_deleted':
        // print('[ChatProvider] 🗑️ Обработка chat_deleted');
        _handleChatDeleted(data);
        break;
      case 'message_sent':
        // print('[ChatProvider] ✉️ Обработка message_sent');
        await _handleMessageSent(data);
        break;
      case 'user_online':
        // print('[ChatProvider] 🟢 Обработка user_online');
        _handleUserOnline(data);
        break;
      case 'user_offline':
        // print('[ChatProvider] 🔴 Обработка user_offline');
        _handleUserOffline(data);
        break;
      case 'message_deleted':
        // print('[ChatProvider] 🗑️ Обработка message_deleted');
        _handleMessageDeleted(data);
        break;
      case 'auth_success':
        // print('[ChatProvider] ✅ Обработка auth_success - загружаем чаты');
        loadChats();
        
        // ⭐⭐⭐ ИСПРАВЛЕНО: join_chat теперь отправляется СРАЗУ в _handleAuthSuccess
        // в WebSocketManager, до отправки auth_success в _messageController
        // Это гарантирует, что join_chat обработается до получения новых сообщений
        _log('✅ auth_success обработан, join_chat должен быть уже отправлен в WebSocketManager');
        break;
      case 'incoming_call':
        // print('[ChatProvider] 📞 Обработка incoming_call');
        _handleIncomingCall(data);
        break;
      // ⭐⭐⭐ КРИТИЧНО: call_* сообщения обрабатываются WebRTCService, не здесь
      // НЕ перехватываем их, чтобы они дошли до WebRTCService
      case 'call_offer':
      case 'call_answer':
      case 'call_ice_candidate':
      case 'call_ended':
      case 'call_declined':
      case 'call_connected':
      case 'call_heartbeat':
        // print('[ChatProvider] ⏭️ Пропускаем $type - обрабатывается WebRTCService');
        // НЕ обрабатываем, пусть WebRTCService получит это сообщение
        break;
      default:
        // print('[ChatProvider] ⚠️ Неизвестный тип сообщения: $type');
        break;
    }

    // print('[ChatProvider] ========================================');
    // print('[ChatProvider] ✅ _handleWebSocketMessage завершен');
    // print('[ChatProvider] ========================================');
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (_onIncomingCall != null) {
      _onIncomingCall!(data);
    }
  }

  Future<void> _handleNewMessage(Map<String, dynamic> data) async {
    _log('========================================');
    _log('🔔 _handleNewMessage вызван!');
    _log('Data: $data');
    _log('_isWindowFocused: $_isWindowFocused');
    _log('_currentUserId: $_currentUserId');
    _log('========================================');

    try {
      Map<String, dynamic>? messageData;

      if (data.containsKey('message')) {
        messageData = data['message'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['message'] as Map<String, dynamic>)
            : null;
      } else if (data.containsKey('data')) {
        messageData = data['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(data['data'] as Map<String, dynamic>)
            : null;
      } else {
        messageData = Map<String, dynamic>.from(data);
      }

      // ⭐⭐⭐ КРИТИЧНО: Если chatId есть на верхнем уровне, добавляем его в messageData
      // Это нужно для случаев, когда chatId передается отдельно от message
      if (messageData != null && data.containsKey('chatId')) {
        // ⭐⭐⭐ ИСПРАВЛЕНО: Всегда устанавливаем chatId из верхнего уровня, если он есть
        final topLevelChatId = data['chatId']?.toString() ?? '';
        if (topLevelChatId.isNotEmpty) {
          messageData['chatId'] = topLevelChatId;
          _log('✅ chatId установлен из верхнего уровня: $topLevelChatId');
        }
      }

      _log('messageData: $messageData');

      if (messageData == null) {
        _log('❌ messageData is NULL, возвращаемся');
        return;
      }

      // ⭐⭐⭐ КРИТИЧНО: Проверяем, что chatId установлен перед созданием Message
      if (!messageData.containsKey('chatId') || messageData['chatId'] == null || messageData['chatId'].toString().isEmpty) {
        // Пытаемся получить chatId из верхнего уровня еще раз
        if (data.containsKey('chatId')) {
          final topLevelChatId = data['chatId']?.toString() ?? '';
          if (topLevelChatId.isNotEmpty) {
            messageData['chatId'] = topLevelChatId;
            _log('✅ chatId установлен из верхнего уровня (fallback): $topLevelChatId');
          }
        }
      }

      final message = Message.fromJson(messageData);

      _log('📨 Message parsed:');
      _log('  - ID: ${message.id}');
      _log('  - ChatID: ${message.chatId}');
      _log('  - SenderID: ${message.senderId}');
      _log('  - SenderName: ${message.senderName}');
      _log('  - Content: ${message.content}');

      // Проверяем что сообщение не от текущего пользователя
      final isFromMe = message.senderId == _currentUserId;

      _log('isFromMe: $isFromMe (${message.senderId} == $_currentUserId)');

      if (!isFromMe) {
        _log(
            '💬 Входящее сообщение от: ${message.senderName ?? message.senderId}');

        _log('Проверка условий для уведомления:');
        _log('  - kIsWeb: $kIsWeb');
        _log('  - _isWindowFocused: $_isWindowFocused');
        _log('  - !_isWindowFocused: ${!_isWindowFocused}');
        _log('  - _currentChatId: $_currentChatId');
        _log('  - message.chatId: ${message.chatId}');

        // ⭐⭐⭐ ИСПРАВЛЕНО: Показываем локальное уведомление для iOS/Android
        // если чат не открыт (пользователь не видит сообщение)
        // ⭐⭐⭐ КРИТИЧНО: Нормализуем chatId для корректного сравнения
        final currentChatIdNormalized = _currentChatId?.trim();
        final messageChatIdNormalized = message.chatId.trim();
        final isCurrentChat = currentChatIdNormalized != null && 
                             currentChatIdNormalized.isNotEmpty &&
                             currentChatIdNormalized == messageChatIdNormalized;
        
        _log('========================================');
        _log('🔍 ПРОВЕРКА: Нужно ли показывать уведомление?');
        _log('  - _currentChatId: "$currentChatIdNormalized"');
        _log('  - message.chatId: "$messageChatIdNormalized"');
        _log('  - isCurrentChat: $isCurrentChat');
        _log('  - Типы: ${currentChatIdNormalized.runtimeType} == ${messageChatIdNormalized.runtimeType}');
        _log('========================================');

        // ⭐⭐⭐ НОВОЕ: Проверяем состояние приложения - НЕ показываем уведомления в foreground
        final isAppInForeground = _appLifecycleState == AppLifecycleState.resumed;
        
        // Показываем уведомление ТОЛЬКО если:
        // - Приложение НЕ в foreground (background/terminated)
        // - Для Web: окно не в фокусе И чат не открыт
        // - Для Mobile: чат не открыт
        if (isAppInForeground) {
          _log('========================================');
          _log('⏸️ ПРИЛОЖЕНИЕ В FOREGROUND - уведомление НЕ показано');
          _log('   AppLifecycleState: $_appLifecycleState');
          _log('   Пользователь видит приложение');
          _log('========================================');
          // ⭐⭐⭐ НЕ return - продолжаем обработку сообщения для отображения в UI
          // Просто не показываем уведомление
        } else if (kIsWeb) {
          // ⭐⭐⭐ НОВОЕ: Для Web тоже проверяем, открыт ли чат
          if (!_isWindowFocused && !isCurrentChat) {
          final senderName = message.senderName ?? 'Пользователь';
          final messagePreview = message.content.length > 50
              ? '${message.content.substring(0, 50)}...'
              : message.content;

          _log('🎯 ВЫЗЫВАЕМ incrementUnread!');
          _log('  - Sender: $senderName');
          _log('  - Preview: $messagePreview');

          // Уведомление в title браузера
          TitleNotificationService.instance
              .incrementUnread(message: '$senderName: $messagePreview');

            _log('🔔 Title notification показан (окно не в фокусе и чат не открыт)');
          } else if (isCurrentChat) {
            _log('========================================');
            _log('⏸️ ЧАТ ОТКРЫТ - уведомление НЕ показано');
            _log('   Пользователь видит сообщение в открытом чате');
            _log('========================================');
          } else {
          _log('ℹ️ Окно в фокусе - уведомление не показано');
          }
        } else {
          // ⭐⭐⭐ ИСПРАВЛЕНО: Для iOS/Android показываем локальное уведомление
          // если чат не открыт (пользователь не видит сообщение)
          // ⭐⭐⭐ НОВОЕ: НЕ показываем уведомление, если приложение только что открылось из фона
          // (в течение 5 секунд после перехода в foreground)
          // Это предотвращает дублирование уведомлений, которые уже были показаны через push
          final shouldSuppressNotification = _lastResumedFromBackground != null &&
              DateTime.now().difference(_lastResumedFromBackground!).inSeconds < 5;
          
          // ⭐⭐⭐ КРИТИЧНО: Дополнительная проверка - если _currentChatId NULL или пустой,
          // это значит, что чат точно не открыт
          // ⭐⭐⭐ ИСПРАВЛЕНО: Используем только isCurrentChat для проверки
          // Если chatId совпадает - чат открыт, уведомление не показываем
          
          _log('========================================');
          _log('🔍 ФИНАЛЬНАЯ ПРОВЕРКА для Mobile:');
          _log('   isCurrentChat: $isCurrentChat');
          _log('   _currentChatId: "$currentChatIdNormalized"');
          _log('   message.chatId: "$messageChatIdNormalized"');
          _log('   shouldSuppressNotification: $shouldSuppressNotification');
          _log('========================================');
          
          // ⭐⭐⭐ КРИТИЧНО: Если чат открыт - НЕ показываем уведомление и НЕ обрабатываем дальше
          if (isCurrentChat) {
            _log('========================================');
            _log('⏸️ ЧАТ ОТКРЫТ - уведомление НЕ показано');
            _log('   _currentChatId: "$currentChatIdNormalized"');
            _log('   message.chatId: "$messageChatIdNormalized"');
            _log('   Пользователь видит сообщение в открытом чате');
            _log('========================================');
            // ⭐⭐⭐ НЕ return - продолжаем обработку сообщения для отображения в UI
            // Просто не показываем уведомление
          } else if (shouldSuppressNotification) {
            _log('========================================');
            _log('⏸️ ПРИОСТАНОВКА показа уведомления');
            _log('   Приложение только что открылось из фона');
            _log('   Время с момента открытия: ${DateTime.now().difference(_lastResumedFromBackground!).inSeconds} сек');
            _log('   Уведомление уже было показано через push');
            _log('   Пропускаем локальное уведомление');
            _log('========================================');
          } else {
            _log('========================================');
            _log('📱 Mobile: Чат НЕ открыт - показываем локальное уведомление');
            _log('   _currentChatId: "$currentChatIdNormalized"');
            _log('   message.chatId: "$messageChatIdNormalized"');
            _log('========================================');
            try {
              final fcmService = FCMService();
              await fcmService.showLocalMessageNotification(
                chatId: message.chatId,
                senderName: message.senderName ?? 'Пользователь',
                messageText: message.content,
              );
              _log('✅ Локальное уведомление показано');
            } catch (e) {
              _log('❌ Ошибка показа локального уведомления: $e');
            }
          }
        }
      } else {
        _log('ℹ️ Сообщение от себя, пропускаем уведомление');
      }

      if (_currentChatId == message.chatId) {
        // ⭐⭐⭐ ИСПРАВЛЕНО: Ищем сообщение по ID или по tempId для замены временного сообщения
        // Также проверяем по типу и метаданным для голосовых сообщений
        final existingIndex = _messages.indexWhere((m) {
          // Точное совпадение ID
          if (m.id == message.id) return true;
          
          // Совпадение по tempId в метаданных
          if (m.id.startsWith('temp_') && message.metadata?['tempId'] == m.id) return true;
          
          // Для голосовых сообщений: проверяем по типу, senderId и timestamp (в пределах 5 секунд)
          if (message.type == 'voice' && m.type == 'voice' && 
              m.senderId == message.senderId) {
            try {
              final mTime = DateTime.parse(m.timestamp);
              final msgTime = DateTime.parse(message.timestamp);
              final diff = msgTime.difference(mTime).abs();
              if (diff.inSeconds < 5) {
                // Проверяем совпадение fileUrl в метаданных
                final mFileUrl = m.metadata?['fileUrl'] ?? m.metadata?['mediaUrl'];
                final msgFileUrl = message.metadata?['fileUrl'] ?? message.metadata?['mediaUrl'];
                if (mFileUrl != null && msgFileUrl != null && mFileUrl == msgFileUrl) {
                  return true;
                }
              }
            } catch (e) {
              // Игнорируем ошибки парсинга времени
            }
          }
          
          return false;
        });

        if (existingIndex == -1) {
          _messages.add(message);
          _log('✅ Сообщение добавлено в список');
        } else {
          // Заменяем временное сообщение на реальное
          _messages[existingIndex] = message;
          _log('✅ Сообщение обновлено в списке (заменено временное)');
        }
      }

      final chatIndex = _chats.indexWhere((c) => c.id == message.chatId);
      if (chatIndex != -1) {
        final isCurrentChat = _currentChatId == message.chatId;

        // ⭐⭐⭐ ИСПРАВЛЕНО: Для голосовых сообщений показываем специальный текст
        String lastMessageText = message.content;
        if (message.type == 'voice') {
          lastMessageText = '🎤 Голосовое сообщение';
        } else if (message.type == 'image') {
          lastMessageText = '📷 Фото';
        } else if (message.type == 'video') {
          lastMessageText = '🎥 Видео';
        } else if (message.type == 'file') {
          lastMessageText = '📎 Файл';
        } else if (message.type == 'call') {
          lastMessageText = '📞 Звонок';
        }
        
        _chats[chatIndex] = _chats[chatIndex].copyWith(
          lastMessage: lastMessageText,
          lastMessageTime: DateTime.parse(message.timestamp),
          unreadCount: isCurrentChat ? 0 : (_chats[chatIndex].unreadCount + 1),
        );

        final chat = _chats.removeAt(chatIndex);
        _chats.insert(0, chat);

        _log('✅ Чат обновлен');
      }

      notifyListeners();

      if (_currentChatId == message.chatId && _isWindowFocused) {
        markMessagesAsRead(message.chatId);
      }

      // ⭐⭐⭐ АВТОМАТИЧЕСКАЯ ЗАГРУЗКА ИЗОБРАЖЕНИЙ
      if (message.type == 'image' || message.type == 'video') {
        _autoDownloadMedia(message);
      }

      _log('========================================');
    } catch (e) {
      _log('❌ Ошибка обработки нового сообщения: $e');
      _log('Stack trace: ${StackTrace.current}');
    }
  }

  bool isUserTyping(String chatId) {
    return _typingStatus[chatId] ?? false;
  }

  void togglePinChat(String chatId) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        isPinned: !_chats[chatIndex].isPinned,
      );

      // Закрепление чатов отключено на уровне UI, но метод оставлен для совместимости.
      // Сортировку по isPinned убираем, чтобы закрепленные флаги (если пришли с бэка)
      // не влияли на порядок отображения.

      notifyListeners();
    }
  }

  void _handleTyping(Map<String, dynamic> data) {
    final chatId = data['chatId'] ?? data['chat_id'];
    if (chatId != null) {
      _typingStatus[chatId] = true;
      notifyListeners();

      Future.delayed(const Duration(seconds: 3), () {
        _typingStatus[chatId] = false;
        notifyListeners();
      });
    }
  }

  void _handleStoppedTyping(Map<String, dynamic> data) {
    final chatId = data['chatId'] ?? data['chat_id'];
    if (chatId != null) {
      _typingStatus[chatId] = false;
      notifyListeners();
    }
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    // Обработка прочтения сообщения
  }

  void _handleChatCreated(Map<String, dynamic> data) {
    try {
      final chat = Chat.fromJson(data['chat']);
      _chats.insert(0, chat);
      notifyListeners();
    } catch (e) {
      _log('Ошибка обработки создания чата: $e');
    }
  }

  void _handleChatDeleted(Map<String, dynamic> data) {
    final chatId = data['chatId'];
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();
  }

  Future<void> _handleMessageSent(Map<String, dynamic> data) async {
    await _handleNewMessage(data);
  }

  void _handleUserOnline(Map<String, dynamic> data) {
    // Обработка статуса онлайн
  }

  void _handleUserOffline(Map<String, dynamic> data) {
    // Обработка статуса оффлайн
  }
  
  // Set для отслеживания файлов, которые уже загружаются
  final Set<String> _downloadingUrls = {};
  final Set<String> _checkedChatsForAutoDownload = {}; // Чats, для которых уже проверена автозагрузка
  
  // Автоматическая загрузка медиафайлов
  Future<void> _autoDownloadMedia(Message message) async {
    try {
      // Проверяем, включена ли автозагрузка
      final autoDownload = await MediaStorageService.instance.getAutoDownload();
      if (!autoDownload) {
        return;
      }
      
      // Получаем URL изображения/видео
      final metadata = message.metadata ?? {};
      final imageUrl = metadata['fileUrl'] ?? 
                      metadata['mediaUrl'] ?? 
                      message.mediaUrl ?? '';
      
      if (imageUrl.isEmpty) {
        return;
      }
      
      // Проверяем, не загружается ли уже
      if (_downloadingUrls.contains(imageUrl)) {
        // print('[ChatProvider] ⏳ Файл уже загружается: $imageUrl');
        return;
      }
      
      // Проверяем, не загружено ли уже (повторная проверка для надежности)
      final isDownloaded = await MediaStorageService.instance.isDownloaded(imageUrl);
      if (isDownloaded) {
        // print('[ChatProvider] ✅ Файл уже загружен, пропускаем: $imageUrl');
        return;
      }
      
      // Добавляем в список загружающихся
      _downloadingUrls.add(imageUrl);
      // print('[ChatProvider] 📥 Автоматическая загрузка медиа: $imageUrl');
      
      // Загружаем в фоне
      MediaStorageService.instance.downloadImage(
        imageUrl,
        fileName: metadata['fileName'] as String?,
      ).then((success) {
        _downloadingUrls.remove(imageUrl);
        if (success) {
          // print('[ChatProvider] ✅ Медиафайл автоматически загружен');
          // НЕ вызываем notifyListeners() здесь, чтобы избежать бесконечного цикла
          // UI обновится автоматически через FutureBuilder в MessageBubble
        } else {
          // print('[ChatProvider] ⚠️ Не удалось автоматически загрузить медиафайл');
        }
      }).catchError((e) {
        _downloadingUrls.remove(imageUrl);
        // print('[ChatProvider] ❌ Ошибка автоматической загрузки: $e');
      });
    } catch (e) {
      // print('[ChatProvider] ❌ Ошибка _autoDownloadMedia: $e');
    }
  }

  void setUserId(int userId) {
    _currentUserId = userId.toString();
    _log('setUserId: $_currentUserId');
    loadChats();
  }

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    _log('setCurrentUserId: $_currentUserId');
  }

  // Удалить сообщение из локального списка (без перезагрузки)
  void removeMessage(String messageId) {
    _messages.removeWhere((msg) => msg.id == messageId);
    // Добавляем в список локально удаленных, чтобы оно не вернулось при автообновлении
    _locallyDeletedMessages.add(messageId);
    notifyListeners();
  }

  // Обработка удаления сообщения через WebSocket (от другого пользователя)
  void _handleMessageDeleted(Map<String, dynamic> data) {
    try {
      final chatId = data['chatId'] as String?;
      // messageId может быть строкой или числом, приводим к строке для сравнения
      final messageIdRaw = data['messageId'];
      final messageId = messageIdRaw?.toString();
      final deletedBy = data['deletedBy'];

      _log('🗑️ Сообщение удалено другим пользователем');
      _log('  - Chat ID: $chatId');
      _log('  - Message ID (raw): $messageIdRaw (type: ${messageIdRaw.runtimeType})');
      _log('  - Message ID (string): $messageId');
      _log('  - Deleted by: $deletedBy');
      _log('  - Current chat ID: $_currentChatId');
      _log('  - Messages count: ${_messages.length}');

      if (chatId == null || messageId == null) {
        _log('⚠️ Недостаточно данных для удаления сообщения');
        return;
      }

      // Проверяем, существует ли сообщение в текущем чате
      if (chatId == _currentChatId) {
        // Проверяем, существует ли сообщение (сравниваем как строки)
        final messageExists = _messages.any((msg) => msg.id.toString() == messageId);
        
        _log('  - Message exists: $messageExists');
        if (messageExists) {
          // Находим сообщение для анимации ПЕРЕД удалением
          final messageToDelete = _messages.firstWhere(
            (msg) => msg.id.toString() == messageId,
            orElse: () => _messages.first, // fallback, но не должен использоваться
          );
          
          _log('  - Found message: ${messageToDelete.id} (type: ${messageToDelete.id.runtimeType})');
          
          // Удаляем сообщение из списка
          _messages.removeWhere((msg) => msg.id.toString() == messageId);
          notifyListeners();

          // Уведомляем UI о необходимости показать анимацию
          // Это будет обработано в ChatScreen через callback
          _log('  - Notifying UI to show animation for message: $messageId');
          _notifyMessageDeletedForAnimation(messageId);
        } else {
          _log('⚠️ Сообщение $messageId не найдено в списке');
          _log('  - Available message IDs: ${_messages.map((m) => m.id.toString()).take(10).join(", ")}');
        }
      } else {
        // Если это не текущий чат, просто логируем
        _log('📨 Получено уведомление об удалении сообщения в другом чате: $chatId');
      }
    } catch (e, stackTrace) {
      _log('❌ Ошибка обработки message_deleted: $e');
      _log('  Stack trace: $stackTrace');
    }
  }

  // Callback для уведомления об удалении сообщения (для анимации)
  Function(String messageId)? _onMessageDeletedForAnimation;

  void setOnMessageDeletedForAnimation(Function(String messageId)? callback) {
    _onMessageDeletedForAnimation = callback;
  }

  void _notifyMessageDeletedForAnimation(String messageId) {
    if (_onMessageDeletedForAnimation != null) {
      _onMessageDeletedForAnimation!(messageId);
    }
  }

  void setCurrentChatId(String? chatId) {
    // ⭐⭐⭐ КРИТИЧНО: Нормализуем chatId перед сравнением
    final normalizedNewChatId = chatId?.trim();
    final normalizedCurrentChatId = _currentChatId?.trim();
    
    if (normalizedNewChatId == normalizedCurrentChatId) {
      _log('setCurrentChatId: пропуск (уже установлен): $normalizedNewChatId');
      return;
    }

    final previousChatId = _currentChatId;

    // ⭐⭐⭐ НОВОЕ: Уведомляем backend о закрытии предыдущего чата
    if (previousChatId != null && previousChatId != chatId) {
      _wsManager.leaveChat(previousChatId);
      _log('📤 Отправлено leave_chat для чата: $previousChatId');
    }

    if (previousChatId != null && previousChatId != chatId) {
      _messages.clear();
      // Очищаем список локально удаленных сообщений при смене чата
      _locallyDeletedMessages.clear();
    }

    // ⭐⭐⭐ КРИТИЧНО: Сохраняем нормализованный chatId
    _currentChatId = normalizedNewChatId;
    _log('========================================');
    _log('✅ setCurrentChatId ВЫЗВАН');
    _log('   Новый chatId: "$normalizedNewChatId"');
    _log('   Предыдущий chatId: "$previousChatId"');
    _log('   _currentChatId теперь: "$_currentChatId"');
    _log('========================================');

    if (chatId != null && normalizedNewChatId != null) {
      // ⭐⭐⭐ НОВОЕ: Уведомляем backend об открытии чата
      _wsManager.joinChat(normalizedNewChatId);
      _log('📤 Отправлено join_chat для чата: $normalizedNewChatId');

      final chatIndex = _chats.indexWhere((c) => c.id == normalizedNewChatId);
      if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
        _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
      }

      // Сбрасываем уведомления ТОЛЬКО если есть что сбрасывать
      if (kIsWeb && TitleNotificationService.instance.unreadCount > 0) {
        TitleNotificationService.instance.clearUnread();
        _log('✅ Title notifications сброшены при открытии чата');
      }

      markMessagesAsRead(normalizedNewChatId);
    }

    notifyListeners();
  }

  Future<void> loadChats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _chats = await _api.getChats();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _log('Ошибка загрузки чатов: $e');
      _errorMessage = 'Не удалось загрузить чаты';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String chatId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allMessages = await _api.getMessages(chatId);
      
      // Фильтруем локально удаленные сообщения (только у меня)
      _messages = allMessages.where((msg) => !_locallyDeletedMessages.contains(msg.id)).toList();
      
      _isLoading = false;
      notifyListeners();
      
      // ⭐⭐⭐ АВТОМАТИЧЕСКАЯ ЗАГРУЗКА ИЗОБРАЖЕНИЙ ДЛЯ ЗАГРУЖЕННЫХ СООБЩЕНИЙ
      // Вызываем только один раз для каждого чата
      if (!_checkedChatsForAutoDownload.contains(chatId)) {
        _checkedChatsForAutoDownload.add(chatId);
        _autoDownloadMediaForLoadedMessages();
      }
    } catch (e) {
      _log('Ошибка загрузки сообщений: $e');
      _errorMessage = 'Не удалось загрузить сообщения';
      _isLoading = false;
      _messages = [];
      notifyListeners();
    }
  }
  
  // Автоматическая загрузка медиафайлов для загруженных сообщений
  Future<void> _autoDownloadMediaForLoadedMessages() async {
    try {
      final autoDownload = await MediaStorageService.instance.getAutoDownload();
      if (!autoDownload) {
        // print('[ChatProvider] ⏭️ Автозагрузка отключена, пропускаем');
        return;
      }
      
      // print('[ChatProvider] 🔍 Проверка медиафайлов для ${_messages.length} сообщений');
      
      // Загружаем изображения для всех сообщений с медиа
      for (final message in _messages) {
        if (message.type == 'image' || message.type == 'video') {
          final metadata = message.metadata ?? {};
          final imageUrl = metadata['fileUrl'] ??
              metadata['mediaUrl'] ??
              message.mediaUrl ??
              '';
          
          if (imageUrl.isEmpty) {
            // print('[ChatProvider] ⚠️ Пустой URL для сообщения ${message.id}');
            continue;
          }
          
          // Проверяем, не загружается ли уже
          if (_downloadingUrls.contains(imageUrl)) {
            // print('[ChatProvider] ⏳ Файл уже загружается: $imageUrl');
            continue;
          }
          
          // Проверяем, не загружено ли уже
          final isDownloaded = await MediaStorageService.instance.isDownloaded(imageUrl);
          if (isDownloaded) {
            // print('[ChatProvider] ✅ Файл уже загружен, пропускаем: $imageUrl');
            continue;
          }
          
          // print('[ChatProvider] 📥 Начинаем загрузку: $imageUrl');
          _autoDownloadMedia(message);
        }
      }
    } catch (e) {
      // print('[ChatProvider] ❌ Ошибка автоматической загрузки для загруженных сообщений: $e');
    }
  }

  Future<void> sendMessage(String content,
      {String? chatId, String? replyToId, String? type, Map<String, dynamic>? metadata}) async {
    final targetChatId = chatId ?? _currentChatId;
    if (targetChatId == null) return;

    final messageType = type ?? 'text';

    // print('[ChatProvider] ========================================');
    // print('[ChatProvider] 📤 ОТПРАВКА СООБЩЕНИЯ ЧЕРЕЗ WEBSOCKET');
    // print('[ChatProvider] ChatID: $targetChatId');
    // print('[ChatProvider] Content: $content');
    // print('[ChatProvider] Type: $messageType');
    if (metadata != null) {
      // print('[ChatProvider] Metadata: $metadata');
    }
    // print('[ChatProvider] ========================================');

    try {
      // Генерируем временный ID для сообщения
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      // Отправляем через WebSocket
      final wsData = <String, dynamic>{
        'type': 'send_message',
        'chatId': targetChatId,
        'content': content,
        'tempId': tempId,
        'messageType': messageType,
      };
      
      if (metadata != null) {
        wsData['metadata'] = metadata;
      }
      
      _wsManager.send(wsData);

      // print('[ChatProvider] ✅ Сообщение отправлено через WebSocket');
      // print('[ChatProvider] TempID: $tempId');
      // print('[ChatProvider] ========================================');

      // Добавляем сообщение локально (оптимистичное обновление UI)
      final tempMessage = Message(
        id: tempId,
        chatId: targetChatId,
        senderId: _currentUserId ?? '',
        senderName: 'Вы',
        content: content,
        timestamp: DateTime.now().toIso8601String(),
        type: messageType,
        metadata: metadata,
        isRead: false,
      );

      if (_currentChatId == targetChatId) {
        _messages.add(tempMessage);
        notifyListeners();
      }

      // Обновляем чат в списке
      final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
      if (chatIndex != -1) {
        // ⭐⭐⭐ ИСПРАВЛЕНО: Для голосовых сообщений показываем специальный текст
        String lastMessageText = content;
        if (messageType == 'voice') {
          lastMessageText = '🎤 Голосовое сообщение';
        } else if (messageType == 'file') {
          lastMessageText = metadata?['fileName'] ?? 'Файл';
        } else if (messageType == 'image') {
          lastMessageText = '📷 Фото';
        } else if (messageType == 'video') {
          lastMessageText = '🎥 Видео';
        } else if (messageType == 'call') {
          lastMessageText = '📞 Звонок';
        }
        
        _chats[chatIndex] = _chats[chatIndex].copyWith(
          lastMessage: lastMessageText,
          lastMessageTime: DateTime.now(),
        );

        final chat = _chats.removeAt(chatIndex);
        _chats.insert(0, chat);
        notifyListeners();
      }
    } catch (e) {
      // print('[ChatProvider] ❌ Ошибка отправки сообщения: $e');
      _log('Ошибка отправки сообщения: $e');
      _errorMessage = 'Не удалось отправить сообщение';
      notifyListeners();
    }
  }

  Future<void> sendCallMessage(Message callMessage) async {
    try {
      final message = await _api.sendMessage(
        callMessage.chatId,
        callMessage.content,
        type: callMessage.type,
        metadata: callMessage.metadata,
      );

      if (message != null) {
        if (_currentChatId == callMessage.chatId) {
          _messages.add(message);
        }

        final chatIndex = _chats.indexWhere((c) => c.id == callMessage.chatId);
        if (chatIndex != -1) {
          _chats[chatIndex] = _chats[chatIndex].copyWith(
            lastMessage: message.content,
            lastMessageTime: DateTime.parse(message.timestamp),
          );

          final chat = _chats.removeAt(chatIndex);
          _chats.insert(0, chat);
        }

        notifyListeners();
      }
    } catch (e) {
      _log('Ошибка отправки сообщения о звонке: $e');
    }
  }

  Future<void> createOrGetChat(String userId) async {
    try {
      final chat = await _api.createChat(userId);

      if (chat != null) {
        final existingIndex = _chats.indexWhere((c) => c.id == chat.id);

        if (existingIndex == -1) {
          _chats.insert(0, chat);
        } else {
          _chats[existingIndex] = chat;
        }

        notifyListeners();
      }
    } catch (e) {
      _log('Ошибка создания/получения чата: $e');
      _errorMessage = 'Не удалось создать чат';
      notifyListeners();
    }
  }

  Future<void> createGroupChat(
      String groupName, List<String> participantIds) async {
    try {
      final chat = await _api.createGroupChat(groupName, participantIds);

      if (chat != null) {
        final existingIndex = _chats.indexWhere((c) => c.id == chat.id);

        if (existingIndex == -1) {
          _chats.insert(0, chat);
        } else {
          _chats[existingIndex] = chat;
        }

        await loadChats();
        notifyListeners();
      }
    } catch (e) {
      _log('Ошибка создания группового чата: $e');
      _errorMessage = 'Не удалось создать групповой чат';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteChat(String chatId, {bool deleteForEveryone = false}) async {
    try {
      final success = await _api.deleteChat(chatId, deleteForEveryone: deleteForEveryone);

      if (!success) {
        // Важно: если сервер не подтвердил удаление, не оставляем UI в состоянии
        // "как будто удалили" (когда содержимое исчезает, а чат остается).
        _errorMessage = 'Не удалось удалить чат';
        notifyListeners();
        throw Exception('Delete chat failed (api returned success=false)');
      }

      _chats.removeWhere((c) => c.id == chatId);

      if (_currentChatId == chatId) {
        _currentChatId = null;
        _messages.clear();
      }

      notifyListeners();
    } catch (e) {
      _log('Ошибка удаления чата: $e');
      _errorMessage = 'Не удалось удалить чат';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    try {
      await _api.markMessagesAsRead(chatId);
    } catch (e) {
      _log('Ошибка отметки сообщений как прочитанных: $e');
    }
  }

  Chat? getChatById(String chatId) {
    try {
      return _chats.firstWhere((c) => c.id == chatId);
    } catch (e) {
      return null;
    }
  }

  List<Message> getMessages(String chatId) {
    return _messages.where((m) => m.chatId == chatId).toList();
  }

  String? getTypingUserName(String chatId) {
    if (!isUserTyping(chatId)) return null;
    final chat = getChatById(chatId);
    if (chat == null) return null;
    return "Собеседник";
  }

  Future<void> sendTypingStatus(String chatId, bool isTyping) async {
    _wsManager.send({
      'type': isTyping ? 'typing' : 'stopped_typing',
      'chatId': chatId,
    });
  }
}
