// lib/screens/chat_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';

class ChatView extends StatefulWidget {
  final Chat chat;
  final VoidCallback? onBack;

  const ChatView({
    Key? key,
    required this.chat,
    this.onBack,
  }) : super(key: key);

  @override
  _ChatViewState createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;
  DateTime? _lastTypingTime;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    await context.read<ChatProvider>().loadMessages(widget.chat.id);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await context.read<ChatProvider>().sendMessage(
            chatId: widget.chat.id,
            content: text,
          );
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отправки сообщения'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleTyping() {
    final now = DateTime.now();

    if (!_isTyping ||
        (_lastTypingTime != null &&
            now.difference(_lastTypingTime!).inSeconds > 2)) {
      _isTyping = true;
      _lastTypingTime = now;

      context.read<ChatProvider>().sendTypingStatus(widget.chat.id, true);

      Future.delayed(Duration(seconds: 3), () {
        if (mounted && _isTyping) {
          _isTyping = false;
          context.read<ChatProvider>().sendTypingStatus(widget.chat.id, false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.currentUser?.id ?? '';

    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Заголовок чата
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: widget.onBack,
                  ),
                SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF2B5CE6),
                  backgroundImage: widget.chat.avatarUrl != null
                      ? NetworkImage(widget.chat.avatarUrl!)
                      : null,
                  child: widget.chat.avatarUrl == null
                      ? Text(
                          widget.chat.name[0].toUpperCase(),
                          style: TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chat.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Consumer<ChatProvider>(
                        builder: (context, chatProvider, _) {
                          final typingUser =
                              chatProvider.getTypingUserName(widget.chat.id);

                          if (typingUser != null) {
                            return Text(
                              'печатает...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2B5CE6),
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }

                          return Text(
                            widget.chat.isOnline ? 'в сети' : 'не в сети',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.chat.isOnline
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    // Поиск по чату
                  },
                ),
                IconButton(
                  icon: Icon(Icons.more_vert),
                  onPressed: () {
                    // Меню чата
                  },
                ),
              ],
            ),
          ),

          // Сообщения
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final messages = chatProvider.getMessages(widget.chat.id);

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Начните общение',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Отправьте первое сообщение',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    final showAvatar = index == 0 ||
                        messages[index - 1].senderId != message.senderId;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: 4,
                        left: isMe ? 60 : 0,
                        right: isMe ? 0 : 60,
                      ),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe && showAvatar)
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[400],
                              child: Text(
                                widget.chat.name[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (!isMe && !showAvatar) SizedBox(width: 32),
                          SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isMe ? Color(0xFF2B5CE6) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      color:
                                          isMe ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _formatMessageTime(
                                        DateTime.tryParse(message.timestamp) ??
                                            DateTime.now()),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Поле ввода
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: () {
                    // Прикрепить файл
                  },
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: 'Сообщение',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (_) => _handleTyping(),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF2B5CE6),
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    if (messageDay == today) {
      return '$hour:$minute';
    } else if (messageDay == today.subtract(Duration(days: 1))) {
      return 'Вчера $hour:$minute';
    } else {
      return '${time.day}.${time.month} $hour:$minute';
    }
  }
}
