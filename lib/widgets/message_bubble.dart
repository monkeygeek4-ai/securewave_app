import 'package:flutter/material.dart';
import '../models/message.dart';
import 'package:intl/intl.dart';

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
    final time = DateTime.tryParse(message.timestamp) ?? DateTime.now();
    final timeStr = DateFormat('HH:mm').format(time);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Имя отправителя (для групповых чатов)
            if (!isMe && message.senderName != null)
              Padding(
                padding: EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  message.senderName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Пузырь сообщения
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMe ? Color(0xFF2B5CE6) : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                  bottomLeft: isMe ? Radius.circular(15) : Radius.circular(3),
                  bottomRight: isMe ? Radius.circular(3) : Radius.circular(15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Ответ на сообщение (если есть)
                  if (message.replyToId != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Ответ на сообщение',
                        style: TextStyle(
                          fontSize: 12,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),

                  // Контент сообщения
                  if (message.type == 'text')
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    )
                  else if (message.type == 'image' && message.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.mediaUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 200,
                          height: 100,
                          color: Colors.grey[400],
                          child: Icon(Icons.broken_image, color: Colors.white),
                        ),
                      ),
                    )
                  else if (message.type == 'file')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 16,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Файл',
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),

                  // Время и статус
                  SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited)
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text(
                            'изменено',
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white60 : Colors.black45,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      if (isMe) ...[
                        SizedBox(width: 4),
                        _buildStatusIcon(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color = Colors.white70;

    switch (message.status) {
      case 'отправлено':
        icon = Icons.check;
        break;
      case 'доставлено':
        icon = Icons.done_all;
        break;
      case 'прочитано':
        icon = Icons.done_all;
        color = Colors.white;
        break;
      default:
        icon = Icons.schedule;
        break;
    }

    return Icon(
      icon,
      size: 14,
      color: color,
    );
  }
}
