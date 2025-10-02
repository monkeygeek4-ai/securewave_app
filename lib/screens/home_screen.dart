// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../services/webrtc_service.dart';
import '../models/chat.dart';
import '../models/call.dart';
import '../widgets/chat_list_item.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'chat_view.dart';
import 'profile/profile_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _selectedChatId;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Timer? _refreshTimer;
  Call? _incomingCall;
  StreamSubscription? _callSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Подписываемся на входящие звонки
    _listenForIncomingCalls();

    // Проверяем наличие чатов после загрузки экрана
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
        if (call != null && call.status == CallStatus.incoming) {
          setState(() {
            _incomingCall = call;
          });
        } else if (call == null || call.status != CallStatus.incoming) {
          setState(() {
            _incomingCall = null;
          });
        }
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
    });

    final chatProvider = context.read<ChatProvider>();
    chatProvider.setCurrentChatId(chatId);
    chatProvider.markMessagesAsRead(chatId);
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
      drawer: isTablet ? null : _buildDrawer(),
      body: Row(
        children: [
          // Левая панель - список чатов
          Container(
            width: isTablet ? 350 : MediaQuery.of(context).size.width,
            child: _buildChatListPanel(hasDrawer: !isTablet),
          ),

          // Правая панель - открытый чат (только на планшете)
          if (isTablet)
            Expanded(
              child: _selectedChatId != null
                  ? Consumer<ChatProvider>(
                      builder: (context, chatProvider, _) {
                        final chat = chatProvider.getChatById(_selectedChatId!);
                        if (chat == null) {
                          return Center(child: Text('Чат не найден'));
                        }
                        return ChatView(chatId: chat.id);
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
              child: Icon(Icons.edit),
              backgroundColor: Color(0xFF2B5CE6),
            )
          : null,
    );
  }

  Widget _buildChatListPanel({bool hasDrawer = false}) {
    return Column(
      children: [
        // Заголовок и поиск
        Container(
          color: Color(0xFF2B5CE6),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16,
            right: 16,
            bottom: 8,
          ),
          child: Column(
            children: [
              // Заголовок с меню
              Row(
                children: [
                  if (hasDrawer)
                    Builder(
                      builder: (context) => IconButton(
                        icon: Icon(Icons.menu, color: Colors.white),
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                    ),
                  Expanded(
                    child: Text(
                      'SecureWave',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => NewChatScreen()),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Поиск
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _searchChats,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Поиск чатов...',
                    hintStyle: TextStyle(color: Colors.white70),
                    prefixIcon: Icon(Icons.search, color: Colors.white70),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Список чатов
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              if (chatProvider.isLoading && chatProvider.chats.isEmpty) {
                return Center(child: CircularProgressIndicator());
              }

              final filteredChats = _getFilteredChats(chatProvider.chats);

              if (filteredChats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _isSearching ? 'Ничего не найдено' : 'Нет чатов',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (!_isSearching) ...[
                        SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NewChatScreen(),
                              ),
                            );
                          },
                          child: Text('Создать новый чат'),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshChats,
                child: ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    final isSelected = chat.id == _selectedChatId;

                    return ChatListItem(
                      chat: chat,
                      isSelected: isSelected,
                      onTap: () {
                        final isTablet =
                            MediaQuery.of(context).size.width > 600;

                        if (isTablet) {
                          _selectChat(chat.id);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(chatId: chat.id),
                            ),
                          );
                        }
                      },
                      onLongPress: () => _showChatOptions(chat),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
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
            // Красивый заголовок с градиентом
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

            // Пункт "Настройки профиля"
            ListTile(
              leading: Icon(Icons.settings, color: Color(0xFF7C3AED)),
              title: Text('Настройки профиля'),
              subtitle: Text('Редактировать данные и фото'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSettingsScreen(),
                  ),
                );
              },
            ),

            Divider(),

            // Пункт "Тема"
            ListTile(
              leading: Icon(Icons.brightness_6, color: Colors.grey[700]),
              title: Text('Тема'),
              trailing: Switch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (value) {
                  // TODO: Переключение темы
                },
                activeColor: Color(0xFF7C3AED),
              ),
            ),

            // Пункт "О приложении"
            ListTile(
              leading: Icon(Icons.info_outline, color: Colors.grey[700]),
              title: Text('О приложении'),
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

            // Пункт "Выход"
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
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text('Выйти'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                }
              },
            ),

            SizedBox(height: 20),

            // Версия приложения внизу
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'SecureWave v1.0.0',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
