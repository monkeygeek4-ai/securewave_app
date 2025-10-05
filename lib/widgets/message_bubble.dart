// lib/widgets/message_bubble.dart

import 'package:flutter/material.dart';
import '../models/message.dart';
import '../utils/app_colors.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  // Получаем текст статуса звонка
  String _getCallStatusText() {
    final status = message.callStatus?.toLowerCase() ?? '';

    switch (status) {
      case 'outgoing':
        return 'Исходящий звонок';
      case 'incoming':
        return 'Входящий звонок';
      case 'cancelled':
      case 'canceled':
        return 'Отменен';
      case 'missed':
        return 'Пропущенный';
      case 'rejected':
      case 'declined':
        return 'Отклонен';
      case 'ended':
        return isMe ? 'Исходящий звонок' : 'Входящий звонок';
      default:
        return 'Звонок';
    }
  }

  // Получаем иконку для звонка
  IconData _getCallIcon() {
    final status = message.callStatus?.toLowerCase() ?? '';

    switch (status) {
      case 'ended':
        return Icons.check_circle;
      case 'cancelled':
      case 'canceled':
      case 'missed':
        return Icons.phone_missed;
      case 'declined':
        return Icons.cancel;
      default:
        return message.callType == 'video' ? Icons.videocam : Icons.call;
    }
  }

  // Получаем цвет для статуса звонка
  Color _getCallStatusColor(BuildContext context) {
    final status = message.callStatus?.toLowerCase() ?? '';

    switch (status) {
      case 'ended':
        return AppColors.online;
      case 'cancelled':
      case 'canceled':
      case 'missed':
        return Colors.orange;
      case 'declined':
        return Colors.red;
      default:
        return isMe ? Colors.white : AppColors.primaryPurple;
    }
  }

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
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.transparent,
                    child: Text(
                      message.senderName?.isNotEmpty == true
                          ? message.senderName![0].toUpperCase()
                          : 'U',
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
                  gradient: isMe ? AppColors.primaryGradient : null,
                  color: !isMe ? AppColors.getCardColor(context) : null,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: isMe ? Radius.circular(20) : Radius.circular(4),
                    bottomRight:
                        isMe ? Radius.circular(4) : Radius.circular(20),
                  ),
                  boxShadow: [
                    isMe ? AppColors.messageShadow : AppColors.cardShadow,
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
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    // Контент сообщения
                    if (message.type == 'text')
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : AppColors.getTextColor(context),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      )
                    else if (message.type == 'call')
                      // НОВЫЙ БЛОК: Отображение звонков
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCallIcon(),
                            size: 20,
                            color: _getCallStatusColor(context),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getCallStatusText(),
                                style: TextStyle(
                                  color: isMe
                                      ? Colors.white
                                      : AppColors.getTextColor(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (message.callDuration != null &&
                                  message.callDuration! > 0)
                                Text(
                                  _formatDuration(message.callDuration!),
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white.withOpacity(0.8)
                                        : AppColors.getSecondaryTextColor(
                                            context),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
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
                                  AppColors.gradientStart.withOpacity(0.3),
                                  AppColors.gradientEnd.withOpacity(0.3),
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
                              : AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file,
                              size: 18,
                              color:
                                  isMe ? Colors.white : AppColors.primaryPurple,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Файл',
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : AppColors.primaryPurple,
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
                                    : AppColors.primaryPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'изм.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white.withOpacity(0.8)
                                      : AppColors.primaryPurple,
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
                                : AppColors.getSecondaryTextColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isMe) ...[
                          SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 16,
                            color: message.isRead
                                ? AppColors.online
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

  // Форматирование длительности звонка
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds % 60;
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }
}
