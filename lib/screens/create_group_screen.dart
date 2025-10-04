// lib/screens/create_group_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';

class CreateGroupScreen extends StatefulWidget {
  final List<User> allUsers;

  const CreateGroupScreen({Key? key, required this.allUsers}) : super(key: key);

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  List<User> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.allUsers;
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = widget.allUsers;
      } else {
        _filteredUsers = widget.allUsers
            .where((user) =>
                user.username.toLowerCase().contains(query.toLowerCase()) ||
                (user.fullName ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();

    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Введите название группы'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Выберите минимум 2 участников'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final chatProvider = context.read<ChatProvider>();

      // Создаем групповой чат
      await chatProvider.createGroupChat(
        groupName,
        _selectedUserIds.toList(),
      );

      if (mounted) {
        Navigator.of(context).pop(); // Закрываем экран создания группы
        Navigator.of(context).pop(); // Закрываем экран выбора чата

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Группа "$groupName" создана'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('[CreateGroup] Ошибка создания группы: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось создать группу'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedUsers = widget.allUsers
        .where((user) => _selectedUserIds.contains(user.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Создать группу'),
        backgroundColor: Color(0xFF2B5CE6),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _selectedUserIds.length >= 2 ? _createGroup : null,
            child: Text(
              'Создать',
              style: TextStyle(
                color: _selectedUserIds.length >= 2
                    ? Colors.white
                    : Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Название группы
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[50],
            child: TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Название группы',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Выбранные участники
          if (selectedUsers.isNotEmpty)
            Container(
              height: 100,
              padding: EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = selectedUsers[index];
                  return Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Color(0xFF7C3AED),
                              backgroundImage: user.avatarUrl != null &&
                                      user.avatarUrl!.isNotEmpty
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null ||
                                      user.avatarUrl!.isEmpty
                                  ? Text(
                                      user.username.isNotEmpty
                                          ? user.username[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(color: Colors.white),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: -4,
                              top: -4,
                              child: GestureDetector(
                                onTap: () => _toggleUserSelection(user.id),
                                child: Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        SizedBox(
                          width: 60,
                          child: Text(
                            user.username,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          Divider(height: 1),

          // Поиск
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Поиск участников...',
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
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      'Пользователи не найдены',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final isSelected = _selectedUserIds.contains(user.id);

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFF7C3AED),
                          backgroundImage: user.avatarUrl != null &&
                                  user.avatarUrl!.isNotEmpty
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child:
                              user.avatarUrl == null || user.avatarUrl!.isEmpty
                                  ? Text(
                                      user.username.isNotEmpty
                                          ? user.username[0].toUpperCase()
                                          : '?',
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
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleUserSelection(user.id),
                          activeColor: Color(0xFF7C3AED),
                        ),
                        onTap: () => _toggleUserSelection(user.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
