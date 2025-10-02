// lib/models/user.dart (ОБНОВЛЕННАЯ ВЕРСИЯ)

class User {
  final String id;
  final String username;
  final String? email;
  final String? fullName;
  final String? phone;
  final bool phoneVerified;
  final String? bio;
  final String? avatar;
  final bool isOnline;
  final String? lastSeen;
  final String? createdAt;
  final String? nickname;

  User({
    required this.id,
    required this.username,
    this.email,
    this.fullName,
    this.phone,
    this.phoneVerified = false,
    this.bio,
    this.avatar,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
    this.nickname,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      fullName: json['fullName'] ?? json['full_name'],
      phone: json['phone'],
      phoneVerified: json['phoneVerified'] == true ||
          json['phone_verified'] == true ||
          json['phoneVerified'] == 1 ||
          json['phone_verified'] == 1,
      bio: json['bio'],
      avatar: json['avatar'] ?? json['avatar_url'] ?? json['avatarUrl'],
      isOnline: json['isOnline'] == true ||
          json['is_online'] == true ||
          json['isOnline'] == 1 ||
          json['is_online'] == 1,
      lastSeen: json['lastSeen'] ?? json['last_seen'],
      createdAt: json['createdAt'] ?? json['created_at'],
      nickname: json['nickname'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'phoneVerified': phoneVerified,
      'bio': bio,
      'avatar': avatar,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'createdAt': createdAt,
      'nickname': nickname,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? phone,
    bool? phoneVerified,
    String? bio,
    String? avatar,
    bool? isOnline,
    String? lastSeen,
    String? createdAt,
    String? nickname,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      bio: bio ?? this.bio,
      avatar: avatar ?? this.avatar,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      nickname: nickname ?? this.nickname,
    );
  }
}
