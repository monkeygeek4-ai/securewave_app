// lib/screens/new_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/chat_provider.dart';
import '../models/chat.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  final _api = ApiService.instance;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

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
    try {
      setState(() {
        _isLoading = true;
      });

      final users = await _api.getUsers();

      setState(() {
        _users = users.map((user) {
          if (user is Map<String, dynamic>) {
            return user;
          } else {
            return {
              'id': user.id ?? '',
              'username': user.username ?? '',
              'fullName': user.fullName ?? user.username ?? '',
              'email': user.email ?? '',
              'phone': user.phone ?? '',
              'avatar': user.avatar,
            };
          }
        }).toList();
        _filteredUsers = _users;
        _isLoading = false;
      });
    } catch (e) {
      print('[NewChat] Ошибка загрузки пользователей: $e');
      setState(() {
        _users = [];
        _filteredUsers = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить пользователей'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: _loadUsers,
            ),
          ),
        );
      }
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final username = user['username']?.toString().toLowerCase() ?? '';
          final fullName = (user['fullName'] ?? user['full_name'])
                  ?.toString()
                  .toLowerCase() ??
              '';
          final email = user['email']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          return username.contains(searchLower) ||
              fullName.contains(searchLower) ||
              email.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _startChat(Map<String, dynamic> user) async {
    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final userId = user['id'].toString();
      final userName = user['fullName']?.toString() ??
          user['username']?.toString() ??
          'Unknown';

      // Используем createChat из API service
      final newChat = await _api.createChat(
        userId: userId,
        userName: userName,
      );

      // Закрываем индикатор загрузки
      if (mounted) {
        Navigator.pop(context);
      }

      if (newChat != null && mounted) {
        // Обновляем список чатов в провайдере
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.loadChats();

        // Переходим к экрану чата
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chat: newChat),
          ),
        );
      }
    } catch (e) {
      print('[NewChat] Ошибка создания чата: $e');

      // Закрываем индикатор загрузки если он открыт
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Показываем ошибку
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось создать чат. Попробуйте снова.'),
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
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Обновить список',
          ),
        ],
      ),
      body: Column(
        children: [
          // Поиск
          Container(
            color: Color(0xFF2B5CE6),
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              style: TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Поиск пользователей...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Список пользователей
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF2B5CE6),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Загрузка пользователей...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
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
                              _searchController.text.isEmpty
                                  ? 'Нет доступных пользователей'
                                  : 'Пользователи не найдены',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_searchController.text.isEmpty) ...[
                              SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _loadUsers,
                                icon: Icon(Icons.refresh),
                                label: Text('Обновить'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFF2B5CE6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: Color(0xFF2B5CE6),
                        child: ListView.builder(
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final username =
                                user['username']?.toString() ?? 'unknown';
                            final fullName =
                                (user['fullName'] ?? user['full_name'])
                                    ?.toString();
                            final email = user['email']?.toString();
                            final phone = user['phone']?.toString();

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(0xFF2B5CE6),
                                child: user['avatar'] != null
                                    ? ClipOval(
                                        child: Image.network(
                                          user['avatar'],
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Text(
                                              username[0].toUpperCase(),
                                              style: TextStyle(
                                                  color: Colors.white),
                                            );
                                          },
                                        ),
                                      )
                                    : Text(
                                        username[0].toUpperCase(),
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                              title: Text(
                                fullName ?? username,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('@$username'),
                                  if (email != null && email.isNotEmpty)
                                    Text(
                                      email,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  if (phone != null && phone.isNotEmpty)
                                    Text(
                                      phone,
                                      style: TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.message,
                                color: Color(0xFF2B5CE6),
                                size: 20,
                              ),
                              onTap: () => _startChat(user),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
