// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.setCurrentChatId(_chatId);

      await Future.delayed(Duration(milliseconds: 100));

      if (mounted) {
        _scrollToBottom();
      }
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
    final chatProvider = context.read<ChatProvider>();

    if (chatProvider.currentChatId == _chatId) {
      chatProvider.setCurrentChatId(null);
    }

    _messageController.removeListener(_onTextChanged);
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();

    super.dispose();
  }

  void _handleTyping() {
    final chatProvider = context.read<ChatProvider>();

    if (!_isTyping) {
      _isTyping = true;
      chatProvider.sendTypingStatus(_chatId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 2), () {
      _isTyping = false;
      chatProvider.sendTypingStatus(_chatId, false);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();

    _messageController.clear();
    _focusNode.unfocus();

    await chatProvider.sendMessage(text, chatId: _chatId);

    if (mounted) {
      _scrollToBottom();
    }
  }

  void _startCall(String callType) {
    final chatProvider = context.read<ChatProvider>();
    final chat = chatProvider.getChatById(_chatId);

    if (chat == null) {
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

    final participants = chat.participants;
    if (participants == null || participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось начать звонок: участники не найдены'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentUserId = chatProvider.currentUserId;

    final receiverId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => participants.first,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          chatId: _chatId,
          receiverId: receiverId,
          receiverName: chat.name,
          receiverAvatar: chat.avatarUrl,
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
              },
            ),
            ListTile(
              leading: Icon(Icons.search),
              title: Text('Поиск по чату'),
              onTap: () {
                Navigator.pop(context);
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
        content: Text('Все сообщения будут удалены безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Функция в разработке')),
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
        content: Text('Чат будет удален безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<ChatProvider>().deleteChat(_chatId);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.id ?? '';
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: () {},
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  backgroundImage:
                      _chatAvatar != null && _chatAvatar!.isNotEmpty
                          ? NetworkImage(_chatAvatar!)
                          : null,
                  child: _chatAvatar == null || _chatAvatar!.isEmpty
                      ? Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _chatName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        final isTyping = chatProvider.isUserTyping(_chatId);
                        return Text(
                          isTyping
                              ? 'печатает...'
                              : _isOnline
                                  ? 'в сети'
                                  : 'был(а) недавно',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
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
          IconButton(
            icon: Icon(Icons.call),
            onPressed: () => _startCall('audio'),
            tooltip: 'Аудио звонок',
          ),
          IconButton(
            icon: Icon(Icons.videocam),
            onPressed: () => _startCall('video'),
            tooltip: 'Видео звонок',
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: _showChatOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                      ? [Color(0xFF1E1E1E), Color(0xFF0D0D0D)]
                      : [Color(0xFFF5F3FF), Color(0xFFEDE7F6)],
                ),
              ),
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  final messages = chatProvider.getMessages(_chatId);

                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Нет сообщений',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Color(0xFF7C3AED),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Начните переписку',
                            style: TextStyle(
                              color:
                                  isDarkMode ? Colors.white54 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final previousMessage =
                          index > 0 ? messages[index - 1] : null;
                      final showDate =
                          _shouldShowDate(message, previousMessage);

                      return Column(
                        children: [
                          if (showDate)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF667EEA),
                                      Color(0xFF764BA2)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF7C3AED).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _formatDate(message.timestamp),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          MessageBubble(
                            message: message,
                            isMe: message.senderId == currentUserId,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              if (chatProvider.isUserTyping(_chatId)) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Color(0xFF1E1E1E) : Color(0xFFF5F3FF),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF667EEA).withOpacity(0.2),
                            Color(0xFF764BA2).withOpacity(0.1)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TypingIndicator(),
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF7C3AED).withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.attach_file, color: Colors.white),
                    onPressed: () {},
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Color(0xFF2D2D2D) : Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Color(0xFF7C3AED).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      onChanged: (text) {
                        if (text.isNotEmpty) {
                          _handleTyping();
                        }
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Сообщение...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.black54,
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
                Container(
                  decoration: BoxDecoration(
                    gradient: _messageController.text.trim().isNotEmpty
                        ? LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          )
                        : null,
                    color: _messageController.text.trim().isEmpty
                        ? (isDarkMode ? Color(0xFF2D2D2D) : Colors.grey[300])
                        : null,
                    shape: BoxShape.circle,
                    boxShadow: _messageController.text.trim().isNotEmpty
                        ? [
                            BoxShadow(
                              color: Color(0xFF7C3AED).withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _messageController.text.trim().isNotEmpty
                        ? _sendMessage
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
