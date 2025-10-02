// lib/screens/invites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({Key? key}) : super(key: key);

  @override
  _InvitesScreenState createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  final _api = ApiService();

  List<dynamic> _invites = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    setState(() => _isLoading = true);

    try {
      final response = await _api.get('/invites');

      if (response['success'] == true) {
        setState(() {
          _invites = response['invites'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading invites: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvite() async {
    setState(() => _isCreating = true);

    try {
      final response = await _api.post('/invites/create');

      if (response['success'] == true) {
        final inviteUrl = response['url'] ?? '';
        final code = response['code'] ?? '';

        if (inviteUrl.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: inviteUrl));
        }

        if (mounted) {
          _showInviteLinkDialog(code, inviteUrl);
        }

        await _loadInvites();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Ошибка создания инвайта'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _showInviteLinkDialog(String code, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Инвайт создан!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ссылка скопирована в буфер обмена:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF7C3AED), width: 2),
              ),
              child: SelectableText(
                url,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Код: $code',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ссылка скопирована'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Text('Копировать еще раз'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF7C3AED),
            ),
            child: Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvite(String inviteCode) async {
    try {
      final response = await _api.post('/invites/$inviteCode', {'_method': 'DELETE'});

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Инвайт удален'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadInvites();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['error'] ?? 'Ошибка удаления'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmDelete(String inviteCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить инвайт?'),
        content: Text('Код $inviteCode будет удален безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteInvite(inviteCode);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _copyInviteLink(String url, String code) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ссылка скопирована: $code'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(isDarkMode),
          _buildCreateButton(isDarkMode),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED),
                    ),
                  )
                : _buildInvitesList(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Мои инвайты',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7C3AED),
            ),
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInvites,
            tooltip: 'Обновить',
            color: Color(0xFF7C3AED),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      ),
      child: ElevatedButton.icon(
        onPressed: _isCreating ? null : _createInvite,
        icon: _isCreating
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.add),
        label: Text(_isCreating ? 'Создание...' : 'Создать код'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildInvitesList(bool isDarkMode) {
    if (_invites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'У вас пока нет инвайтов',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Создайте инвайт-код, чтобы пригласить друзей',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF7C3AED),
      onRefresh: _loadInvites,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _invites.length,
        itemBuilder: (context, index) {
          final invite = _invites[index];
          return _buildInviteCard(invite, isDarkMode);
        },
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite, bool isDarkMode) {
    final code = invite['code'] ?? '';
    final url = invite['url'] ?? '';
    final isUsed = invite['is_used'] == true || invite['is_used'] == 1;
    final usedBy = invite['used_by_username'];
    final createdAt = invite['created_at'];
    final usedAt = invite['used_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUsed ? Colors.grey.shade300 : Color(0xFF7C3AED),
          width: isUsed ? 1 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUsed ? Colors.grey[300] : Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      color: isUsed ? Colors.grey[700] : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUsed ? Colors.grey[300] : Colors.green[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isUsed ? 'Использован' : 'Активен',
                    style: TextStyle(
                      color: isUsed ? Colors.grey[700] : Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF1A1A1A) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7C3AED),
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.copy, size: 18),
                    onPressed: () => _copyInviteLink(url, code),
                    tooltip: 'Копировать ссылку',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                SizedBox(width: 4),
                Text(
                  'Создан: ${_formatDate(createdAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            if (isUsed && usedBy != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    'Использован: $usedBy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (usedAt != null) ...[
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      _formatDate(usedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ),
              ],
            ],
            if (!isUsed) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyInviteLink(url, code),
                      icon: Icon(Icons.copy, size: 18),
                      label: Text('Копировать'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFF7C3AED),
                        side: BorderSide(color: Color(0xFF7C3AED)),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDelete(code),
                      icon: Icon(Icons.delete, size: 18),
                      label: Text('Удалить'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}