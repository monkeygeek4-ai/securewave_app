class User {
  final String id;
  final String username;
  final String? email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final bool isOnline;
  final bool? isVerified;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.username,
    this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.bio,
    this.isOnline = false,
    this.isVerified,
    this.lastSeen,
    this.createdAt,
  });

  // Получение отображаемого имени
  String get displayName => fullName ?? username;

  // Получение инициалов
  String get initials {
    final name = displayName;
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // Форматированный номер телефона
  String? get formattedPhone {
    if (phone == null || phone!.isEmpty) return null;

    // Простое форматирование для российских номеров
    if (phone!.startsWith('+7') && phone!.length >= 11) {
      final cleaned = phone!.replaceAll(RegExp(r'[^\d+]'), '');
      return '${cleaned.substring(0, 2)} (${cleaned.substring(2, 5)}) ${cleaned.substring(5, 8)}-${cleaned.substring(8, 10)}-${cleaned.substring(10)}';
    }
    return phone;
  }

  // Статус "был в сети"
  String get lastSeenText {
    if (isOnline) return 'в сети';

    if (lastSeen == null) return 'недавно';

    final now = DateTime.now();
    final difference = now.difference(lastSeen!);

    if (difference.inMinutes < 1) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'был${_getGenderSuffix()} $minutes ${_pluralize(minutes, 'минуту', 'минуты', 'минут')} назад';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'был${_getGenderSuffix()} $hours ${_pluralize(hours, 'час', 'часа', 'часов')} назад';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return 'был${_getGenderSuffix()} $days ${_pluralize(days, 'день', 'дня', 'дней')} назад';
    } else {
      return 'давно';
    }
  }

  String _getGenderSuffix() {
    // Простая эвристика для определения пола по имени
    // В реальном приложении это должно храниться в профиле
    final name = fullName?.toLowerCase() ?? username.toLowerCase();
    if (name.endsWith('а') || name.endsWith('я')) {
      return 'а'; // женский род
    }
    return ''; // мужской род
  }

  String _pluralize(int count, String one, String few, String many) {
    if (count % 100 >= 11 && count % 100 <= 19) {
      return many;
    }

    switch (count % 10) {
      case 1:
        return one;
      case 2:
      case 3:
      case 4:
        return few;
      default:
        return many;
    }
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      fullName: json['fullName'] ?? json['full_name'],
      phone: json['phone'],
      avatarUrl: json['avatarUrl'] ?? json['avatar_url'] ?? json['avatar'],
      bio: json['bio'],
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
      isVerified: json['isVerified'] ?? json['is_verified'],
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : (json['last_seen'] != null
              ? DateTime.parse(json['last_seen'])
              : null),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'isOnline': isOnline,
      'isVerified': isVerified,
      'lastSeen': lastSeen?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? bio,
    bool? isOnline,
    bool? isVerified,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, fullName: $fullName, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
