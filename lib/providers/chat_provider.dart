// lib/providers/chat_provider.dart

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:html' as html;
import '../models/chat.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_manager.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final WebSocketManager _wsManager = WebSocketManager.instance;

  List<Chat> _chats = [];
  List<Message> _messages = [];
  String? _currentChatId;
  String? _currentUserId;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, bool> _typingStatus = {};
  bool _isWindowFocused = true;

  StreamSubscription? _wsSubscription;
  StreamSubscription? _focusSubscription;
  StreamSubscription? _blurSubscription;

  static const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

  List<Chat> get chats => _chats;
  List<Message> get messages => _messages;
  String? get currentChatId => _currentChatId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUserId => _currentUserId ?? '';

  void _log(String message) {
    if (kDebugMode) {
      print('[ChatProvider] $message');
    }
  }

  bool isUserTyping(String chatId) {
    return _typingStatus[chatId] ?? false;
  }

  ChatProvider() {
    _initializeWebSocketListeners();
    _initializeWindowFocusListeners();
  }

  void _initializeWebSocketListeners() {
    _wsSubscription?.cancel();

    _wsSubscription = _wsManager.messages.listen((data) {
      _log('📨 Получено WS сообщение: ${data['type']}');

      Future.microtask(() {
        switch (data['type']) {
          case 'новое_сообщение':
          case 'message':
          case 'new_message':
            _log('💬 Обработка нового сообщения');
            _handleIncomingMessage(data['message'] ?? data);
            break;
          case 'typing':
          case 'пользователь_печатает':
            _handleTypingStatus(data);
            break;
          case 'stopped_typing':
          case 'пользователь_перестал_печатать':
            _handleStoppedTyping(data);
            break;
          case 'message_read':
          case 'сообщение_прочитано':
            _handleMessageRead(data);
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
      });
    });
  }

  void _initializeWindowFocusListeners() {
    if (kIsWeb) {
      _focusSubscription = html.window.onFocus.listen((_) {
        _isWindowFocused = true;
        _log('🔍 Окно в фокусе');

        if (_currentChatId != null) {
          final chatIndex = _chats.indexWhere((c) => c.id == _currentChatId);
          if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
            _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
            notifyListeners();
          }

          markMessagesAsRead(_currentChatId!);
        }
      });

      _blurSubscription = html.window.onBlur.listen((_) {
        _isWindowFocused = false;
        _log('🔍 Окно потеряло фокус');
      });

      html.document.addEventListener('visibilitychange', (event) {
        final isVisible = !html.document.hidden!;
        _isWindowFocused = isVisible;

        _log('📱 Видимость страницы: ${isVisible ? "видима" : "скрыта"}');

        if (isVisible && _currentChatId != null) {
          final chatIndex = _chats.indexWhere((c) => c.id == _currentChatId);
          if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
            _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
            notifyListeners();
          }

          markMessagesAsRead(_currentChatId!);
        }
      });
    }
  }

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    _log('Установлен ID пользователя: $userId');
  }

  void setCurrentChatId(String? chatId) {
    _currentChatId = chatId;
    _log('Установлен текущий чат: $chatId');

    if (chatId != null) {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
        _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
        notifyListeners();
      }

      markMessagesAsRead(chatId);
    }
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

  Future<void> sendMessage(String content, {String? replyToId}) async {
    if (_currentChatId == null || content.trim().isEmpty) {
      _log(
          'Невозможно отправить сообщение: chatId = $_currentChatId, content пустой');
      return;
    }

    try {
      _log('Отправка сообщения в чат $_currentChatId');

      final message = await _api.sendMessage(_currentChatId!, content);

      if (message != null) {
        _log('Сообщение успешно отправлено: ${message.id}');

        _addMessageLocally(message);
        _updateChatLastMessage(message);
      } else {
        _log('Ошибка: сообщение не было создано на сервере');
      }
    } catch (e) {
      _log('Ошибка отправки сообщения: $e');
      _errorMessage = 'Не удалось отправить сообщение';
      notifyListeners();
    }
  }

  void _addMessageLocally(Message message) {
    if (!_messages.any((m) => m.id == message.id)) {
      _messages.add(message);
      notifyListeners();
    }
  }

  void _updateChatLastMessage(Message message) {
    final chatIndex = _chats.indexWhere((c) => c.id == message.chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
      );

      _chats.sort((a, b) {
        final aTime = a.lastMessageTime ?? DateTime.now();
        final bTime = b.lastMessageTime ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

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
    if (chat == null || chat.participants == null) return null;

    try {
      final otherParticipant = chat.participants!.firstWhere(
        (p) => p.id != _currentUserId,
      );
      return otherParticipant.username;
    } catch (e) {
      return null;
    }
  }

  Future<void> sendTypingStatus(bool isTyping) async {
    if (_currentChatId == null) return;

    _wsManager.send({
      'type': isTyping ? 'typing' : 'stopped_typing',
      'chatId': _currentChatId,
      'userId': _currentUserId,
    });
  }

  Future<void> togglePinChat(String chatId) async {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) return;

    _chats[chatIndex] = _chats[chatIndex].copyWith(
      isPinned: !_chats[chatIndex].isPinned,
    );

    _chats.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      final aTime = a.lastMessageTime ?? DateTime.now();
      final bTime = b.lastMessageTime ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    notifyListeners();
  }

  Future<void> clearMessages(String chatId) async {
    _messages.removeWhere((m) => m.chatId == chatId);
    notifyListeners();
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final message = Message.fromJson(data);
      _log('Новое сообщение: ${message.id} в чате ${message.chatId}');

      if (message.chatId == _currentChatId) {
        _addMessageLocally(message);

        if (_isWindowFocused) {
          markMessagesAsRead(message.chatId);
        }
      }

      _updateChatLastMessage(message);

      final chatIndex = _chats.indexWhere((c) => c.id == message.chatId);
      if (chatIndex != -1 && message.chatId != _currentChatId) {
        final currentUnread = _chats[chatIndex].unreadCount;
        _chats[chatIndex] = _chats[chatIndex].copyWith(
          unreadCount: currentUnread + 1,
        );
        notifyListeners();
      }
    } catch (e) {
      _log('Ошибка обработки входящего сообщения: $e');
    }
  }

  void _handleTypingStatus(Map<String, dynamic> data) {
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

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _focusSubscription?.cancel();
    _blurSubscription?.cancel();
    super.dispose();
  }
}
