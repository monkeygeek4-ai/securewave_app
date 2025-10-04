// lib/providers/chat_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_manager.dart';

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
    debugPrint('[ChatProvider] $message');
  }

  void _subscribeToWebSocket() {
    _wsSubscription = _wsManager.messages.listen((data) {
      _handleWebSocketMessage(data);
    });
  }

  void _subscribeToAppLifecycle() {
    // Метод onFocus/onBlur не существует в WebSocketManager
    // Убираем эти подписки или реализуем альтернативным способом
    _log('Подписка на lifecycle events (пока не реализована)');
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    final type = data['type'];
    _log('WebSocket сообщение: $type');

    switch (type) {
      case 'new_message':
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
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    try {
      final message = Message.fromJson(data['message']);
      _log('Новое сообщение: ${message.id} в чате ${message.chatId}');

      final existingIndex = _messages.indexWhere((m) => m.id == message.id);

      if (existingIndex == -1) {
        _messages.add(message);
      } else {
        _messages[existingIndex] = message;
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
      }

      notifyListeners();

      if (_currentChatId == message.chatId) {
        markMessagesAsRead(message.chatId);
      }
    } catch (e) {
      _log('Ошибка обработки нового сообщения: $e');
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
    _log('Сообщение прочитано: $data');
  }

  void _handleChatCreated(Map<String, dynamic> data) {
    try {
      final chat = Chat.fromJson(data['chat']);
      _chats.insert(0, chat);
      notifyListeners();
      _log('Новый чат создан: ${chat.id}');
    } catch (e) {
      _log('Ошибка обработки создания чата: $e');
    }
  }

  void _handleChatDeleted(Map<String, dynamic> data) {
    final chatId = data['chatId'];
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();
    _log('Чат удален: $chatId');
  }

  void _handleMessageSent(Map<String, dynamic> data) {
    _log('Подтверждение отправки сообщения: $data');
  }

  void _handleUserOnline(Map<String, dynamic> data) {
    final userId = data['userId'];
    _log('Пользователь онлайн: $userId');
  }

  void _handleUserOffline(Map<String, dynamic> data) {
    final userId = data['userId'];
    _log('Пользователь оффлайн: $userId');
  }

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    _log('Установлен ID пользователя: $userId');
  }

  // ИСПРАВЛЕННЫЙ МЕТОД - очищает старые сообщения и загружает новые
  void setCurrentChatId(String? chatId) {
    // Если переключаемся на другой чат - очищаем старые сообщения
    if (_currentChatId != chatId) {
      _messages.clear();
      _log('Очищены сообщения предыдущего чата');
    }

    _currentChatId = chatId;
    _log('Установлен текущий чат: $chatId');

    if (chatId != null) {
      // Сбрасываем счетчик непрочитанных
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
        _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
      }

      // Загружаем сообщения нового чата
      loadMessages(chatId);

      // Отмечаем сообщения как прочитанные
      markMessagesAsRead(chatId);
    }

    notifyListeners();
  }

  Future<void> loadChats() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _log('Загрузка чатов...');
      _chats = await _api.getChats();
      _log('Загружено ${_chats.length} чатов');
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
      _log('Загрузка сообщений для чата: $chatId');
      _messages = await _api.getMessages(chatId);
      _log('Загружено ${_messages.length} сообщений');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _log('Ошибка загрузки сообщений: $e');
      _errorMessage = 'Не удалось загрузить сообщения';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content,
      {String? chatId, String? replyToId}) async {
    final targetChatId = chatId ?? _currentChatId;

    if (targetChatId == null) {
      _log('Ошибка: chatId не указан');
      return;
    }

    try {
      _log('Отправка сообщения в чат: $targetChatId');

      final message = await _api.sendMessage(targetChatId, content);

      if (message != null) {
        _log('Сообщение отправлено: ${message.id}');

        final existingIndex = _messages.indexWhere((m) => m.id == message.id);

        if (existingIndex == -1) {
          _messages.add(message);
        } else {
          _messages[existingIndex] = message;
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

  Future<void> createOrGetChat(String userId) async {
    try {
      _log('Создание или получение чата с пользователем: $userId');

      final chat = await _api.createChat(userId);

      if (chat != null) {
        _log('Чат создан/получен: ${chat.id}');

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

  // НОВЫЙ МЕТОД для создания группового чата
  Future<void> createGroupChat(
      String groupName, List<String> participantIds) async {
    try {
      _log(
          'Создание группового чата: $groupName с ${participantIds.length} участниками');

      final chat = await _api.createGroupChat(groupName, participantIds);

      if (chat != null) {
        _log('Групповой чат создан: ${chat.id}');

        final existingIndex = _chats.indexWhere((c) => c.id == chat.id);

        if (existingIndex == -1) {
          _chats.insert(0, chat);
        } else {
          _chats[existingIndex] = chat;
        }

        // Обновляем список чатов
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
      _log('Удаление чата: $chatId');

      final success = await _api.deleteChat(chatId);

      if (success) {
        _chats.removeWhere((c) => c.id == chatId);

        if (_currentChatId == chatId) {
          _currentChatId = null;
          _messages.clear();
        }

        notifyListeners();
        _log('Чат успешно удален');
      }
    } catch (e) {
      _log('Ошибка удаления чата: $e');
      _errorMessage = 'Не удалось удалить чат';
      notifyListeners();
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    try {
      await _api.markMessagesAsRead(chatId);
      _log('Сообщения отмечены как прочитанные для чата: $chatId');
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
