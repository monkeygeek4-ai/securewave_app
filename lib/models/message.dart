class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String? senderName;
  final String? senderAvatar;
  final String content;
  final String type; // 'text', 'image', 'video', 'file', 'voice'
  final String timestamp;
  final bool isRead;
  final bool isEdited;
  final String? replyToId;
  final String? mediaUrl;
  final Map<String, dynamic>? metadata;
  final String? status; // 'отправлено', 'доставлено', 'прочитано'
  final int? readCount;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = 'text',
    required this.timestamp,
    this.isRead = false,
    this.isEdited = false,
    this.replyToId,
    this.mediaUrl,
    this.metadata,
    this.status,
    this.readCount,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? json['chat_id']?.toString() ?? '',
      senderId:
          json['senderId']?.toString() ?? json['sender_id']?.toString() ?? '',
      senderName: json['senderName'] ?? json['sender_name'],
      senderAvatar: json['senderAvatar'] ?? json['sender_avatar'],
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      timestamp: json['timestamp'] ??
          json['created_at'] ??
          DateTime.now().toIso8601String(),
      isRead: json['isRead'] ?? json['is_read'] ?? false,
      isEdited: json['isEdited'] ?? json['is_edited'] ?? false,
      replyToId: json['replyToId'] ?? json['reply_to_id'],
      mediaUrl: json['mediaUrl'] ?? json['media_url'],
      metadata: json['metadata'],
      status: json['status'],
      readCount: json['readCount'] ?? json['read_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type,
      'timestamp': timestamp,
      'isRead': isRead,
      'isEdited': isEdited,
      'replyToId': replyToId,
      'mediaUrl': mediaUrl,
      'metadata': metadata,
      'status': status,
      'readCount': readCount,
    };
  }

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    String? type,
    String? timestamp,
    bool? isRead,
    bool? isEdited,
    String? replyToId,
    String? mediaUrl,
    Map<String, dynamic>? metadata,
    String? status,
    int? readCount,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      replyToId: replyToId ?? this.replyToId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      readCount: readCount ?? this.readCount,
    );
  }
}
