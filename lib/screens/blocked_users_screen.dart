import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);

    try {
      final users = await ApiService.instance.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _unblockUser(int userId, String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Разблокировать?'),
        content: Text('Разблокировать пользователя $username?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Разблокировать'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await ApiService.instance.unblockUser(userId);

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пользователь разблокирован'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBlockedUsers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Ошибка'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Заблокированные'),
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.block,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет заблокированных пользователей',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBlockedUsers,
                  child: ListView.builder(
                    itemCount: _blockedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _blockedUsers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                          child: Text(
                            (user['username'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(user['username'] ?? 'Неизвестно'),
                        subtitle: Text(
                          user['full_name'] ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: TextButton(
                          onPressed: () => _unblockUser(
                            user['id'] as int,
                            user['username'] as String? ?? '',
                          ),
                          child: const Text(
                            'Разблокировать',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
