// lib/providers/chat_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_manager.dart';
import '../services/title_notification_service.dart';

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
    _subscribeToWebSocket();
    _subscribeToAppLifecycle();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ChatProvider] $message');
    }
  }

  void _subscribeToWebSocket() {
    _wsSubscription = _wsManager.messages.listen((data) {
      _handleWebSocketMessage(data);
    });
  }

  void _subscribeToAppLifecycle() {
    // Пока не реализовано
  }

  void setIncomingCallHandler(Function(Map<String, dynamic>) handler) {
    _onIncomingCall = handler;
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'new_message':
      case 'message':
      case 'chat_message':
        _handleNewMessage(data);
        break;
      case 'message_read':
        _handleMessageRead(data);
        break;
      case 'typing':
        _handleTyping(data);
        break;
      case 'stopped_typing':
        _handleStoppedTyping(data);
        break;
      case 'chat_created':
        _handleChatCreated(data);
        break;
      case 'chat_deleted':
        _handleChatDeleted(data);
        break;
      case 'message_sent':
        _handleMessageSent(data);
        break;
      case 'user_online':
        _handleUserOnline(data);
        break;
      case 'user_offline':
        _handleUserOffline(data);
        break;
      case 'auth_success':
        loadChats();
        break;
      case 'incoming_call':
        _handleIncomingCall(data);
        break;
      default:
        break;
    }
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (_onIncomingCall != null) {
      _onIncomingCall!(data);
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
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

      if (messageData == null) return;

      final message = Message.fromJson(messageData);

      if (_currentChatId == message.chatId) {
        final existingIndex = _messages.indexWhere((m) => m.id == message.id);

        if (existingIndex == -1) {
          _messages.add(message);
        } else {
          _messages[existingIndex] = message;
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

        // Обновляем счетчик в заголовке только если сообщение НЕ в текущем чате
        if (!isCurrentChat && kIsWeb) {
          _updateUnreadCountInTitle();
        }
      }

      notifyListeners();

      if (_currentChatId == message.chatId) {
        markMessagesAsRead(message.chatId);
      }
    } catch (e) {
      _log('Ошибка обработки нового сообщения: $e');
    }
  }

  /// Обновляет счетчик непрочитанных в заголовке браузера
  void _updateUnreadCountInTitle() {
    if (!kIsWeb) return;

    int totalUnread = 0;
    for (var chat in _chats) {
      totalUnread += chat.unreadCount;
    }

    TitleNotificationService.instance.setUnreadCount(totalUnread);
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

    // Обновляем счетчик после удаления чата
    if (kIsWeb) {
      _updateUnreadCountInTitle();
    }

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
    loadChats();
  }

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  void setCurrentChatId(String? chatId) {
    if (_currentChatId == chatId) return;

    if (_currentChatId != null && _currentChatId != chatId) {
      _messages.clear();
    }

    _currentChatId = chatId;

    if (chatId != null) {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
        final unreadCount = _chats[chatIndex].unreadCount;
        _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);

        // Уменьшаем счетчик в заголовке на количество прочитанных
        if (kIsWeb) {
          for (int i = 0; i < unreadCount; i++) {
            TitleNotificationService.instance.decrementUnread();
          }
        }
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

      // Обновляем счетчик после загрузки чатов
      if (kIsWeb) {
        _updateUnreadCountInTitle();
      }

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

  Future<void> sendMessage(String content,
      {String? chatId, String? replyToId}) async {
    final targetChatId = chatId ?? _currentChatId;
    if (targetChatId == null) return;

    try {
      final message = await _api.sendMessage(targetChatId, content);

      if (message != null) {
        if (_currentChatId == targetChatId) {
          final existingIndex = _messages.indexWhere((m) => m.id == message.id);

          if (existingIndex == -1) {
            _messages.add(message);
          } else {
            _messages[existingIndex] = message;
          }
        }

        final chatIndex = _chats.indexWhere((c) => c.id == targetChatId);
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

        // Обновляем счетчик после удаления
        if (kIsWeb) {
          _updateUnreadCountInTitle();
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
