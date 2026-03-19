// lib/widgets/chat_list_item.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/chat.dart';
import '../utils/image_utils.dart';

class ChatListItem extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? typingUser;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
    this.onLongPress,
    this.typingUser,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF2B5CE6),
            child: chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: ImageUtils.getAvatarUrl(chat.avatarUrl) ?? '',
                      fit: BoxFit.cover,
                      width: 56,
                      height: 56,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF2B5CE6),
                        child: Center(
                          child: Text(
                            chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF2B5CE6),
                        child: Center(
                          child: Text(
                            chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Text(
                    chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (chat.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.isMuted)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.volume_off,
                size: 16,
                color: Colors.grey,
              ),
            ),
        ],
      ),
      subtitle: typingUser != null
          ? Text(
              '$typingUser печатает...',
              style: const TextStyle(
                color: Color(0xFF2B5CE6),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              chat.lastMessage ?? 'Нет сообщений',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Кружок с количеством непрочитанных слева
          if (chat.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xFF2B5CE6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  chat.unreadCount > 9 ? '9+' : chat.unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Время справа
          if (chat.lastMessageTime != null)
            Text(
              _formatTime(chat.lastMessageTime!),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 365) {
      return '${time.year}';
    } else if (diff.inDays > 7) {
      return '${time.day}.${time.month.toString().padLeft(2, '0')}';
    } else if (diff.inDays > 0) {
      if (diff.inDays == 1) {
        return 'Вчера';
      } else {
        return '${diff.inDays} д';
      }
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ч';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} м';
    } else {
      return 'Сейчас';
    }
  }
}
