// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/webrtc_service.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'chat_view.dart';
import 'profile/profile_settings_screen.dart';
import 'invites_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _selectedChatId;
  bool _showProfileSettings = false;
  bool _showInvites = false;
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
      _showInvites = false;
    });

    final chatProvider = context.read<ChatProvider>();
    chatProvider.setCurrentChatId(chatId);
    chatProvider.markMessagesAsRead(chatId);
  }

  void _openProfileSettings() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (isTablet) {
      setState(() {
        _selectedChatId = null;
        _showProfileSettings = true;
        _showInvites = false;
      });
      Navigator.pop(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileSettingsScreen(),
        ),
      );
    }
  }

  void _openInvites() {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (isTablet) {
      setState(() {
        _selectedChatId = null;
        _showProfileSettings = false;
        _showInvites = true;
      });
      Navigator.pop(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvitesScreen(),
        ),
      );
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
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await context.read<ChatProvider>().deleteChat(chat.id);

                if (mounted) {
                  if (_selectedChatId == chat.id) {
                    setState(() {
                      _selectedChatId = null;
                    });
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Чат удален'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Не удалось удалить чат'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      drawer: _buildDrawer(),
      body: Row(
        children: [
          Container(
            width: isTablet ? 350 : MediaQuery.of(context).size.width,
            child: _buildChatListPanel(hasDrawer: true),
          ),
          if (isTablet)
            Expanded(
              child: _showProfileSettings
                  ? ProfileSettingsScreen()
                  : _showInvites
                      ? InvitesScreen()
                      : _selectedChatId != null
                          ? Consumer<ChatProvider>(
                              builder: (context, chatProvider, _) {
                                final chat =
                                    chatProvider.getChatById(_selectedChatId!);
                                if (chat == null) {
                                  return Center(child: Text('Чат не найден'));
                                }
                                return ChatView(chat: chat);
                              },
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Выберите чат',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),
        ],
      ),
      floatingActionButton: !isTablet
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NewChatScreen()),
                );
              },
              backgroundColor: Color(0xFF7C3AED),
              child: Icon(Icons.add_comment, color: Colors.white),
              tooltip: 'Новый чат',
            )
          : null,
    );
  }

  Widget _buildDrawer() {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final currentUser = authProvider.currentUser;
    final isDarkMode = themeProvider.isDarkMode;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF7C3AED).withOpacity(0.2),
                    Color(0xFF1E1E1E),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
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
              onTap: _openProfileSettings,
            ),
            ListTile(
              leading: Icon(Icons.card_giftcard, color: Color(0xFF7C3AED)),
              title: Text(
                'Инвайты',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Управление приглашениями',
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              onTap: _openInvites,
            ),
            Divider(),
            ListTile(
              leading: Icon(
                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: Color(0xFF7C3AED),
              ),
              title: Text(
                'Тема',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              trailing: Switch(
                value: isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
                activeColor: Color(0xFF7C3AED),
              ),
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: Color(0xFF7C3AED)),
              title: Text(
                'О приложении',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'SecureWave',
                  applicationVersion: '1.0.0',
                  applicationIcon: Icon(
                    Icons.security,
                    size: 50,
                    color: Color(0xFF7C3AED),
                  ),
                  children: [
                    Text('Безопасный мессенджер с видеозвонками'),
                    SizedBox(height: 10),
                    Text('© 2025 SecureWave Team'),
                  ],
                );
              },
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red),
              title: Text(
                'Выход',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Выход'),
                    content: Text('Вы уверены, что хотите выйти?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child:
                            Text('Выйти', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  authProvider.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatListPanel({required bool hasDrawer}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        border: isTablet
            ? Border(
                right: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                ),
              )
            : null,
      ),
      child: Column(
        children: [
          _buildAppBar(hasDrawer: hasDrawer),
          _buildSearchBar(),
          Expanded(child: _buildChatList()),
        ],
      ),
    );
  }

  Widget _buildAppBar({required bool hasDrawer}) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
      ),
      child: Row(
        children: [
          if (hasDrawer)
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Expanded(
            child: Text(
              'SecureWave',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isTablet)
            IconButton(
              icon: Icon(Icons.add_comment, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NewChatScreen()),
                );
              },
              tooltip: 'Новый чат',
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(12),
      color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: _searchChats,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Поиск чатов...',
          hintStyle:
              TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
          prefixIcon:
              Icon(Icons.search, color: isDarkMode ? Colors.white70 : null),
          filled: true,
          fillColor: isDarkMode ? Color(0xFF2D2D2D) : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        if (chatProvider.isLoading && chatProvider.chats.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
          );
        }

        final filteredChats = _getFilteredChats(chatProvider.chats);

        if (filteredChats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 60, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  _isSearching ? 'Ничего не найдено' : 'Нет чатов',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshChats,
          color: Color(0xFF7C3AED),
          child: ListView.builder(
            itemCount: filteredChats.length,
            itemBuilder: (context, index) {
              final chat = filteredChats[index];
              return _buildChatTile(chat);
            },
          ),
        );
      },
    );
  }

  Widget _buildChatTile(Chat chat) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedChatId == chat.id;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      color: isSelected
          ? (isDarkMode
              ? Color(0xFF7C3AED).withOpacity(0.2)
              : Color(0xFF7C3AED).withOpacity(0.1))
          : null,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xFF7C3AED),
              backgroundImage:
                  chat.avatarUrl != null ? NetworkImage(chat.avatarUrl!) : null,
              child: chat.avatarUrl == null
                  ? Text(
                      chat.name[0].toUpperCase(),
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    )
                  : null,
            ),
            if (chat.unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    chat.unreadCount > 9 ? '9+' : '${chat.unreadCount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            if (chat.isPinned)
              Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.push_pin, size: 14, color: Color(0xFF7C3AED)),
              ),
            Expanded(
              child: Text(
                chat.name,
                style: TextStyle(
                  fontWeight: chat.unreadCount > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          chat.lastMessage ?? 'Нет сообщений',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.black54,
            fontWeight:
                chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (chat.lastMessageTime != null)
              Text(
                _formatTime(chat.lastMessageTime!),
                style: TextStyle(
                  fontSize: 12,
                  color: chat.unreadCount > 0
                      ? Color(0xFF7C3AED)
                      : (isDarkMode ? Colors.white60 : Colors.black45),
                  fontWeight: chat.unreadCount > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            if (!isTablet)
              IconButton(
                icon: Icon(Icons.more_vert, size: 18),
                onPressed: () => _showChatOptions(chat),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
          ],
        ),
        onTap: () {
          if (isTablet) {
            _selectChat(chat.id);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(chat: chat),
              ),
            ).then((_) => _refreshChats(showIndicator: false));
          }
        },
        onLongPress: () => _showChatOptions(chat),
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
      return '${diff.inDays} дн. назад';
    } else {
      return '${time.day}.${time.month}.${time.year}';
    }
  }
}
