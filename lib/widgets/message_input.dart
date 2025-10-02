import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSend;
  final Function(bool) onTyping;
  final VoidCallback onAttachment;

  const MessageInput({
    Key? key,
    required this.controller,
    required this.onSend,
    required this.onTyping,
    required this.onAttachment,
  }) : super(key: key);

  @override
  _MessageInputState createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
      widget.onTyping(hasText);
    }
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -2),
            blurRadius: 4,
            color: Colors.black12,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Кнопка вложений
            IconButton(
              icon: Icon(
                Icons.attach_file,
                color: Colors.grey[600],
              ),
              onPressed: widget.onAttachment,
              tooltip: 'Прикрепить файл',
            ),

            // Поле ввода
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        maxLines: 5,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Введите сообщение...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),

                    // Эмодзи кнопка
                    IconButton(
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.grey[600],
                        size: 24,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Эмодзи в разработке'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      tooltip: 'Эмодзи',
                    ),
                  ],
                ),
              ),
            ),

            // Кнопка отправки/голосового сообщения
            AnimatedSwitcher(
              duration: Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: _hasText
                  ? IconButton(
                      key: ValueKey('send'),
                      icon: Icon(
                        Icons.send,
                        color: Color(0xFF2B5CE6),
                      ),
                      onPressed: _handleSend,
                      tooltip: 'Отправить',
                    )
                  : IconButton(
                      key: ValueKey('mic'),
                      icon: Icon(
                        Icons.mic,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Голосовые сообщения в разработке'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      tooltip: 'Голосовое сообщение',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
