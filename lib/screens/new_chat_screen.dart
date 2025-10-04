// lib/screens/new_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import 'create_group_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({Key? key}) : super(key: key);

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
      print('[NewChat] Ошибка загрузки пользователей: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[NewChat] Ошибка создания чата: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
        title: Text('Новый чат'),
        backgroundColor: Color(0xFF2B5CE6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Кнопка создания группового чата
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateGroupScreen(allUsers: _allUsers),
                  ),
                );
              },
              icon: Icon(Icons.group_add),
              label: Text('Создать групповой чат'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          Divider(height: 1),

          // Поиск пользователей
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Поиск пользователей...',
                prefixIcon: Icon(Icons.search),
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
                ? Center(child: CircularProgressIndicator())
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
                            SizedBox(height: 16),
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
                              backgroundColor: Color(0xFF7C3AED),
                              backgroundImage: user.avatarUrl != null &&
                                      user.avatarUrl!.isNotEmpty
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null ||
                                      user.avatarUrl!.isEmpty
                                  ? Text(
                                      user.username[0].toUpperCase(),
                                      style: TextStyle(color: Colors.white),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.fullName ?? user.username,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: user.fullName != null
                                ? Text('@${user.username}')
                                : null,
                            trailing: Icon(
                              Icons.chat_bubble_outline,
                              color: Color(0xFF7C3AED),
                            ),
                            onTap: () => _startChat(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
