// lib/providers/chat_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_manager.dart';
import '../models/chat.dart';
import '../models/message.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:html' as html show window, document;

class ChatProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final WebSocketManager _wsManager = WebSocketManager.instance;

  // Подписки
  StreamSubscription? _wsSubscription;
  StreamSubscription? _focusSubscription;
  StreamSubscription? _blurSubscription;

  // Состояние
  List<Chat> _chats = [];
  Map<String, List<Message>> _messages = {};
  Map<String, Map<String, bool>> _typingUsers = {};
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentUserId;
  String? _currentChatId;
  bool _isWindowFocused = true;

  // Геттеры
  List<Chat> get chats => _chats;
  Map<String, List<Message>> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUserId => _currentUserId;
  String? get currentChatId => _currentChatId;
  Map<String, Map<String, bool>> get typingStatus => _typingUsers;

  int get totalUnreadCount {
    int count = 0;
    for (final chat in _chats) {
      count += chat.unreadCount;
    }
    return count;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ChatProvider] $message');
    }
  }

  String getCurrentUserId() {
    return _currentUserId ?? '';
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

  // ===== УПРАВЛЕНИЕ СОСТОЯНИЕМ =====

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    _log('Установлен ID пользователя: $userId');
  }

  void setCurrentChatId(String? chatId) {
    final previousChatId = _currentChatId;
    _currentChatId = chatId;

    if (previousChatId != null && _wsManager.isConnected) {
      _wsManager.leaveChat(previousChatId);
    }

    if (chatId != null) {
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1 && _chats[chatIndex].unreadCount > 0) {
        _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
        notifyListeners();
      }

      if (_wsManager.isConnected) {
        _wsManager.joinChat(chatId);
        _wsManager.markAsRead(chatId, null);
      }

      _markMessagesAsReadOnServer(chatId);
    }
  }

  // ===== ЗАГРУЗКА ДАННЫХ =====

  Future<void> loadChats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final chats = await _api.getChats();
      _chats = chats;
      _log('Загружено ${_chats.length} чатов');
    } catch (e) {
      _log('Ошибка загрузки чатов: $e');
      _errorMessage = 'Не удалось загрузить чаты';
      _chats = [];

      if (e.toString().contains('500')) {
        _log('Возможно это первый вход пользователя, база чатов пуста');
        _errorMessage = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String chatId, {bool forceReload = false}) async {
    if (_messages[chatId] != null && !forceReload) {
      _log('Сообщения для чата $chatId уже загружены');
      return;
    }

    try {
      _log('Загружаем сообщения для чата $chatId');
      final messages = await _api.getMessages(chatId);

      final uniqueMessages = <String, Message>{};
      final contentTimeMap = <String, DateTime>{};

      for (final message in messages) {
        final contentKey = '${message.senderId}_${message.content}';
        final messageTime = DateTime.parse(message.timestamp);

        if (!uniqueMessages.containsKey(message.id)) {
          if (contentTimeMap.containsKey(contentKey)) {
            final existingTime = contentTimeMap[contentKey]!;
            if (messageTime.difference(existingTime).inSeconds.abs() < 5) {
              _log('Пропускаем дубль сообщения');
              continue;
            }
          }

          uniqueMessages[message.id] = message;
          contentTimeMap[contentKey] = messageTime;
        }
      }

      _messages[chatId] = uniqueMessages.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _log('✅ Загружено ${_messages[chatId]!.length} уникальных сообщений');
      notifyListeners();
    } catch (e) {
      _log('⌛ Ошибка загрузки сообщений: $e');
      _messages[chatId] = [];
      notifyListeners();
    }
  }

  List<Message> getMessages(String chatId) {
    return _messages[chatId] ?? [];
  }

  // ===== ОТПРАВКА СООБЩЕНИЙ =====

  Future<bool> sendMessage({
    required String chatId,
    required String content,
    String type = 'text',
    String? replyToId,
  }) async {
    if (content.trim().isEmpty) return false;

    try {
      _log('📤 Отправляем сообщение в чат $chatId: $content');

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final tempMessage = Message(
        id: tempId,
        chatId: chatId,
        senderId: _currentUserId ?? '',
        senderName: 'Вы',
        content: content,
        type: type,
        timestamp: DateTime.now().toIso8601String(),
        isRead: false,
        status: 'отправляется',
      );

      _messages[chatId] ??= [];
      _messages[chatId]!.add(tempMessage);
      notifyListeners();

      _log('✅ Временное сообщение добавлено: $tempId');

      // Отправляем через WebSocket если подключен
      if (_wsManager.isConnected) {
        _wsManager.sendMessage({
          'chatId': chatId,
          'content': content,
          'messageType': type,
          'tempId': tempId,
          'replyToId': replyToId,
        });
        _log('📡 Сообщение отправлено через WebSocket');
      }

      // Отправляем через HTTP API
      Message? serverMessage = await _api.sendMessage(
        chatId: chatId,
        content: content,
        type: type,
        replyToId: replyToId,
      );

      if (serverMessage != null) {
        _log('✅ Получен ответ от сервера: ${serverMessage.id}');

        // Удаляем временное сообщение
        _messages[chatId]!.removeWhere((m) => m.id == tempId);

        // Проверяем, нет ли уже такого сообщения
        bool messageExists = _messages[chatId]!.any((m) =>
            m.id == serverMessage.id ||
            (m.content == serverMessage.content &&
                m.senderId == serverMessage.senderId &&
                DateTime.parse(serverMessage.timestamp)
                        .difference(DateTime.parse(m.timestamp))
                        .inSeconds
                        .abs() <
                    10)); // Увеличиваем окно до 10 секунд

        if (!messageExists) {
          final messageWithStatus =
              serverMessage.copyWith(status: 'отправлено');
          _messages[chatId]!.add(messageWithStatus);
          _log('✅ Серверное сообщение добавлено: ${serverMessage.id}');
        } else {
          _log('⚠️ Сообщение уже существует, не добавляем дубль');
        }

        _messages[chatId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _updateChatLastMessage(chatId, content);
        notifyListeners();
        return true;
      } else {
        _log('⌛ Не получен ответ от сервера');
        final index = _messages[chatId]!.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[chatId]![index] =
              _messages[chatId]![index].copyWith(status: 'ошибка');
        }
        _errorMessage = 'Не удалось отправить сообщение';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _log('⌛ Ошибка отправки сообщения: $e');
      _messages[chatId]?.removeWhere((m) => m.id.startsWith('temp_'));
      _errorMessage = 'Не удалось отправить сообщение';
      notifyListeners();
      return false;
    }
  }

  // ===== УПРАВЛЕНИЕ ЧАТАМИ =====

  Chat? getChatById(String chatId) {
    try {
      return _chats.firstWhere((chat) => chat.id == chatId);
    } catch (e) {
      return null;
    }
  }

  void updateChat(Chat updatedChat) {
    final index = _chats.indexWhere((chat) => chat.id == updatedChat.id);
    if (index != -1) {
      _chats[index] = updatedChat;

      _chats.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;

        final aTime = a.lastMessageTime ?? DateTime(1970);
        final bTime = b.lastMessageTime ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      notifyListeners();
    }
  }

  Future<Chat?> createChat({
    required String userId,
    String? userName,
  }) async {
    try {
      final chat = await _api.createChat(
        userId: userId,
        userName: userName,
      );

      if (chat != null) {
        _chats.insert(0, chat);
        notifyListeners();
      }

      return chat;
    } catch (e) {
      _log('Ошибка создания чата: $e');
      _errorMessage = 'Не удалось создать чат';
      return null;
    }
  }

  Future<bool> deleteChat(String chatId) async {
    try {
      final result = await _api.deleteChat(chatId);

      if (result) {
        _chats.removeWhere((chat) => chat.id == chatId);
        _messages.remove(chatId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _log('Ошибка удаления чата: $e');
      return false;
    }
  }

  void togglePinChat(String chatId) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        isPinned: !_chats[chatIndex].isPinned,
      );

      _chats.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;

        final aTime = a.lastMessageTime ?? DateTime(1970);
        final bTime = b.lastMessageTime ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      notifyListeners();
    }
  }

  // ===== СТАТУС ПЕЧАТИ =====

  void sendTypingStatus(String chatId, bool isTyping) {
    if (_wsManager.isConnected) {
      _wsManager.sendTyping(chatId, isTyping);
    }
  }

  String? getTypingUserName(String chatId) {
    final typingUsersInChat = _typingUsers[chatId];
    if (typingUsersInChat != null && typingUsersInChat.isNotEmpty) {
      return typingUsersInChat.keys.first;
    }
    return null;
  }

  // ===== ОЧИСТКА СООБЩЕНИЙ =====

  void clearMessages(String chatId) {
    _messages[chatId] = [];
    notifyListeners();
  }

  // ===== ОТМЕТКА О ПРОЧТЕНИИ =====

  void markMessagesAsRead(String chatId) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
      notifyListeners();
    }

    if (_wsManager.isConnected) {
      _wsManager.markAsRead(chatId, null);
    }

    _markMessagesAsReadOnServer(chatId);
  }

  Future<void> _markMessagesAsReadOnServer(String chatId) async {
    try {
      final success = await _api.markMessagesAsRead(chatId);

      if (success) {
        _log('✅ Сообщения отмечены как прочитанные на сервере');

        if (_messages[chatId] != null) {
          for (int i = 0; i < _messages[chatId]!.length; i++) {
            if (_messages[chatId]![i].senderId != _currentUserId) {
              _messages[chatId]![i] = _messages[chatId]![i].copyWith(
                isRead: true,
              );
            }
          }
          notifyListeners();
        }
      }
    } catch (e) {
      _log('⚠️ Ошибка отметки сообщений как прочитанных: $e');
    }
  }

  // ===== ОБНОВЛЕНИЕ ПОСЛЕДНЕГО СООБЩЕНИЯ =====

  void _updateChatLastMessage(String chatId, String message) {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(
        lastMessage: message,
        lastMessageTime: DateTime.now(),
      );

      final chat = _chats.removeAt(chatIndex);
      _chats.insert(0, chat);

      notifyListeners();
    }
  }

  // ===== ОБРАБОТЧИКИ WEBSOCKET =====

  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      _log('🔥 Обработка входящего сообщения: $data');

      final message = Message.fromJson(data);
      final chatId = message.chatId;

      _messages[chatId] ??= [];

      // Улучшенная проверка на дубликаты
      bool messageExists = _messages[chatId]!.any((m) {
        // Проверяем по ID
        if (m.id == message.id) {
          _log('Сообщение с ID ${message.id} уже существует');
          return true;
        }

        // Проверяем временные сообщения
        if (m.id.startsWith('temp_') &&
            m.content == message.content &&
            m.senderId == message.senderId) {
          _log('Найдено временное сообщение с таким же содержимым');
          return true;
        }

        // Для собственных сообщений проверяем по содержимому и времени
        if (m.content == message.content &&
            m.senderId == message.senderId &&
            message.senderId == _currentUserId) {
          final timeDiff = DateTime.parse(message.timestamp)
              .difference(DateTime.parse(m.timestamp))
              .inSeconds
              .abs();
          if (timeDiff < 10) {
            _log('Найдено собственное сообщение в пределах 10 секунд');
            return true;
          }
        }

        return false;
      });

      if (!messageExists) {
        // Удаляем временное сообщение если есть
        _messages[chatId]!.removeWhere((m) =>
            m.id.startsWith('temp_') &&
            m.content == message.content &&
            m.senderId == message.senderId);

        _messages[chatId]!.add(message);
        _messages[chatId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        _log('✅ Новое сообщение добавлено в чат $chatId: ${message.id}');
      } else {
        _log('⚠️ Сообщение уже существует, пропускаем: ${message.id}');
      }

      // Обновляем чат
      final chatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (chatIndex != -1) {
        final isCurrentChat = _currentChatId == chatId;
        final isOwnMessage = message.senderId == _currentUserId;

        int newUnreadCount;
        if (isCurrentChat && (!kIsWeb || _isWindowFocused)) {
          newUnreadCount = 0;

          if (!isOwnMessage && _wsManager.isConnected) {
            _wsManager.markAsRead(chatId, message.id);
          }
        } else if (isOwnMessage) {
          newUnreadCount = _chats[chatIndex].unreadCount;
        } else {
          newUnreadCount = _chats[chatIndex].unreadCount + 1;
        }

        _chats[chatIndex] = _chats[chatIndex].copyWith(
          lastMessage: message.content,
          lastMessageTime: DateTime.now(),
          unreadCount: newUnreadCount,
        );

        final chat = _chats.removeAt(chatIndex);
        _chats.insert(0, chat);

        _log('✅ Чат обновлен: $chatId, непрочитано: ${_chats[0].unreadCount}');
      }

      notifyListeners();
      _log('🎯 UI уведомлен об изменениях');
    } catch (e) {
      _log('⌛ Ошибка обработки входящего сообщения: $e');
    }
  }

  void _handleMessageSent(Map<String, dynamic> data) {
    try {
      final tempId = data['tempId'];
      final message = Message.fromJson(data['message']);
      final chatId = message.chatId;

      if (_messages[chatId] != null && tempId != null) {
        final index = _messages[chatId]!.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[chatId]![index] =
              message.copyWith(status: message.status ?? 'отправлено');
          _log('✅ Временное сообщение $tempId заменено на ${message.id}');
          notifyListeners();
        }
      }
    } catch (e) {
      _log('⌛ Ошибка обработки подтверждения отправки: $e');
    }
  }

  void _handleTypingStatus(Map<String, dynamic> data) {
    final chatId = data['chatId']?.toString();
    final userId = data['userId']?.toString();
    final userName = data['userName']?.toString() ?? userId ?? 'Пользователь';
    final isTyping = data['isTyping'] ?? true;

    if (chatId == null || userId == null) return;
    if (userId == _currentUserId) return;

    _typingUsers[chatId] ??= {};

    if (isTyping) {
      _typingUsers[chatId]![userName] = true;

      Future.delayed(Duration(seconds: 3), () {
        _typingUsers[chatId]?.remove(userName);
        notifyListeners();
      });
    } else {
      _typingUsers[chatId]!.remove(userName);
    }

    notifyListeners();
  }

  void _handleStoppedTyping(Map<String, dynamic> data) {
    data['isTyping'] = false;
    _handleTypingStatus(data);
  }

  void _handleMessageRead(Map<String, dynamic> data) {
    final chatId = data['chatId'];
    final messageId = data['messageId'];
    final status = data['status'] ?? 'прочитано';

    _log(
        '📖 Получено уведомление о прочтении: chatId=$chatId, messageId=$messageId');

    if (chatId != null && _messages[chatId] != null) {
      if (messageId != null) {
        final messageIndex =
            _messages[chatId]!.indexWhere((m) => m.id == messageId.toString());
        if (messageIndex != -1) {
          _messages[chatId]![messageIndex] =
              _messages[chatId]![messageIndex].copyWith(
            isRead: true,
            status: status,
          );
          _log('✅ Статус сообщения $messageId обновлен на "$status"');
        }
      } else {
        for (int i = 0; i < _messages[chatId]!.length; i++) {
          if (_messages[chatId]![i].senderId == _currentUserId) {
            _messages[chatId]![i] = _messages[chatId]![i].copyWith(
              isRead: true,
              status: status,
            );
          }
        }
        _log('✅ Все сообщения в чате $chatId отмечены как прочитанные');
      }

      notifyListeners();
    }
  }

  void _handleChatCreated(Map<String, dynamic> data) {
    try {
      final chat = Chat.fromJson(data['chat'] ?? data);

      bool chatExists = _chats.any((c) => c.id == chat.id);

      if (!chatExists) {
        _chats.insert(0, chat);
        notifyListeners();
      }
    } catch (e) {
      _log('Ошибка обработки нового чата: $e');
    }
  }

  void _handleChatDeleted(Map<String, dynamic> data) {
    final chatId = data['chatId'];
    if (chatId != null) {
      _chats.removeWhere((chat) => chat.id == chatId);
      _messages.remove(chatId);
      notifyListeners();
    }
  }

  void _handleUserOnline(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null) {
      for (int i = 0; i < _chats.length; i++) {
        if (_chats[i].participants?.contains(userId) ?? false) {
          _chats[i] = _chats[i].copyWith(isOnline: true);
        }
      }
      notifyListeners();
    }
  }

  void _handleUserOffline(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId != null) {
      for (int i = 0; i < _chats.length; i++) {
        if (_chats[i].participants?.contains(userId) ?? false) {
          _chats[i] = _chats[i].copyWith(isOnline: false);
        }
      }
      notifyListeners();
    }
  }

  void clearAll() {
    _chats.clear();
    _messages.clear();
    _typingUsers.clear();
    _currentChatId = null;
    notifyListeners();
  }

  void forceUpdateChats() {
    notifyListeners();
    _log('🔄 Принудительное обновление UI');
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _focusSubscription?.cancel();
    _blurSubscription?.cancel();
    _wsManager.disconnect();
    super.dispose();
  }
}
