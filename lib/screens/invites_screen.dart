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
      final response =
          await _api.post('/invites/create', data: <String, dynamic>{});

      if (response['success'] == true) {
        final inviteCode = response['code'];
        final inviteUrl = 'https://securewave.sbk-19.ru/invite/$inviteCode';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Инвайт создан: $inviteUrl'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Копировать',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: inviteUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URL скопирован в буфер обмена'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFF7C3AED),
                  ),
                );
              },
            ),
          ),
        );

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

  Future<void> _deleteInvite(String inviteCode) async {
    try {
      final response =
          await _api.post('/invites/$inviteCode', data: {'_method': 'DELETE'});

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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteInvite(inviteCode);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  bool _isExpired(String? expiresAt) {
    if (expiresAt == null) return false;
    try {
      final expiryDate = DateTime.parse(expiresAt);
      return expiryDate.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
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

  String _getTimeRemaining(String? expiresAt) {
    if (expiresAt == null) return '';
    try {
      final expiryDate = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final difference = expiryDate.difference(now);

      if (difference.isNegative) return 'Истек';

      if (difference.inDays > 0) {
        return 'Осталось: ${difference.inDays} д.';
      } else if (difference.inHours > 0) {
        return 'Осталось: ${difference.inHours} ч.';
      } else if (difference.inMinutes > 0) {
        return 'Осталось: ${difference.inMinutes} мин.';
      } else {
        return 'Истекает: скоро';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (isTablet) {
      return _buildContent(showAppBar: false);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои инвайты'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInvites,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildContent(showAppBar: true),
    );
  }

  Widget _buildContent({required bool showAppBar}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
      child: Column(
        children: [
          if (!showAppBar)
            Container(
              color: const Color(0xFF7C3AED),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 16,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Инвайты',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadInvites,
                    tooltip: 'Обновить',
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF7C3AED),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCreateInviteSection(isDarkMode),
                            const SizedBox(height: 30),
                            _buildInvitesListSection(isDarkMode),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateInviteSection(bool isDarkMode) {
    return Card(
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Создать инвайт', isDarkMode),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreating ? null : _createInvite,
                icon: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.link),
                label:
                    Text(_isCreating ? 'Создание...' : 'Создать инвайт-ссылку'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Создайте инвайт-ссылку для приглашения новых пользователей в SecureWave',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitesListSection(bool isDarkMode) {
    return Card(
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              'Мои инвайты (${_invites.length})',
              isDarkMode,
            ),
            const SizedBox(height: 20),
            if (_invites.isEmpty)
              _buildEmptyState(isDarkMode)
            else
              ..._invites.map((invite) => _buildInviteCard(invite, isDarkMode)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.card_giftcard,
              size: 64,
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'У вас пока нет инвайтов',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Создайте инвайт-код для приглашения друзей',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite, bool isDarkMode) {
    final code = invite['code'] ?? '';
    final isUsed = invite['is_used'] == true || invite['is_used'] == 1;
    final phone = invite['phone'];
    final usedBy = invite['used_by_username'];
    final createdAt = invite['created_at'];
    final expiresAt = invite['expires_at'];
    final isExpired = _isExpired(expiresAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isUsed || isExpired
                            ? (isDarkMode ? Colors.grey[700] : Colors.grey[300])
                            : const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          color: isUsed || isExpired
                              ? (isDarkMode ? Colors.white60 : Colors.grey[700])
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    if (!isUsed && !isExpired) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        color: const Color(0xFF7C3AED),
                        onPressed: () {
                          final inviteUrl =
                              'https://securewave.sbk-19.ru/invite/$code';
                          Clipboard.setData(ClipboardData(text: inviteUrl));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ссылка скопирована'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        tooltip: 'Копировать ссылку',
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.red[100]
                          : isUsed
                              ? Colors.green[100]
                              : Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isExpired
                          ? 'Истек'
                          : isUsed
                              ? 'Использован'
                              : 'Активен',
                      style: TextStyle(
                        color: isExpired
                            ? Colors.red[700]
                            : isUsed
                                ? Colors.green[700]
                                : Colors.orange[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      size: 20,
                      color: Colors.red[400],
                    ),
                    onPressed: () => _confirmDelete(code),
                    tooltip: 'Удалить',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
          const SizedBox(height: 12),
          if (phone != null) ...[
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 16,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Создан: ${_formatDate(createdAt)}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ],
          ),
          if (!isUsed && expiresAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isExpired ? Icons.cancel : Icons.schedule,
                  size: 16,
                  color: isExpired ? Colors.red : const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Text(
                  _getTimeRemaining(expiresAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: isExpired ? Colors.red : const Color(0xFF7C3AED),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          if (isUsed && usedBy != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.green[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Использован: @$usedBy',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
