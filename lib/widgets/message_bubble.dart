// lib/widgets/message_bubble.dart

import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              Padding(
                padding: EdgeInsets.only(right: 8, bottom: 4),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF7C3AED).withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.transparent,
                    child: Text(
                      'U',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: !isMe
                      ? (isDarkMode ? Color(0xFF2D2D2D) : Colors.white)
                      : null,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: isMe ? Radius.circular(20) : Radius.circular(4),
                    bottomRight:
                        isMe ? Radius.circular(4) : Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isMe
                          ? Color(0xFF7C3AED).withOpacity(0.4)
                          : Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe && message.senderName != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                    if (message.type == 'text')
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : (isDarkMode ? Colors.white : Colors.black87),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      )
                    else if (message.type == 'image' &&
                        message.mediaUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          message.mediaUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            width: 200,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF667EEA).withOpacity(0.3),
                                  Color(0xFF764BA2).withOpacity(0.3)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      )
                    else if (message.type == 'file')
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.2)
                              : Color(0xFF7C3AED).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 18,
                              color: isMe ? Colors.white : Color(0xFF7C3AED),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Файл',
                              style: TextStyle(
                                color: isMe ? Colors.white : Color(0xFF7C3AED),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.isEdited)
                          Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.white.withOpacity(0.2)
                                    : Color(0xFF7C3AED).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'изм.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white.withOpacity(0.8)
                                      : Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe
                                ? Colors.white.withOpacity(0.9)
                                : (isDarkMode
                                    ? Colors.white60
                                    : Colors.black54),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isMe) ...[
                          SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 16,
                            color: message.isRead
                                ? Color(0xFF00E676)
                                : Colors.white.withOpacity(0.7),
                          ),
                        ],
                      ],
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

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (e) {
      return '';
    }
  }
}
