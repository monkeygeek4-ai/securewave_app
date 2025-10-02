// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/webrtc_service.dart';
import '../models/chat.dart';
import 'new_chat_screen.dart';
import 'chat_view.dart';
import 'profile/profile_settings_screen.dart';
import 'invites_screen.dart'; // ДОБАВЛЕН ИМПОРТ

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _selectedChatId;
  bool _showProfileSettings = false;
  String? _selectedSettingsTab; // ДОБАВЛЕНО: 'profile' или 'invites'
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Timer? _refreshTimer;
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _listenForIncomingCalls();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkChats();
      _startPeriodicRefresh();
    });

    print('[Home] Экран главной страницы открыт');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _refreshTimer?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  void _listenForIncomingCalls() {
    try {
      _callSubscription = WebRTCService.instance.callState.listen((call) {
        // Обработка входящих звонков через overlay
      });
    } catch (e) {
      print('[Home] Ошибка подписки на звонки: $e');
    }
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(Duration(seconds: 3), (_) {
      final isTablet = MediaQuery.of(context).size.width > 600;
      if (isTablet || _selectedChatId == null) {
        _refreshChats(showIndicator: false);
      }
    });
  }

  Future<void> _checkChats() async {
    final chatProvider = context.read<ChatProvider>();
    if (chatProvider.chats.isEmpty && !chatProvider.isLoading) {
      await _refreshChats();
    }
  }

  Future<void> _refreshChats({bool showIndicator = true}) async {
    try {
      await context.read<ChatProvider>().loadChats();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('[Home] Ошибка обновления чатов: $e');
      if (mounted && showIndicator) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось загрузить чаты'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: _refreshChats,
            ),
          ),
        );
      }
    }
  }

  void _searchChats(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
    });
  }

  List<Chat> _getFilteredChats(List<Chat> chats) {
    if (!_isSearching || _searchController.text.isEmpty) {
      return chats;
    }

    final query = _searchController.text.toLowerCase();
    return chats.where((chat) {
      return chat.name.toLowerCase().contains(query) ||
          (chat.lastMessage?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshChats();
      _startPeriodicRefresh();
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel();
    }
  }

  void _selectChat(String chatId) {
    setState(() {
      _selectedChatId = chatId;
      _showProfileSettings = false;
      _selectedSettingsTab = null; // ДОБАВЛЕНО
    });

    final chatProvider = context.read<ChatProvider>();
    chatProvider.setCurrentChatId(chatId);
    chatProvider.markMessagesAsRead(chatId);
  }

  // ОБНОВЛЕНО: добавлен параметр tab
  void _openProfileSettings({String tab = 'profile'}) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (isTablet) {
      setState(() {
        _selectedChatId = null;
        _showProfileSettings = true;
        _selectedSettingsTab = tab; // ДОБАВЛЕНО
      });
      Navigator.pop(context);
    } else {
      // На телефоне открываем соответствующий экран
      if (tab == 'invites') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => InvitesScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileSettingsScreen()),
        );
      }
    }
  }

  void _showChatOptions(Chat chat) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(chat.isPinned ? 'Открепить' : 'Закрепить'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<ChatProvider>().togglePinChat(chat.id);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Удалить чат', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteChat(chat);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteChat(Chat chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить чат?'),
        content: Text('Чат с ${chat.name} будет удален безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatProvider>().deleteChat(chat.id);
              if (_selectedChatId == chat.id) {
                setState(() {
                  _selectedChatId = null;
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: isTablet ? null : _buildAppBar(),
      drawer: isTablet ? null : _buildDrawer(),
      body: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Поиск...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: _searchChats,
            )
          : Text('SecureWave'),
      backgroundColor: Color(0xFF7C3AED),
      foregroundColor: Colors.white,
      actions: [
        if (!_isSearching)
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => setState(() => _isSearching = true),
          )
        else
          IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
              });
            },
          ),
      ],
    );
  }

  Widget _buildDrawer() {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final currentUser = authProvider.currentUser;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    Color(0xFF7C3AED).withOpacity(0.2),
                    Color(0xFF1E1E1E),
                  ]
                : [
                    Color(0xFF7C3AED).withOpacity(0.1),
                    Colors.white,
                  ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage: currentUser?.avatar != null &&
                            currentUser!.avatar!.isNotEmpty
                        ? NetworkImage(currentUser.avatar!)
                        : null,
                    child: currentUser?.avatar == null ||
                            currentUser!.avatar!.isEmpty
                        ? Icon(Icons.person, size: 35, color: Color(0xFF7C3AED))
                        : null,
                  ),
                  SizedBox(height: 12),
                  Text(
                    currentUser?.fullName ?? currentUser?.username ?? 'User',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    currentUser?.nickname != null
                        ? '@${currentUser!.nickname}'
                        : '@${currentUser?.username ?? ''}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.settings, color: Color(0xFF7C3AED)),
              title: Text(
                'Настройки профиля',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Редактировать данные и фото',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _openProfileSettings(tab: 'profile');
              },
            ),
            // ДОБАВЛЕНО: Пункт "Мои инвайты"
            ListTile(
              leading: Icon(Icons.card_giftcard, color: Color(0xFF7C3AED)),
              title: Text(
                'Мои инвайты',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Пригласить друзей',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _openProfileSettings(tab: 'invites');
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: Color(0xFF7C3AED),
              ),
              title: Text(
                isDarkMode ? 'Светлая тема' : 'Темная тема',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                themeProvider.toggleTheme();
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text(
                'Выход',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await context.read<AuthProvider>().logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (isTablet && (_selectedChatId != null || _showProfileSettings)) {
      return SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NewChatScreen()),
        );

        if (result != null && mounted) {
          _refreshChats();
        }
      },
      backgroundColor: Color(0xFF7C3AED),
      child: Icon(Icons.add_comment, color: Colors.white),
    );
  }

  Widget _buildMobileLayout() {
    if (_selectedChatId != null) {
      final chatProvider = context.watch<ChatProvider>();
      final chat = chatProvider.getChatById(_selectedChatId!);
      if (chat != null) {
        return ChatView(chat: chat);
      }
    }
    return _buildChatList();
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        Container(
          width: 350,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildChatList()),
            ],
          ),
        ),
        // ОБНОВЛЕНО: показываем правильный контент
        if (_selectedChatId != null)
          Expanded(
            flex: 2,
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final chat = chatProvider.getChatById(_selectedChatId!);
                if (chat == null) {
                  return Center(child: Text('Чат не найден'));
                }
                return ChatView(chat: chat);
              },
            ),
          )
        else if (_showProfileSettings)
          Expanded(
            flex: 2,
            child: _selectedSettingsTab == 'invites'
                ? InvitesScreen() // ДОБАВЛЕНО
                : ProfileSettingsScreen(),
          )
        else
          Expanded(
            flex: 2,
            child: _buildEmptyState(),
          ),
      ],
    );
  }

  Widget _buildChatList() {
    final chatProvider = context.watch<ChatProvider>();
    final chats = _getFilteredChats(chatProvider.chats);

    if (chatProvider.isLoading && chats.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
      );
    }

    if (chats.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshChats,
      color: Color(0xFF7C3AED),
      child: ListView.builder(
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          final isSelected = chat.id == _selectedChatId;

          return InkWell(
            onTap: () => _selectChat(chat.id),
            onLongPress: () => _showChatOptions(chat),
            child: Container(
              color: isSelected
                  ? Color(0xFF7C3AED).withOpacity(0.1)
                  : Colors.transparent,
              child: _buildChatItem(chat),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatItem(Chat chat) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage:
                chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty
                    ? NetworkImage(chat.avatarUrl!)
                    : null,
            child: chat.avatarUrl == null || chat.avatarUrl!.isEmpty
                ? Text(
                    chat.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          if (chat.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.name,
              style: TextStyle(
                fontWeight:
                    chat.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.lastMessageTime != null)
            Text(
              _formatTime(chat.lastMessageTime!),
              style: TextStyle(
                fontSize: 12,
                color:
                    chat.unreadCount > 0 ? Color(0xFF7C3AED) : Colors.grey[600],
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessage ?? 'Нет сообщений',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: chat.unreadCount > 0 ? null : Colors.grey[600],
                fontWeight:
                    chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFF7C3AED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${chat.unreadCount}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      trailing: chat.isPinned
          ? Icon(Icons.push_pin, size: 18, color: Color(0xFF7C3AED))
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 100,
            color: Colors.grey[400],
          ),
          SizedBox(height: 20),
          Text(
            'Нет чатов',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Нажмите + чтобы начать новый чат',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Вчера';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} дн назад';
    } else {
      return '${time.day}.${time.month}.${time.year}';
    }
  }
}
