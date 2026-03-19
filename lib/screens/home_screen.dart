import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/chat_list_item.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    await context.read<ChatProvider>().loadChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _selectedIndex == 0
          ? AppBar(
              elevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: Color(0xFF2B5CE6),
              title: null,
              actions: [
                IconButton(
                  icon: Icon(Icons.search, color: Colors.white),
                  onPressed: _showSearch,
                ),
              ],
            )
          : null,
      body: _selectedIndex == 0 ? _buildChatsList() : _buildSettingsPage(),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _startNewChat,
              backgroundColor: Color(0xFF2B5CE6),
              child: Icon(Icons.edit, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Color(0xFF2B5CE6),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildChatsList() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        if (chatProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: Color(0xFF2B5CE6)),
          );
        }

        if (chatProvider.chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
                SizedBox(height: 20),
                Text(
                  'No chats yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                Text(
                  'Start a new conversation',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _startNewChat,
                  icon: Icon(Icons.add),
                  label: Text('New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2B5CE6),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadChats,
          color: Color(0xFF2B5CE6),
          child: ListView.separated(
            itemCount: chatProvider.chats.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, indent: 80, endIndent: 15),
            itemBuilder: (context, index) {
              final chat = chatProvider.chats[index];
              return ChatListItem(
                chat: chat,
                onTap: () => _openChat(chat),
                onLongPress: () => _showChatOptions(chat),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSettingsPage() {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDarkMode;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, 48, 20, 24),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: Text(
                      'U',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Online',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        _settingsItem(
          icon: Icons.person_outline,
          iconColor: Color(0xFF2B5CE6),
          title: 'Profile Settings',
          subtitle: 'Edit your personal information',
          onTap: () {},
        ),
        _divider(),
        _settingsItem(
          icon: Icons.download_outlined,
          iconColor: Color(0xFF2B5CE6),
          title: 'Storage & Data',
          subtitle: 'Manage media files and downloads',
          onTap: () {},
        ),
        _divider(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Color(0xFF2B5CE6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: Color(0xFF2B5CE6),
                  size: 22,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(
                      isDark ? 'Dark mode' : 'Light mode',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDark,
                activeColor: Color(0xFF2B5CE6),
                onChanged: (_) => themeProvider.toggleTheme(),
              ),
            ],
          ),
        ),
        _divider(),
        _settingsItem(
          icon: Icons.info_outline,
          iconColor: Color(0xFF2B5CE6),
          title: 'About',
          subtitle: 'SecureWave v1.0.0',
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'SecureWave',
              applicationVersion: 'v1.0.0',
              applicationIcon: Icon(Icons.security, color: Color(0xFF2B5CE6), size: 36),
              children: [Text('Secure encrypted messenger.\n© 2024 SecureWave Team')],
            );
          },
        ),
        SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Sign Out'),
                  content: Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        authProvider.logout();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.logout),
            label: Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        SizedBox(height: 32),
      ],
    );
  }

  Widget _settingsItem({required IconData icon, required Color iconColor, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])) : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }

  Widget _divider() => Divider(height: 1, indent: 70, endIndent: 16);

  void _openChat(dynamic chat) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(chat: chat)));
  }

  void _startNewChat() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => NewChatScreen()));
  }

  void _showSearch() {
    showSearch(context: context, delegate: ChatSearchDelegate());
  }

  void _showChatOptions(dynamic chat) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Icon(Icons.volume_off), title: Text('Mute'), onTap: () => Navigator.pop(context)),
            ListTile(leading: Icon(Icons.push_pin), title: Text('Pin'), onTap: () => Navigator.pop(context)),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _deleteChat(chat); },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteChat(dynamic chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Chat'),
        content: Text('Are you sure you want to delete this chat?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); context.read<ChatProvider>().deleteChat(chat.id); },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class ChatSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(icon: Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(icon: Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final filtered = chatProvider.chats.where((chat) {
      return chat.name.toLowerCase().contains(query.toLowerCase()) ||
          chat.lastMessage?.toLowerCase().contains(query.toLowerCase()) == true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(child: Text('No chats found', style: TextStyle(color: Colors.grey[600])));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final chat = filtered[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(0xFF2B5CE6),
            child: Text(chat.name[0].toUpperCase(), style: TextStyle(color: Colors.white)),
          ),
          title: Text(chat.name),
          subtitle: Text(chat.lastMessage ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            close(context, null);
            Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(chat: chat)));
          },
        );
      },
    );
  }
}
