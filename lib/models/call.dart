// lib/models/call.dart

enum CallStatus {
  incoming,
  calling,
  connecting,
  active,
  ended,
  declined,
  failed
}

class Call {
  final String id;
  final String chatId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final String callType; // 'audio' или 'video'
  final CallStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, dynamic>? offer; // Добавлено поле для SDP offer

  Call({
    required this.id,
    required this.chatId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    required this.callType,
    required this.status,
    required this.startTime,
    this.endTime,
    this.offer,
  });

  // Метод для создания копии с измененными полями
  Call copyWith({
    String? id,
    String? chatId,
    String? callerId,
    String? callerName,
    String? callerAvatar,
    String? receiverId,
    String? receiverName,
    String? receiverAvatar,
    String? callType,
    CallStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, dynamic>? offer,
  }) {
    return Call(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatar: receiverAvatar ?? this.receiverAvatar,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      offer: offer ?? this.offer,
    );
  }

  // Длительность звонка
  Duration? get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    if (status == CallStatus.active) {
      return DateTime.now().difference(startTime);
    }
    return null;
  }

  // Форматированная длительность
  String get formattedDuration {
    final dur = duration;
    if (dur == null) return '';

    final minutes = dur.inMinutes;
    final seconds = dur.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isVideo => callType == 'video';
  bool get isAudio => callType == 'audio';
}
