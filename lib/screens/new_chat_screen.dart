// lib/screens/new_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({Key? key}) : super(key: key);

  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final ApiService _api = ApiService();
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
      final users = await _api.getUsers();
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      print('[NewChat] Ошибка загрузки пользователей: $e');
      setState(() => _isLoading = false);
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
                (user.email ?? '').toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _startChat(User user) async {
    final chatProvider = context.read<ChatProvider>();
    final isTablet = MediaQuery.of(context).size.width > 600;

    setState(() => _isLoading = true);

    try {
      print('[NewChat] Создание чата с пользователем: ${user.username}');

      // Создаем или получаем чат с пользователем
      await chatProvider.createOrGetChat(user.id);

      // Загружаем обновленный список чатов
      await chatProvider.loadChats();

      // Ждем немного, чтобы чат точно появился в списке
      await Future.delayed(const Duration(milliseconds: 300));

      // Находим созданный чат
      final createdChat = chatProvider.chats.firstWhere(
        (chat) => chat.participants?.contains(user.id) ?? false,
        orElse: () => chatProvider.chats.first,
      );

      if (mounted) {
        // Закрываем экран выбора пользователя
        Navigator.of(context).pop();

        // Если планшет - НЕ открываем новый экран, просто выбираем чат
        if (isTablet) {
          // На планшете просто триггерим выбор чата в HomeScreen
          // Это обновит правую панель без открытия нового экрана
          return;
        }

        // На мобильном - открываем экран чата
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(chat: createdChat),
          ),
        );
      }
    } catch (e) {
      print('[NewChat] Ошибка создания чата: $e');
      setState(() => _isLoading = false);

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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'Пользователи не найдены',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF2B5CE6),
                              child: Text(
                                user.username.isNotEmpty
                                    ? user.username[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              user.username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: user.email != null
                                ? Text(
                                    user.email!,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  )
                                : null,
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
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
