// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../utils/app_colors.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.setCurrentChatId(_chatId);
      chatProvider.loadMessages(_chatId);
      chatProvider.markMessagesAsRead(_chatId);
      _scrollToBottom();
    });

    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    context.read<ChatProvider>().setCurrentChatId(null);
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
    setState(() {});
    _stopTyping();

    try {
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.sendMessage(text, chatId: _chatId);

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
    final chatProvider = context.read<ChatProvider>();

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
      String? receiverId;

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

      print(
          '[ChatScreen] Начинаем ${callType == "video" ? "видеозвонок" : "аудиозвонок"} с $receiverId');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            chatId: _chatId,
            receiverId: receiverId,
            receiverName: _chatName,
            receiverAvatar: _chatAvatar,
            callType: callType,
          ),
        ),
      );
    } else {
      // ИСПРАВЛЕНО: добавлена проверка на null для participants
      final receiverId =
          chat.participants?.isNotEmpty == true ? chat.participants!.first : '';

      print(
          '[ChatScreen] Начинаем ${callType == "video" ? "видеозвонок" : "аудиозвонок"} с $receiverId');

      if (receiverId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось определить получателя'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            chatId: _chatId,
            receiverId: receiverId,
            receiverName: chat.name,
            receiverAvatar: chat.avatarUrl,
            callType: callType,
          ),
        ),
      );
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
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      return 'Вчера';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        _chatAvatar == null ? AppColors.primaryGradient : null,
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
                    backgroundImage:
                        _chatAvatar != null ? NetworkImage(_chatAvatar!) : null,
                    child: _chatAvatar == null
                        ? Text(
                            _chatName[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                if (_isOnline)
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chatName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, _) {
                      final typingUser =
                          chatProvider.getTypingUserName(_chatId);
                      if (typingUser != null) {
                        return Text(
                          'печатает...',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                        );
                      }
                      return Text(
                        _isOnline ? 'В сети' : 'Не в сети',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
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
            icon: Icon(Icons.videocam),
            onPressed: () => _startCall('video'),
            tooltip: 'Видеозвонок',
          ),
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () => _startCall('audio'),
            tooltip: 'Аудиозвонок',
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Дополнительное меню
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: Column(
          children: [
            // Список сообщений
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  // ИСПРАВЛЕНО: используем getMessages вместо getMessagesForChat
                  final messages = chatProvider.getMessages(_chatId);

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [AppColors.primaryShadow],
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Нет сообщений',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextColor(context),
                            ),
                          ),
                          SizedBox(height: 8),
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

                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final previousMessage =
                          index > 0 ? messages[index - 1] : null;

                      return Column(
                        children: [
                          if (_shouldShowDate(message, previousMessage))
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Container(
                                padding: EdgeInsets.symmetric(
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
                          MessageBubble(
                            message: message,
                            isMe: message.senderId ==
                                context.read<ChatProvider>().currentUserId,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Индикатор печати
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final typingUser = chatProvider.getTypingUserName(_chatId);
                if (typingUser != null) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        TypingIndicator(),
                        SizedBox(width: 8),
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
                return SizedBox.shrink();
              },
            ),

            // Поле ввода сообщения
            Container(
              decoration: BoxDecoration(
                color: AppColors.getSurfaceColor(context),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: SafeArea(
                child: Row(
                  children: [
                    // Кнопка прикрепления файлов
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: AppColors.primaryPurple,
                      ),
                      onPressed: () {
                        // TODO: Прикрепление файлов
                      },
                    ),
                    // Поле ввода
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
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    // Кнопка отправки
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
                        icon: _isLoading
                            ? SizedBox(
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
                        onPressed:
                            _messageController.text.trim().isEmpty || _isLoading
                                ? null
                                : _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
