// lib/screens/home_screen.dart
// UI redesign: dark glassmorphism + space gradient + bottom navigation

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'dart:async';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/webrtc_service.dart';
import '../models/chat.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'chat_view.dart';
import 'profile/profile_settings_screen.dart';
import 'storage_settings_screen.dart';
import 'permissions_settings_screen.dart';
import '../utils/image_utils.dart';
import '../services/api_service.dart';
import '../widgets/report_dialog.dart';
import 'blocked_users_screen.dart';

// ── Space-theme palette ──────────────────────────────────────────────────────
const _kDeepSpace   = Color(0xFF0A0415);
const _kSpaceMid    = Color(0xFF120B2E);
const _kPurple      = Color(0xFF7C3AED);
const _kPurpleLight = Color(0xFF9B5CF6);
const _kIndigo      = Color(0xFF4338CA);
const _kBlue        = Color(0xFF1E40AF);
const _kOnline      = Color(0xFF22C55E);
const _kUnread      = Color(0xFFEC4899);

// ── Glassmorphism helper ─────────────────────────────────────────────────────
Widget _glass({
  required Widget child,
  double blur = 16,
  double opacity = 0.12,
  BorderRadius? radius,
  EdgeInsets? padding,
  Gradient? gradient,
}) {
  return ClipRRect(
    borderRadius: radius ?? BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: gradient ??
              LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(opacity),
                  Colors.white.withOpacity(opacity * 0.5),
                ],
              ),
          borderRadius: radius ?? BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: child,
      ),
    ),
  );
}


// ── Stars painter ────────────────────────────────────────────────────────────
class _StarsPainter extends CustomPainter {
  final List<_Star> stars;
  _StarsPainter(this.stars);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      paint.color = Colors.white.withOpacity(s.opacity);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}

class _Star {
  final double x, y, radius, opacity;
  const _Star(this.x, this.y, this.radius, this.opacity);
}

// Pre-generated star field (deterministic)
final _kStars = List<_Star>.generate(120, (i) {
  final seed = i * 2654435761;
  final x = ((seed ^ (seed >> 13)) & 0xFFFF) / 0xFFFF;
  final y = ((seed ^ (seed >> 7)) & 0xFFFF) / 0xFFFF;
  final r = (i % 3 == 0) ? 1.5 : (i % 2 == 0) ? 1.0 : 0.6;
  final op = (0.3 + ((seed & 0xFF) / 0xFF) * 0.6).clamp(0.2, 0.9);
  return _Star(x, y, r, op);
});

