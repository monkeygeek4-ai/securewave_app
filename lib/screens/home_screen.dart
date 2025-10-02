// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/chat_provider.dart';
import '../services/websocket_manager.dart';
import '../services/webrtc_service.dart';
import '../models/chat.dart';
import '../models/call.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/incoming_call_overlay.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'chat_view.dart';

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
      // Слушаем состояние звонка из WebRTC сервиса
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
      // Продолжаем работу без звонков, если WebRTC недоступен
    }
  }

  void _startPeriodicRefresh() {
    // Обновляем список чатов каждые 3 секунды
    _refreshTimer = Timer.periodic(Duration(seconds: 3), (_) {
      // Обновляем только если нет открытого чата на мобильном
      // или всегда на планшете
      final isTablet = MediaQuery.of(context).size.width > 600;
      if (isTablet || _selectedChatId == null) {
        _refreshChats(showIndicator: false);
      }
    });
  }

  Future<void> _checkChats() async {
    final chatProvider = context.read<ChatProvider>();

    // Если чатов нет и они не загружаются, пробуем загрузить еще раз
    if (chatProvider.chats.isEmpty && !chatProvider.isLoading) {
      await _refreshChats();
    }
  }

  Future<void> _refreshChats({bool showIndicator = true}) async {
    try {
      await context.read<ChatProvider>().loadChats();

      // Принудительно обновляем UI после загрузки
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
      _startPeriodicRefresh(); // Возобновляем обновление
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel(); // Останавливаем обновление
    }
  }

  void _selectChat(String chatId) {
    setState(() {
      _selectedChatId = chatId;
    });

    // Отмечаем сообщения как прочитанные при выборе чата
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
                // ИСПРАВЛЕНО: убрали обработку результата deleted
                await context.read<ChatProvider>().deleteChat(chat.id);

                if (mounted) {
                  // Если удаленный чат был выбран, сбрасываем выбор
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
      drawer: isTablet ? null : CustomDrawer(),
      body: Stack(
        children: [
          Row(
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
                            final chat =
                                chatProvider.getChatById(_selectedChatId!);
                            if (chat == null) {
                              return _buildEmptyChatArea();
                            }
                            return ChatView(
                              key: ValueKey(_selectedChatId),
                              chat: chat,
                              onBack: () {
                                setState(() {
                                  _selectedChatId = null;
                                });
                              },
                            );
                          },
                        )
                      : _buildEmptyChatArea(),
                ),
            ],
          ),

          // FAB для создания нового чата (только на мобильном)
          if (!isTablet)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NewChatScreen()),
                  );
                },
                child: Icon(Icons.edit),
                backgroundColor: Color(0xFF2B5CE6),
              ),
            ),

          // Оверлей входящего звонка
          if (_incomingCall != null)
            IncomingCallOverlay(
              incomingCall: _incomingCall!,
              onDismiss: () {
                setState(() {
                  _incomingCall = null;
                });
              },
            ),
        ],
      ),
      floatingActionButton: isTablet
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
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            height: MediaQuery.of(context).size.height * 0.7,
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: CustomDrawer(),
                          ),
                        );
                      },
                    ),
                  Text(
                    'SecureWave',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  // Кнопка обновления
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    onPressed: _refreshChats,
                    tooltip: 'Обновить чаты',
                  ),
                  // Индикатор подключения
                  StreamBuilder<ConnectionStatus>(
                    stream: WebSocketManager.instance.connectionStatus,
                    builder: (context, snapshot) {
                      final status =
                          snapshot.data ?? ConnectionStatus.disconnected;
                      return Container(
                        width: 10,
                        height: 10,
                        margin: EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: status == ConnectionStatus.connected
                              ? Colors.green
                              : status == ConnectionStatus.connecting
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      );
                    },
                  ),
                ],
              ),
              // Строка поиска
              Container(
                margin: EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(25),
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
        // Список чатов с RefreshIndicator
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, chatProvider, _) {
              if (chatProvider.isLoading && chatProvider.chats.isEmpty) {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }

              final filteredChats = _getFilteredChats(chatProvider.chats);

              if (filteredChats.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refreshChats,
                  child: ListView(
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isSearching
                                    ? Icons.search_off
                                    : Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                _isSearching ? 'Чаты не найдены' : 'Нет чатов',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (!_isSearching) ...[
                                SizedBox(height: 8),
                                Text(
                                  'Создайте новый чат',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NewChatScreen(),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.add),
                                  label: Text('Новый чат'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF2B5CE6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshChats,
                child: ListView.builder(
                  physics: AlwaysScrollableScrollPhysics(),
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];

                    // Для планшетного режима - подсветка выбранного чата
                    final isSelected = _selectedChatId == chat.id;

                    // Получаем информацию о печатающем пользователе
                    final typingUser = chatProvider.getTypingUserName(chat.id);

                    return Container(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                      child: ChatListItem(
                        key: ValueKey(chat.id),
                        chat: chat,
                        typingUser: typingUser,
                        onTap: () {
                          if (MediaQuery.of(context).size.width > 600) {
                            _selectChat(chat.id);
                          } else {
                            // Для мобильного - открываем полноэкранный чат
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(chat: chat),
                              ),
                            ).then((_) {
                              // После возврата обновляем список
                              _refreshChats(showIndicator: false);
                            });
                          }
                        },
                        onLongPress: () => _showChatOptions(chat),
                      ),
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

  Widget _buildEmptyChatArea() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Выберите чат',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'или создайте новый',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => NewChatScreen()),
                );
              },
              icon: Icon(Icons.add),
              label: Text('Новый чат'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2B5CE6),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
