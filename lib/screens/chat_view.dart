// lib/screens/chat_view.dart

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
  bool _isSending = false;
  bool _messagesLoaded = false;
  int _previousMessageCount = 0;
  Timer? _typingTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    print('[ChatView] Инициализация для чата: ${widget.chat.id}');
    _messageController.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _startAutoRefresh();
    });
  }

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) {
      print(
          '[ChatView] Чат изменился с ${oldWidget.chat.id} на ${widget.chat.id}');
      _messagesLoaded = false;
      _previousMessageCount = 0;
      _stopAutoRefresh();
      _loadMessages();
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (mounted) {
        _refreshMessages();
      }
    });
    print('[ChatView] ✅ Автообновление запущено (каждые 2 сек)');
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    print('[ChatView] ❌ Автообновление остановлено');
  }

  Future<void> _refreshMessages() async {
    if (!mounted) return;

    try {
      final chatProvider = context.read<ChatProvider>();
      final oldCount = chatProvider.messages.length;

      print(
          '[ChatView] 🔄 Автообновление: текущее количество сообщений: $oldCount');

      await chatProvider.loadMessages(widget.chat.id);

      final newCount = chatProvider.messages.length;

      if (newCount > oldCount) {
        print(
            '[ChatView] 🆕 НОВОЕ СООБЩЕНИЕ! Было: $oldCount, стало: $newCount');
        if (mounted) {
          setState(() {
            _previousMessageCount = newCount;
          });
          _scrollToBottom();
        }
      } else {
        print('[ChatView] ⚪ Новых сообщений нет ($newCount)');
      }
    } catch (e) {
      print('[ChatView] ❌ Ошибка автообновления: $e');
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadMessages() async {
    if (_messagesLoaded) {
      print('[ChatView] ⏭️ Сообщения уже загружены, пропускаем');
      return;
    }

    print(
        '[ChatView] 📥 Первоначальная загрузка сообщений для чата: ${widget.chat.id}');
    final chatProvider = context.read<ChatProvider>();

    if (chatProvider.currentChatId != widget.chat.id) {
      chatProvider.setCurrentChatId(widget.chat.id);
    }

    await chatProvider.loadMessages(widget.chat.id);

    print(
        '[ChatView] ✅ Первоначальная загрузка завершена: ${chatProvider.messages.length} сообщений');

    if (mounted) {
      setState(() {
        _messagesLoaded = true;
        _previousMessageCount = chatProvider.messages.length;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
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

    setState(() {
      _isSending = true;
    });

    _messageController.clear();
    _stopTyping();

    try {
      final chatProvider = context.read<ChatProvider>();
      print('[ChatView] 📤 Отправка сообщения...');

      await chatProvider.sendMessage(text, chatId: widget.chat.id);

      print(
          '[ChatView] ✅ Сообщение отправлено, принудительно обновляем список');

      await chatProvider.loadMessages(widget.chat.id);

      if (mounted) {
        setState(() {
          _isSending = false;
          _previousMessageCount = chatProvider.messages.length;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('[ChatView] ❌ Ошибка отправки сообщения: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки сообщения'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleTyping() {
    final chatProvider = context.read<ChatProvider>();

    if (!_isTyping) {
      _isTyping = true;
      chatProvider.sendTypingStatus(widget.chat.id, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping && mounted) {
      _isTyping = false;
      context.read<ChatProvider>().sendTypingStatus(widget.chat.id, false);
    }
    _typingTimer?.cancel();
  }

  void _startCall(String callType) {
    final chatProvider = context.read<ChatProvider>();
    final currentUserId = chatProvider.currentUserId;

    print('[ChatView] 📞 Инициация звонка');
    print('[ChatView] Текущий пользователь: $currentUserId');
    print('[ChatView] Чат: ${widget.chat}');

    if (currentUserId == null || currentUserId.isEmpty) {
      print('[ChatView] ❌ Текущий пользователь не определен');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: пользователь не авторизован'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // УЛУЧШЕНО: Используем метод из модели Chat
    final receiverId = widget.chat.getOtherParticipantId(currentUserId);

    print('[ChatView] Определен получатель звонка: $receiverId');

    if (receiverId == null || receiverId.isEmpty) {
      print('[ChatView] ❌ Не удалось определить получателя');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось определить получателя звонка'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Проверяем что не звоним сами себе
    if (receiverId == currentUserId) {
      print('[ChatView] ❌ Попытка позвонить самому себе');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Нельзя позвонить самому себе'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    print('[ChatView] ✅ Открываем CallScreen');
    print('[ChatView] - chatId: ${widget.chat.id}');
    print('[ChatView] - receiverId: $receiverId');
    print('[ChatView] - receiverName: ${widget.chat.name}');
    print('[ChatView] - callType: $callType');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          chatId: widget.chat.id,
          receiverId: receiverId,
          receiverName: widget.chat.name,
          receiverAvatar: widget.chat.avatarUrl,
          callType: callType,
        ),
      ),
    );
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
        automaticallyImplyLeading: widget.onBack != null,
        leading: widget.onBack != null
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.chat.avatarUrl == null
                        ? AppColors.primaryGradient
                        : null,
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
                    backgroundImage: widget.chat.avatarUrl != null
                        ? NetworkImage(widget.chat.avatarUrl!)
                        : null,
                    child: widget.chat.avatarUrl == null
                        ? Text(
                            widget.chat.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                if (widget.chat.isOnline)
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
                    widget.chat.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
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
                            fontStyle: FontStyle.italic,
                            color: Colors.white70,
                          ),
                        );
                      }
                      return Text(
                        widget.chat.isOnline ? 'В сети' : 'Не в сети',
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
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  final messages = chatProvider.messages;
                  final isLoading = chatProvider.isLoading;

                  if (messages.length > _previousMessageCount &&
                      _previousMessageCount > 0) {
                    print(
                        '[ChatView] 📜 Обнаружено новое сообщение в UI, прокручиваем вниз');
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _previousMessageCount = messages.length;
                      _scrollToBottom();
                    });
                  }

                  print('[ChatView] 🎨 Рендерим ${messages.length} сообщений');

                  if (isLoading && messages.isEmpty && !_messagesLoaded) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primaryPurple,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Загрузка сообщений...',
                            style: TextStyle(
                              color: AppColors.getSecondaryTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

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
                            isMe:
                                message.senderId == chatProvider.currentUserId,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final typingUser =
                    chatProvider.getTypingUserName(widget.chat.id);
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
                    IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: AppColors.primaryPurple,
                      ),
                      onPressed: () {},
                    ),
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
                        icon: _isSending
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
                            _messageController.text.trim().isEmpty || _isSending
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
