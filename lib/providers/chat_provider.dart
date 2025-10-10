// lib/providers/chat_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_manager.dart';
import '../services/title_notification_service.dart';

// Условный импорт для Web
import 'dart:html' as html show window, document;

class ChatProvider with ChangeNotifier {
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
    print('[ChatProvider] ========================================');
    print('[ChatProvider] Конструктор ChatProvider вызван');
    print('[ChatProvider] ========================================');
    _subscribeToWebSocket();
    _subscribeToAppLifecycle();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ChatProvider] $message');
    }
  }

  void _subscribeToWebSocket() {
    print('[ChatProvider] ========================================');
    print('[ChatProvider] Инициализация подписки на WebSocket');
    print('[ChatProvider] ========================================');

    _wsSubscription?.cancel();

    print('[ChatProvider] 🔌 Подписываемся на WebSocketManager.messages...');

    _wsSubscription = _wsManager.messages.listen(
      (data) {
        print('[ChatProvider] ========================================');
        print('[ChatProvider] 📨 ПОЛУЧЕНО СООБЩЕНИЕ ОТ WEBSOCKET!');
        print('[ChatProvider] Тип: ${data['type']}');
        print('[ChatProvider] Полные данные: $data');
        print('[ChatProvider] ========================================');

        _handleWebSocketMessage(data);
      },
      onError: (error) {
        print('[ChatProvider] ❌ ОШИБКА в WebSocket подписке: $error');
      },
      cancelOnError: false,
    );

    print('[ChatProvider] ✅ Подписка на WebSocket активирована');
    print('[ChatProvider] ========================================');
  }

  void _subscribeToAppLifecycle() {
    if (kIsWeb) {
      try {
        // Слушаем focus
        html.window.onFocus.listen((_) {
          _isWindowFocused = true;
          _log('🔍 Окно в фокусе');

          // Сбрасываем уведомления ТОЛЬКО если есть что сбрасывать
          if (TitleNotificationService.instance.unreadCount > 0) {
            TitleNotificationService.instance.clearUnread();
            _log('✅ Title notifications сброшены');
          }

          // Помечаем текущий чат как прочитанный
          if (_currentChatId != null) {
            final chatIndex = _chats.indexWhere((c) => c.id == _currentChatId);
            if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
              _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
              notifyListeners();
            }
            markMessagesAsRead(_currentChatId!);
          }
        });

        // Слушаем blur
        html.window.onBlur.listen((_) {
          _isWindowFocused = false;
          _log('🔍 Окно потеряло фокус');
        });

        // Слушаем visibilitychange
        html.document.onVisibilityChange.listen((_) {
          final isVisible = !html.document.hidden!;
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
                _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
                notifyListeners();
              }
              markMessagesAsRead(_currentChatId!);
            }
          }
        });

        _log('✅ Window focus listeners инициализированы');
      } catch (e) {
        _log('⚠️ Ошибка инициализации focus listeners: $e');
      }
    }
  }

  void setIncomingCallHandler(Function(Map<String, dynamic>) handler) {
    _onIncomingCall = handler;
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    final type = data['type'];

    print('[ChatProvider] ========================================');
    print('[ChatProvider] 🔍 _handleWebSocketMessage вызван');
    print('[ChatProvider] Тип сообщения: $type');
    print('[ChatProvider] ========================================');

    _log('📨 Получено WS сообщение: $type');

    switch (type) {
      case 'new_message':
      case 'message':
      case 'chat_message':
        print('[ChatProvider] ✅ Это new_message! Вызываем _handleNewMessage');
        _handleNewMessage(data);
        break;
      case 'message_read':
        print('[ChatProvider] ✅ Обработка message_read');
        _handleMessageRead(data);
        break;
      case 'typing':
        print('[ChatProvider] ⌨️ Обработка typing');
        _handleTyping(data);
        break;
      case 'stopped_typing':
        print('[ChatProvider] ⌨️ Обработка stopped_typing');
        _handleStoppedTyping(data);
        break;
      case 'chat_created':
        print('[ChatProvider] 💬 Обработка chat_created');
        _handleChatCreated(data);
        break;
      case 'chat_deleted':
        print('[ChatProvider] 🗑️ Обработка chat_deleted');
        _handleChatDeleted(data);
        break;
      case 'message_sent':
        print('[ChatProvider] ✉️ Обработка message_sent');
        _handleMessageSent(data);
        break;
      case 'user_online':
        print('[ChatProvider] 🟢 Обработка user_online');
        _handleUserOnline(data);
        break;
      case 'user_offline':
        print('[ChatProvider] 🔴 Обработка user_offline');
        _handleUserOffline(data);
        break;
      case 'auth_success':
        print('[ChatProvider] ✅ Обработка auth_success - загружаем чаты');
        loadChats();
        break;
      case 'incoming_call':
        print('[ChatProvider] 📞 Обработка incoming_call');
        _handleIncomingCall(data);
        break;
      default:
        print('[ChatProvider] ⚠️ Неизвестный тип сообщения: $type');
        break;
    }

    print('[ChatProvider] ========================================');
    print('[ChatProvider] ✅ _handleWebSocketMessage завершен');
    print('[ChatProvider] ========================================');
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (_onIncomingCall != null) {
      _onIncomingCall!(data);
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
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
            ? data['message'] as Map<String, dynamic>
            : null;
      } else if (data.containsKey('data')) {
        messageData = data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : null;
      } else {
        messageData = data;
      }

      _log('messageData: $messageData');

      if (messageData == null) {
        _log('❌ messageData is NULL, возвращаемся');
        return;
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

        // Показываем уведомление ТОЛЬКО если окно не в фокусе
        if (kIsWeb && !_isWindowFocused) {
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

          _log('🔔 Title notification показан (окно не в фокусе)');
        } else if (kIsWeb) {
          _log('ℹ️ Окно в фокусе - уведомление не показано');
        } else {
          _log('ℹ️ Не Web платформа - уведомление не показано');
        }
      } else {
        _log('ℹ️ Сообщение от себя, пропускаем уведомление');
      }

      if (_currentChatId == message.chatId) {
        final existingIndex = _messages.indexWhere((m) => m.id == message.id);

        if (existingIndex == -1) {
          _messages.add(message);
          _log('✅ Сообщение добавлено в список');
        } else {
          _messages[existingIndex] = message;
          _log('✅ Сообщение обновлено в списке');
        }
      }

      final chatIndex = _chats.indexWhere((c) => c.id == message.chatId);
      if (chatIndex != -1) {
        final isCurrentChat = _currentChatId == message.chatId;

        _chats[chatIndex] = _chats[chatIndex].copyWith(
          lastMessage: message.content,
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

      _chats.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }

        final aTime = a.lastMessageTime ?? DateTime.now();
        final bTime = b.lastMessageTime ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      notifyListeners();
    }
  }

  void _handleTyping(Map<String, dynamic> data) {
    final chatId = data['chatId'] ?? data['chat_id'];
    if (chatId != null) {
      _typingStatus[chatId] = true;
      notifyListeners();

      Future.delayed(Duration(seconds: 3), () {
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

  void _handleMessageSent(Map<String, dynamic> data) {
    _handleNewMessage(data);
  }

  void _handleUserOnline(Map<String, dynamic> data) {
    // Обработка статуса онлайн
  }

  void _handleUserOffline(Map<String, dynamic> data) {
    // Обработка статуса оффлайн
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

  void setCurrentChatId(String? chatId) {
    if (_currentChatId == chatId) return;

    if (_currentChatId != null && _currentChatId != chatId) {
      _messages.clear();
    }

    _currentChatId = chatId;
    _log('setCurrentChatId: $_currentChatId');

    if (chatId != null) {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
        _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
      }

      // Сбрасываем уведомления ТОЛЬКО если есть что сбрасывать
      if (kIsWeb && TitleNotificationService.instance.unreadCount > 0) {
        TitleNotificationService.instance.clearUnread();
        _log('✅ Title notifications сброшены при открытии чата');
      }

      markMessagesAsRead(chatId);
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
      _messages = await _api.getMessages(chatId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _log('Ошибка загрузки сообщений: $e');
      _errorMessage = 'Не удалось загрузить сообщения';
      _isLoading = false;
      _messages = [];
      notifyListeners();
    }
  }

  // ⭐⭐⭐ ИСПРАВЛЕНО: Отправка через WebSocket вместо REST API
  Future<void> sendMessage(String content,
      {String? chatId, String? replyToId}) async {
    final targetChatId = chatId ?? _currentChatId;
    if (targetChatId == null) return;

    print('[ChatProvider] ========================================');
    print('[ChatProvider] 📤 ОТПРАВКА СООБЩЕНИЯ ЧЕРЕЗ WEBSOCKET');
    print('[ChatProvider] ChatID: $targetChatId');
    print('[ChatProvider] Content: $content');
    print('[ChatProvider] ========================================');

    try {
      // Генерируем временный ID для сообщения
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

      // ⭐ ИСПРАВЛЕНО: Отправляем через WebSocket, а не REST API!
      _wsManager.send({
        'type': 'send_message', // или 'message'
        'chatId': targetChatId,
        'content': content,
        'tempId': tempId,
      });

      print('[ChatProvider] ✅ Сообщение отправлено через WebSocket');
      print('[ChatProvider] TempID: $tempId');
      print('[ChatProvider] ========================================');

      // Добавляем сообщение локально (оптимистичное обновление UI)
      final tempMessage = Message(
        id: tempId,
        chatId: targetChatId,
        senderId: _currentUserId ?? '',
        senderName: 'Вы',
        content: content,
        timestamp: DateTime.now().toIso8601String(),
        type: 'text',
        isRead: false,
      );

      if (_currentChatId == targetChatId) {
        _messages.add(tempMessage);
        notifyListeners();
      }

      // Обновляем чат в списке
      final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
      if (chatIndex != -1) {
        _chats[chatIndex] = _chats[chatIndex].copyWith(
          lastMessage: content,
          lastMessageTime: DateTime.now(),
        );

        final chat = _chats.removeAt(chatIndex);
        _chats.insert(0, chat);
        notifyListeners();
      }
    } catch (e) {
      print('[ChatProvider] ❌ Ошибка отправки сообщения: $e');
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

  Future<void> deleteChat(String chatId) async {
    try {
      final success = await _api.deleteChat(chatId);

      if (success) {
        _chats.removeWhere((c) => c.id == chatId);

        if (_currentChatId == chatId) {
          _currentChatId = null;
          _messages.clear();
        }

        notifyListeners();
      }
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

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _focusSubscription?.cancel();
    _blurSubscription?.cancel();
    super.dispose();
  }
}
