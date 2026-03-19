// lib/screens/new_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import '../utils/image_utils.dart';
import '../widgets/report_dialog.dart';
import 'create_group_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final users = await ApiService.instance.getUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      // print('[NewChat] Ошибка загрузки пользователей: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось загрузить пользователей'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers
            .where((user) =>
                user.username.toLowerCase().contains(query.toLowerCase()) ||
                (user.fullName ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showUserActions(User user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user.fullName ?? user.username,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF7C3AED)),
              title: const Text('Начать чат'),
              onTap: () {
                Navigator.pop(context);
                _startChat(user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text('Пожаловаться'),
              onTap: () {
                Navigator.pop(context);
                ReportDialog.show(
                  context,
                  reportedUserId: int.tryParse(user.id) ?? 0,
                  reportedUsername: user.fullName ?? user.username,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Заблокировать'),
              onTap: () {
                Navigator.pop(context);
                _blockUser(user);
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _blockUser(User user) async {
    final userId = int.tryParse(user.id);
    if (userId == null) return;

    try {
      final response = await ApiService.instance.blockUser(userId);

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.fullName ?? user.username} заблокирован'),
              backgroundColor: Colors.green,
            ),
          );
          // Удаляем из списка
          setState(() {
            _allUsers.removeWhere((u) => u.id == user.id);
            _filteredUsers.removeWhere((u) => u.id == user.id);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Ошибка блокировки'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startChat(User user) async {
    final chatProvider = context.read<ChatProvider>();

    try {
      await chatProvider.createOrGetChat(user.id);
      await chatProvider.loadChats();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Чат с ${user.username} создан'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // print('[NewChat] Ошибка создания чата: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось создать чат'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый чат'),
        backgroundColor: const Color(0xFF2B5CE6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Кнопка создания группового чата
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateGroupScreen(allUsers: _allUsers),
                  ),
                );
              },
              icon: const Icon(Icons.group_add),
              label: const Text('Создать групповой чат'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Поиск пользователей
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Поиск пользователей...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // Список пользователей
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Пользователи не найдены',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF7C3AED),
                              backgroundImage: user.avatarUrl != null &&
                                      user.avatarUrl!.isNotEmpty
                                  ? NetworkImage(ImageUtils.getAvatarUrl(user.avatarUrl) ?? '')
                                  : null,
                              child: user.avatarUrl == null ||
                                      user.avatarUrl!.isEmpty
                                  ? Text(
                                      user.username[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.fullName ?? user.username,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: user.fullName != null
                                ? Text('@${user.username}')
                                : null,
                            trailing: const Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFF7C3AED),
                            ),
                            onTap: () => _startChat(user),
                            onLongPress: () => _showUserActions(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
