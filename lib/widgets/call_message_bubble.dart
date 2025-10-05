// lib/widgets/call_message_bubble.dart

import 'package:flutter/material.dart';
import '../models/message.dart';
import '../utils/app_colors.dart';

class CallMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const CallMessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds сек';
    }
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String _getCallText() {
    final isVideo = message.callType == 'video';

    switch (message.callStatus) {
      case 'incoming':
        return isVideo ? 'Входящий видеозвонок' : 'Входящий звонок';
      case 'outgoing':
        return isVideo ? 'Исходящий видеозвонок' : 'Исходящий звонок';
      case 'missed':
        return isVideo ? 'Пропущенный видеозвонок' : 'Пропущенный звонок';
      case 'rejected':
        return isVideo ? 'Отклоненный видеозвонок' : 'Отклоненный звонок';
      case 'cancelled':
        return isVideo ? 'Отмененный видеозвонок' : 'Отмененный звонок';
      default:
        return isVideo ? 'Видеозвонок' : 'Звонок';
    }
  }

  IconData _getCallIcon() {
    final isVideo = message.callType == 'video';

    if (message.callStatus == 'incoming') {
      return isVideo ? Icons.videocam : Icons.call_received;
    } else if (message.callStatus == 'outgoing') {
      return isVideo ? Icons.videocam : Icons.call_made;
    } else if (message.callStatus == 'missed') {
      return isVideo ? Icons.videocam_off : Icons.call_missed;
    } else if (message.callStatus == 'rejected' ||
        message.callStatus == 'cancelled') {
      return isVideo ? Icons.videocam_off : Icons.call_end;
    }

    return isVideo ? Icons.videocam : Icons.call;
  }

  Color _getCallColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (message.callStatus) {
      case 'missed':
        return Colors.red;
      case 'rejected':
      case 'cancelled':
        return Colors.orange;
      case 'incoming':
        return Colors.green;
      case 'outgoing':
        return AppColors.primaryPurple;
      default:
        return isDark ? Colors.white70 : Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final callColor = _getCallColor(context);
    final timestamp = DateTime.tryParse(message.timestamp);
    final timeText = timestamp != null
        ? '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: 280),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isMe
                  ? LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    )
                  : null,
              color:
                  isMe ? null : (isDark ? Color(0xFF2D2D2D) : Colors.grey[200]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCallIcon(),
                      color: isMe ? Colors.white : callColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _getCallText(),
                        style: TextStyle(
                          color: isMe
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black87),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (message.callDuration != null &&
                    message.callDuration! > 0) ...[
                  SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : (isDark ? Colors.white60 : Colors.black54),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _formatDuration(message.callDuration!),
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : (isDark ? Colors.white60 : Colors.black54),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 4),
                Text(
                  timeText,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withOpacity(0.7)
                        : (isDark ? Colors.white60 : Colors.black54),
                    fontSize: 11,
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
