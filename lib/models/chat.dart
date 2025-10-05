// lib/models/chat.dart

class Chat {
  final String id;
  final String name;
  final String type;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final bool isPinned;
  final bool isMuted;
  final List<String>? participants;
  final String? receiverId;

  Chat({
    required this.id,
    required this.name,
    required this.type,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
    this.isPinned = false,
    this.isMuted = false,
    this.participants,
    this.receiverId,
  });

  // ДОБАВЛЕНО: Метод для получения ID другого участника (не текущего пользователя)
  String? getOtherParticipantId(String currentUserId) {
    print('[Chat.getOtherParticipantId] Текущий пользователь: $currentUserId');
    print('[Chat.getOtherParticipantId] Участники: $participants');
    print('[Chat.getOtherParticipantId] receiverId: $receiverId');

    // Сначала проверяем поле receiverId (если есть)
    if (receiverId != null &&
        receiverId!.isNotEmpty &&
        receiverId != currentUserId) {
      print(
          '[Chat.getOtherParticipantId] ✅ Используем receiverId: $receiverId');
      return receiverId;
    }

    // Если receiverId нет или он равен текущему пользователю, ищем в participants
    if (participants != null && participants!.isNotEmpty) {
      for (var participantId in participants!) {
        final cleanParticipantId = participantId.trim();
        final cleanCurrentUserId = currentUserId.trim();

        print(
            '[Chat.getOtherParticipantId] Проверяем участника: "$cleanParticipantId" != "$cleanCurrentUserId"');

        if (cleanParticipantId.isNotEmpty &&
            cleanParticipantId != cleanCurrentUserId) {
          print(
              '[Chat.getOtherParticipantId] ✅ Найден другой участник: $cleanParticipantId');
          return cleanParticipantId;
        }
      }
    }

    print('[Chat.getOtherParticipantId] ❌ Другой участник не найден');
    return null;
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    // Парсим participants если есть
    List<String>? participantsList;
    if (json['participants'] != null) {
      if (json['participants'] is String) {
        // PostgreSQL возвращает массив как строку {value1,value2}
        String participantsStr = json['participants'].toString();
        participantsStr =
            participantsStr.replaceAll('{', '').replaceAll('}', '');
        participantsList = participantsStr.isNotEmpty
            ? participantsStr.split(',').map((e) => e.trim()).toList()
            : [];
      } else if (json['participants'] is List) {
        participantsList = List<String>.from(json['participants']);
      }
    }

    return Chat(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Неизвестный',
      type: json['type']?.toString() ?? 'personal',
      avatarUrl: json['avatar'] ?? json['avatarUrl'],
      lastMessage: json['lastMessage'] ?? json['last_message'],
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'])
          : json['last_message_at'] != null
              ? DateTime.parse(json['last_message_at'])
              : null,
      unreadCount: json['unreadCount'] ?? json['unread_count'] ?? 0,
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
      isPinned: json['isPinned'] ?? json['is_pinned'] ?? false,
      isMuted: json['isMuted'] ?? json['is_muted'] ?? false,
      participants: participantsList,
      receiverId:
          json['receiverId']?.toString() ?? json['receiver_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'avatarUrl': avatarUrl,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
      'isPinned': isPinned,
      'isMuted': isMuted,
      'participants': participants,
      'receiverId': receiverId,
    };
  }

  Chat copyWith({
    String? id,
    String? name,
    String? type,
    String? avatarUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isOnline,
    bool? isPinned,
    bool? isMuted,
    List<String>? participants,
    String? receiverId,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      participants: participants ?? this.participants,
      receiverId: receiverId ?? this.receiverId,
    );
  }

  @override
  String toString() {
    return 'Chat(id: $id, name: $name, type: $type, unreadCount: $unreadCount, isOnline: $isOnline, receiverId: $receiverId, participants: $participants)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chat && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
