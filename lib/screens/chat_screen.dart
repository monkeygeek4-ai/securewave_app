// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/call.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../services/webrtc_service.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final dynamic chat;

  const ChatScreen({Key? key, required this.chat}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;
  Timer? _typingTimer;
  bool _isLoading = false;

  String get _chatId {
    if (widget.chat is Chat) {
      return (widget.chat as Chat).id;
    } else if (widget.chat is Map) {
      return widget.chat['id']?.toString() ?? '';
    }
    return '';
  }

  String get _chatName {
    if (widget.chat is Chat) {
      return (widget.chat as Chat).name;
    } else if (widget.chat is Map) {
      return widget.chat['name']?.toString() ?? 'Неизвестный';
    }
    return 'Неизвестный';
  }

  String? get _chatAvatar {
    if (widget.chat is Chat) {
      return (widget.chat as Chat).avatarUrl;
    } else if (widget.chat is Map) {
      return widget.chat['avatar']?.toString() ??
          widget.chat['avatarUrl']?.toString();
    }
    return null;
  }

  bool get _isOnline {
    if (widget.chat is Chat) {
      return (widget.chat as Chat).isOnline;
    } else if (widget.chat is Map) {
      return widget.chat['isOnline'] ?? false;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();

    // ВАЖНО: Устанавливаем текущий чат при открытии экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.setCurrentChatId(_chatId);

      // Загружаем сообщения
      chatProvider.loadMessages(_chatId);

      // Отмечаем сообщения как прочитанные
      chatProvider.markMessagesAsRead(_chatId);

      // Прокручиваем вниз
      _scrollToBottom();
    });

    // Добавляем слушатель изменения текста для обновления кнопки
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    // Обновляем UI только если состояние кнопки изменилось
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // ВАЖНО: Сбрасываем текущий чат при закрытии экрана
    context.read<ChatProvider>().setCurrentChatId(null);

    // Удаляем слушатель
    _messageController.removeListener(_onTextChanged);

    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    _messageController.clear();
    // Важно: обновляем UI после очистки
    setState(() {});

    _stopTyping();

    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.sendMessage(
        chatId: _chatId,
        content: text,
      );

      // Прокрутка вниз после отправки
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки сообщения'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleTyping() {
    final chatProvider = context.read<ChatProvider>();

    if (!_isTyping) {
      _isTyping = true;
      chatProvider.sendTypingStatus(_chatId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      context.read<ChatProvider>().sendTypingStatus(_chatId, false);
    }
    _typingTimer?.cancel();
  }

  void _startCall(String callType) {
    // Изменено с CallType на String
    // Получаем ID получателя из чата
    final chatProvider = context.read<ChatProvider>();

    // Проверяем, что у нас есть chatId
    if (_chatId.isEmpty) {
      print('[ChatScreen] chatId пустой');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось начать звонок: чат не определен'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final chat = chatProvider.getChatById(_chatId);

    if (chat == null) {
      print('[ChatScreen] Чат не найден для ID: $_chatId');
      // Попробуем использовать данные из widget.chat
      String? receiverId;

      // Если widget.chat это Map
      if (widget.chat is Map) {
        receiverId = widget.chat['receiverId']?.toString() ??
            widget.chat['receiver_id']?.toString();
      }

      if (receiverId == null || receiverId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось начать звонок: получатель не определен'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Запускаем звонок с данными из widget.chat
      print(
          '[ChatScreen] Начинаем ${callType == "video" ? "видео" : "аудио"} звонок с $receiverId (из widget.chat)');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            chatId: _chatId,
            receiverId: receiverId,
            receiverName: _chatName,
            receiverAvatar: _chatAvatar,
            callType: callType,
          ),
        ),
      );
      return;
    }

    // Получаем ID собеседника
    String? receiverId;

    // Сначала пробуем получить из receiverId (прямое поле)
    if (chat.receiverId != null && chat.receiverId!.isNotEmpty) {
      receiverId = chat.receiverId;
      print('[ChatScreen] Используем receiverId из чата: $receiverId');
    }
    // Затем пробуем получить из participants
    else if (chat.participants != null && chat.participants!.length > 1) {
      receiverId = chat.participants!.firstWhere(
        (id) => id != chatProvider.currentUserId && id.isNotEmpty,
        orElse: () => '',
      );
      print('[ChatScreen] Используем receiverId из participants: $receiverId');
    }

    // Если не удалось получить receiverId, показываем ошибку
    if (receiverId == null || receiverId.isEmpty) {
      print('[ChatScreen] Не удалось определить получателя звонка');
      print('[ChatScreen] Chat receiverId: ${chat.receiverId}');
      print('[ChatScreen] Chat participants: ${chat.participants}');
      print('[ChatScreen] Current user ID: ${chatProvider.currentUserId}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось начать звонок: получатель не определен'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print(
        '[ChatScreen] Начинаем ${callType == "video" ? "видео" : "аудио"} звонок с $receiverId');

    // Переходим на экран звонка
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          chatId: _chatId,
          receiverId: receiverId,
          receiverName: _chatName,
          receiverAvatar: _chatAvatar,
          callType: callType,
        ),
      ),
    );
  }

  bool _shouldShowDate(Message current, Message? previous) {
    if (previous == null) return true;

    final currentDate = DateTime.parse(current.timestamp);
    final previousDate = DateTime.parse(previous.timestamp);

    return currentDate.day != previousDate.day ||
        currentDate.month != previousDate.month ||
        currentDate.year != previousDate.year;
  }

  String _formatDate(String timestamp) {
    final date = DateTime.parse(timestamp);
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));

    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      return 'Сегодня';
    } else if (date.day == yesterday.day &&
        date.month == yesterday.month &&
        date.year == yesterday.year) {
      return 'Вчера';
    } else {
      final months = [
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря'
      ];
      return '${date.day} ${months[date.month - 1]}';
    }
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.push_pin),
              title: Text('Закрепить чат'),
              onTap: () {
                Navigator.pop(context);
                context.read<ChatProvider>().togglePinChat(_chatId);
              },
            ),
            ListTile(
              leading: Icon(Icons.volume_off),
              title: Text('Отключить уведомления'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Реализовать отключение уведомлений
              },
            ),
            ListTile(
              leading: Icon(Icons.search),
              title: Text('Поиск по чату'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Реализовать поиск
              },
            ),
            ListTile(
              leading: Icon(Icons.clear),
              title: Text('Очистить чат'),
              onTap: () {
                Navigator.pop(context);
                _clearChat();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Удалить чат', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteChat();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Очистить чат?'),
        content: Text('Все сообщения будут удалены безвозвратно'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatProvider>().clearMessages(_chatId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Чат очищен')),
              );
            },
            child: Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить чат?'),
        content: Text('Чат будет удален безвозвратно'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await context.read<ChatProvider>().deleteChat(_chatId);
              if (success) {
                Navigator.pop(this.context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Чат удален')),
                );
              }
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Message message, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Копировать'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Копировать в буфер
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Редактировать'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Редактировать сообщение
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Удалить сообщение
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.reply),
              title: Text('Ответить'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Ответить на сообщение
              },
            ),
            ListTile(
              leading: Icon(Icons.forward),
              title: Text('Переслать'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Переслать сообщение
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF2B5CE6),
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            // TODO: Открыть профиль пользователя
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    _chatAvatar != null ? NetworkImage(_chatAvatar!) : null,
                child: _chatAvatar == null
                    ? Icon(Icons.person, color: Colors.grey[600], size: 20)
                    : null,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _chatName,
                      style: TextStyle(fontSize: 16),
                    ),
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        final typingUser =
                            chatProvider.getTypingUserName(_chatId);
                        if (typingUser != null) {
                          return Text(
                            'печатает...',
                            style: TextStyle(
                                fontSize: 12, fontStyle: FontStyle.italic),
                          );
                        }
                        return Text(
                          _isOnline ? 'в сети' : 'не в сети',
                          style: TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Кнопка аудио звонка
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () {
              _startCall('audio'); // Используем строку вместо enum
            },
            tooltip: 'Аудио звонок',
          ),
          // Кнопка видео звонка
          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () {
              _startCall('video'); // Используем строку вместо enum
            },
            tooltip: 'Видео звонок',
          ),
          // Кнопка меню
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Список сообщений
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final messages = chatProvider.getMessages(_chatId);

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Нет сообщений',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final previousMessage =
                        index > 0 ? messages[index - 1] : null;
                    final showDate = _shouldShowDate(message, previousMessage);
                    final isMe = message.senderId == chatProvider.currentUserId;

                    return Column(
                      children: [
                        if (showDate)
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 10),
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              _formatDate(message.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        GestureDetector(
                          onLongPress: () => _showMessageOptions(message, isMe),
                          child: MessageBubble(
                            message: message,
                            isMe: isMe,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Индикатор набора текста
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              final typingUser = chatProvider.getTypingUserName(_chatId);
              if (typingUser != null) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      TypingIndicator(),
                      SizedBox(width: 8),
                      Text(
                        '$typingUser печатает...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),

          // Поле ввода сообщения
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                    onPressed: () {
                      // TODO: Прикрепить файл
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _focusNode,
                              maxLines: 5,
                              minLines: 1,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (text) {
                                _handleTyping();
                              },
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: 'Введите сообщение...',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                            onPressed: () {
                              // TODO: Открыть панель эмодзи
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  // Кнопка отправки/записи голоса
                  Builder(
                    builder: (context) {
                      final hasText = _messageController.text.trim().isNotEmpty;

                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: hasText ? Color(0xFF2B5CE6) : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: hasText
                                ? (_isLoading ? null : _sendMessage)
                                : () {
                                    // TODO: Голосовое сообщение
                                    print('Запись голосового сообщения');
                                  },
                            child: Center(
                              child: Icon(
                                hasText ? Icons.send : Icons.mic,
                                color:
                                    hasText ? Colors.white : Colors.grey[700],
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