// ── Main widget ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String? _selectedChatId;
  bool _showProfileSettings = false;
  bool _showMenu = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  Timer? _refreshTimer;
  StreamSubscription? _callSubscription;

  // Bottom nav
  int _bottomIndex = 0; // 0=Chats 1=Calls 2=Contacts 3=Settings

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForIncomingCalls();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadChats();
      _startPeriodicRefresh();
    });
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
      _callSubscription = WebRTCService.instance.callState.listen((_) {});
    } catch (_) {}
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_selectedChatId == null && !_showProfileSettings && !_showMenu) {
        _refreshChats(showIndicator: false);
      }
    });
  }

  Future<void> _refreshChats({bool showIndicator = true}) async {
    try {
      await context.read<ChatProvider>().loadChats();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted && showIndicator) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось загрузить чаты'),
            action: SnackBarAction(label: 'Повторить', onPressed: _refreshChats),
          ),
        );
      }
    }
  }

  void _searchChats(String query) => setState(() => _isSearching = query.isNotEmpty);

  List<Chat> _getFilteredChats(List<Chat> chats) {
    if (!_isSearching || _searchController.text.isEmpty) return chats;
    final q = _searchController.text.toLowerCase();
    return chats.where((c) =>
        c.name.toLowerCase().contains(q) ||
        (c.lastMessage?.toLowerCase().contains(q) ?? false)).toList();
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
    });
    final cp = context.read<ChatProvider>();
    if (cp.currentChatId != chatId) cp.setCurrentChatId(chatId);
  }

  void _openProfileSettings() {
    final isTablet = MediaQuery.of(context).size.width > 600;
    if (isTablet) {
      setState(() { _selectedChatId = null; _showProfileSettings = true; });
    } else {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
    }
  }

  void _openStorageSettings() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const StorageSettingsScreen()));

  void _openPermissionsSettings() => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const PermissionsSettingsScreen()));

  // ── Chat options ───────────────────────────────────────────────────────────
  void _showChatOptions(Chat chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _glass(
        radius: const BorderRadius.vertical(top: Radius.circular(24)),
        opacity: 0.18,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white30,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(chat.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              Divider(color: Colors.white.withOpacity(0.1)),
              _bottomSheetTile(Icons.flag_outlined, 'Пожаловаться', Colors.orange,
                  () { Navigator.pop(ctx); _reportUser(chat); }),
              _bottomSheetTile(Icons.block, 'Заблокировать', Colors.red,
                  () { Navigator.pop(ctx); _confirmBlockUser(chat); }),
              _bottomSheetTile(Icons.delete_outline, 'Удалить чат', Colors.red,
                  () { Navigator.pop(ctx); _confirmDeleteChat(chat); }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  ListTile _bottomSheetTile(IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color == Colors.red ? Colors.red : Colors.white)),
        onTap: onTap,
      );

  void _reportUser(Chat chat) {
    final cp = context.read<ChatProvider>();
    final uid = cp.currentUserId;
    if (uid == null) return;
    final otherId = chat.getOtherParticipantId(uid);
    if (otherId == null) return;
    final otherInt = int.tryParse(otherId);
    if (otherInt == null) return;
    ReportDialog.show(context,
        reportedUserId: otherInt,
        reportedUsername: chat.name,
        chatId: int.tryParse(chat.id));
  }

  void _confirmBlockUser(Chat chat) {
    final cp = context.read<ChatProvider>();
    final uid = cp.currentUserId;
    if (uid == null) return;
    final otherId = chat.getOtherParticipantId(uid);
    if (otherId == null) return;
    final otherInt = int.tryParse(otherId);
    if (otherInt == null) return;
    showDialog(
      context: context,
      builder: (ctx) => _spaceDialog(
        title: 'Заблокировать',
        content: 'Вы уверены, что хотите заблокировать ${chat.name}?',
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async { Navigator.pop(ctx); await _blockUser(otherInt, chat.name); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser(int userId, String username) async {
    try {
      final res = await ApiService.instance.blockUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['success'] == true ? '$username заблокирован' : res['error'] ?? 'Ошибка'),
          backgroundColor: res['success'] == true ? Colors.green : Colors.red,
        ));
        if (res['success'] == true) context.read<ChatProvider>().loadChats();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  void _confirmDeleteChat(Chat chat) {
    showDialog(
      context: context,
      builder: (ctx) => _spaceDialog(
        title: 'Удалить чат?',
        content: 'Чат с ${chat.name} будет удалён.',
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () async { Navigator.pop(ctx); await _performDeleteChat(chat, deleteForEveryone: false); },
            child: const Text('Удалить у себя', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () async { Navigator.pop(ctx); await _performDeleteChat(chat, deleteForEveryone: true); },
            child: const Text('Удалить у всех', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteChat(Chat chat, {required bool deleteForEveryone}) async {
    try {
      await context.read<ChatProvider>().deleteChat(chat.id, deleteForEveryone: deleteForEveryone);
      if (mounted) {
        if (_selectedChatId == chat.id) setState(() => _selectedChatId = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(deleteForEveryone ? 'Чат удалён у всех' : 'Чат удалён'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить'), backgroundColor: Colors.red));
    }
  }

  // Space-themed dialog
  Widget _spaceDialog({required String title, required String content, required List<Widget> actions}) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: _glass(
        opacity: 0.2,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(content, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final showDetail = isTablet && (_showProfileSettings || _selectedChatId != null);

    return Scaffold(
      backgroundColor: _kDeepSpace,
      body: Stack(
        children: [
          // ── Space background ──
          Positioned.fill(child: _buildSpaceBackground()),
          // ── Content ──
          Row(
            children: [
              SizedBox(
                width: showDetail ? 350 : MediaQuery.of(context).size.width,
                child: _showMenu ? _buildMenuScreen() : _buildChatListPanel(),
              ),
              if (showDetail)
                Expanded(
                  child: _showProfileSettings
                      ? const ProfileSettingsScreen()
                      : _selectedChatId != null
                          ? Consumer<ChatProvider>(
                              builder: (ctx, cp, _) {
                                final chat = cp.getChatById(_selectedChatId!);
                                if (chat == null) return const Center(child: Text('Чат не найден', style: TextStyle(color: Colors.white)));
                                return ChatView(chat: chat);
                              },
                            )
                          : Center(
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.white24),
                                const SizedBox(height: 16),
                                const Text('Выберите чат', style: TextStyle(color: Colors.white38, fontSize: 20)),
                              ]),
                            ),
                ),
            ],
          ),
        ],
      ),
      // ── Bottom Navigation ──
      bottomNavigationBar: _showMenu || _showProfileSettings
          ? null
          : _buildBottomNav(),
      // ── FAB ──
      floatingActionButton: !_showMenu && !_showProfileSettings && (_selectedChatId == null || !isTablet)
          ? _buildFAB()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
    );
  }

  // ── Space background ───────────────────────────────────────────────────────
  Widget _buildSpaceBackground() {
    return Stack(
      children: [
        // Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.2, -0.5),
              radius: 1.4,
              colors: [
                Color(0xFF2D1B69),
                Color(0xFF1A0B3D),
                Color(0xFF0A0415),
                Color(0xFF050210),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        // Stars
        CustomPaint(
          painter: _StarsPainter(_kStars),
          child: const SizedBox.expand(),
        ),
        // Nebula glow top-right
        Positioned(
          top: -100, right: -80,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFF7C3AED).withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Nebula glow bottom-left
        Positioned(
          bottom: -60, left: -60,
          child: Container(
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0xFF4338CA).withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.04),
              ],
            ),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(0, Icons.chat_bubble_rounded, 'Chats'),
                  _navItem(1, Icons.call_rounded, 'Calls'),
                  _navItem(2, Icons.contacts_rounded, 'Contacts'),
                  _navItem(3, Icons.settings_rounded, 'Settings'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final active = _bottomIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _bottomIndex = index);
        if (index == 3) _openProfileSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
                )
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? Colors.white : Colors.white38, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return _glass(
      radius: BorderRadius.circular(20),
      opacity: 0.18,
      gradient: const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NewChatScreen())),
        child: const SizedBox(
          width: 56, height: 56,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  // ── Chat list panel ────────────────────────────────────────────────────────
  Widget _buildChatListPanel() {
    return Column(
      children: [
        _buildAppBar(),
        _buildSearchBar(),
        Expanded(child: _buildChatList()),
      ],
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [

            const Spacer(),

          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: _glass(
        radius: BorderRadius.circular(30),
        opacity: 0.1,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: _searchController,
          onChanged: _searchChats,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search conversations',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5)),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: Colors.white.withOpacity(0.5)),
                    onPressed: () { _searchController.clear(); _searchChats(''); })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return Consumer<ChatProvider>(
      builder: (ctx, cp, _) {
        if (cp.isLoading && cp.chats.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: _kPurple));
        }
        final chats = _getFilteredChats(cp.chats);
        if (chats.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.chat_bubble_outline, size: 60, color: Colors.white24),
              const SizedBox(height: 16),
              Text(_isSearching ? 'Ничего не найдено' : 'Нет чатов',
                  style: const TextStyle(fontSize: 18, color: Colors.white38)),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: _refreshChats,
          color: _kPurple,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: chats.length,
            itemBuilder: (ctx, i) => _buildChatTile(chats[i]),
          ),
        );
      },
    );
  }

  // ── Chat tile ──────────────────────────────────────────────────────────────
  Widget _buildChatTile(Chat chat) {
    final isSelected = _selectedChatId == chat.id;
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _glass(
        radius: BorderRadius.circular(20),
        opacity: isSelected ? 0.22 : 0.1,
        gradient: isSelected
            ? LinearGradient(colors: [
                _kPurple.withOpacity(0.35),
                _kIndigo.withOpacity(0.2),
              ])
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (isTablet) {
              _selectChat(chat.id);
            } else {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => ChatScreen(chat: chat))).then((_) {
                _refreshChats(showIndicator: false);
              });
            }
          },
          onLongPress: () => _showChatOptions(chat),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // ── Avatar ──
                Stack(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_kPurpleLight, _kIndigo],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kPurple.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: ClipOval(child: _buildAvatar(chat)),
                    ),
                    // Online dot — always at bottom-right when online
                    if (chat.isOnline)
                      Positioned(
                        right: 2, bottom: 2,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: _kOnline,
                            shape: BoxShape.circle,
                            border: Border.all(color: _kDeepSpace, width: 2),
                            boxShadow: [BoxShadow(
                              color: _kOnline.withOpacity(0.6),
                              blurRadius: 6,
                            )],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // ── Name + message ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chat.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        chat.lastMessage ?? 'Нет сообщений',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: chat.unreadCount > 0
                              ? Colors.white.withOpacity(0.85)
                              : Colors.white.withOpacity(0.45),
                          fontSize: 13,
                          fontWeight: chat.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Time + unread badge ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (chat.lastMessageTime != null)
                      Text(
                        _formatTime(chat.lastMessageTime!),
                        style: TextStyle(
                          fontSize: 11,
                          color: chat.unreadCount > 0
                              ? Colors.white.withOpacity(0.85)
                              : Colors.white.withOpacity(0.4),
                          fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (chat.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_kUnread, Color(0xFF9B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: _kUnread.withOpacity(0.45),
                            blurRadius: 8,
                          )],
                        ),
                        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                        child: Text(
                          chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (!isTablet)
                      GestureDetector(
                        onTap: () => _showChatOptions(chat),
                        child: Icon(Icons.more_vert_rounded,
                            size: 18, color: Colors.white.withOpacity(0.3)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Chat chat) {
    if (chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: ImageUtils.getAvatarUrl(chat.avatarUrl) ?? '',
        fit: BoxFit.cover, width: 56, height: 56,
        placeholder: (_, __) => _avatarPlaceholder(chat.name),
        errorWidget: (_, __, ___) => _avatarPlaceholder(chat.name),
      );
    }
    return _avatarPlaceholder(chat.name);
  }

  Widget _avatarPlaceholder(String name) => Center(
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
    ),
  );

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Вчера';
    if (diff.inDays < 7) return '${diff.inDays} дн.';
    return '${time.day}.${time.month}';
  }

  // ── Menu screen ────────────────────────────────────────────────────────────
  Widget _buildMenuScreen() {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final currentUser = authProvider.currentUser;
    final isIOS = Platform.isIOS;

    return Column(
      children: [
        // Header
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() { _showMenu = false; _showProfileSettings = false; }),
                  child: _glass(
                    radius: BorderRadius.circular(14),
                    opacity: 0.12,
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Меню',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Profile header
              SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: currentUser?.avatar != null && currentUser!.avatar!.isNotEmpty
                          ? Image.network(ImageUtils.getAvatarUrl(currentUser.avatar) ?? '', fit: BoxFit.cover)
                          : Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF2D1B69), _kDeepSpace],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Center(child: Icon(Icons.person, size: 100, color: Colors.white.withOpacity(0.3))),
                            ),
                    ),
                    Positioned.fill(child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        ),
                      ),
                    )),
                    Positioned(left: 16, right: 16, bottom: 16, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentUser?.fullName ?? currentUser?.username ?? 'User',
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(currentUser?.nickname != null ? '@${currentUser!.nickname}' : '@${currentUser?.username ?? ''}',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
                        const SizedBox(height: 8),
                        _glass(
                          radius: BorderRadius.circular(20),
                          opacity: 0.2,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: _kOnline, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text('online', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ]),
                        ),
                      ],
                    )),
                  ],
                ),
              ),
              // Menu items
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _menuTile(FontAwesomeIcons.gear, 'Настройки профиля', 'Редактировать данные', _openProfileSettings),
                    _menuTile(FontAwesomeIcons.download, 'Загрузка и хранение', 'Настройки медиафайлов', _openStorageSettings),
                    if (!isIOS)
                      _menuTile(Icons.security, 'Разрешения', 'Управление разрешениями', _openPermissionsSettings),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _glass(
                        radius: BorderRadius.circular(16),
                        opacity: 0.1,
                        child: ListTile(
                          leading: Icon(FontAwesomeIcons.circleHalfStroke, color: _kPurpleLight, size: 20),
                          title: const Text('Тема', style: TextStyle(color: Colors.white)),
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            onChanged: (_) => themeProvider.toggleTheme(),
                            activeColor: _kPurple,
                          ),
                        ),
                      ),
                    ),
                    _menuTile(FontAwesomeIcons.circleInfo, 'О приложении', 'SecureWave v1.0.0', () {
                      showAboutDialog(context: context,
                          applicationName: 'SecureWave',
                          applicationVersion: '1.0.0',
                          applicationIcon: const Icon(Icons.security, size: 50, color: _kPurple),
                          children: [
                            const Text('Безопасное приложение для общения с видеозвонками'),
                            const SizedBox(height: 10),
                            const Text('© 2025 SecureWave Team'),
                          ]);
                    }),
                    const SizedBox(height: 8),
                    _glass(
                      radius: BorderRadius.circular(16),
                      opacity: 0.1,
                      child: ListTile(
                        leading: const Icon(FontAwesomeIcons.rightFromBracket, color: Colors.red, size: 20),
                        title: const Text('Выход', style: TextStyle(color: Colors.red)),
                        onTap: () async {
                          final confirm = await showDialog<bool>(context: context,
                              builder: (ctx) => _spaceDialog(
                                title: 'Выход',
                                content: 'Вы уверены, что хотите выйти?',
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Выйти', style: TextStyle(color: Colors.red))),
                                ],
                              ));
                          if (confirm == true) {
                            authProvider.logout();
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuTile(dynamic icon, String title, String subtitle, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _glass(
        radius: BorderRadius.circular(16),
        opacity: 0.1,
        child: ListTile(
          leading: icon is IconData
              ? Icon(icon, color: _kPurpleLight, size: 20)
              : FaIcon(icon as IconData, color: _kPurpleLight, size: 20),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
          onTap: onTap,
        ),
      ),
    );
  }
}
