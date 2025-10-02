// lib/models/user.dart

class User {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? fullName;
  final String? phone;
  final String? bio;
  final String? nickname;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final bool? isOnline;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.fullName,
    this.phone,
    this.bio,
    this.nickname,
    this.createdAt,
    this.lastSeen,
    this.isOnline,
  });

  // Геттер для совместимости со старым кодом
  String? get avatar => avatarUrl;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'] ?? json['avatar'],
      fullName: json['full_name'] ?? json['fullName'],
      phone: json['phone'],
      bio: json['bio'],
      nickname: json['nickname'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'].toString())
          : null,
      isOnline: json['is_online'] ?? json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'full_name': fullName,
      'phone': phone,
      'bio': bio,
      'nickname': nickname,
      'created_at': createdAt?.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
      'is_online': isOnline,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? fullName,
    String? phone,
    String? bio,
    String? nickname,
    DateTime? createdAt,
    DateTime? lastSeen,
    bool? isOnline,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      nickname: nickname ?? this.nickname,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
