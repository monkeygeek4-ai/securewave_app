// lib/screens/invites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:intl/intl.dart';

class InvitesScreen extends StatefulWidget {
  const InvitesScreen({Key? key}) : super(key: key);

  @override
  _InvitesScreenState createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  final _api = ApiService();
  final _phoneController = TextEditingController();

  List<dynamic> _invites = [];
  bool _isLoading = true;
  bool _isSending = false;

  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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

  Future<void> _createInvite({String? phone}) async {
    setState(() => _isSending = true);

    try {
      final response = await _api.post(
          '/invites/create',
          phone != null
              ? {'phone': phone.replaceAll(RegExp(r'[^\d]'), '')}
              : <String, dynamic>{});

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              phone != null
                  ? 'Инвайт отправлен на номер $phone'
                  : 'Инвайт-код создан: ${response['code']}',
            ),
            backgroundColor: Colors.green,
            action: phone == null
                ? SnackBarAction(
                    label: 'Копировать',
                    textColor: Colors.white,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: response['code']));
                    },
                  )
                : null,
          ),
        );

        _phoneController.clear();
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
      setState(() => _isSending = false);
    }
  }

  Future<void> _deleteInvite(String inviteCode) async {
    try {
      // ИСПРАВЛЕНО: Используем POST вместо delete
      final response =
          await _api.post('/invites/$inviteCode', {'_method': 'DELETE'});

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
        title: Text('Удалить инвайт?'),
        content: Text('Код $inviteCode будет удален безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteInvite(inviteCode);
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSendInviteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отправить инвайт'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _phoneController,
              inputFormatters: [_phoneMask],
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Номер телефона',
                hintText: '+7 (XXX) XXX-XX-XX',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = _phoneController.text;
              if (phone.isNotEmpty) {
                Navigator.pop(context);
                _createInvite(phone: phone);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Отправить'),
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
        return 'Истекает: ${difference.inDays} д. назад';
      } else if (difference.inHours > 0) {
        return 'Истекает: ${difference.inHours} ч.';
      } else if (difference.inMinutes > 0) {
        return 'Истекает: ${difference.inMinutes} мин.';
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isTablet) {
      return _buildContent(showAppBar: false, isDarkMode: isDarkMode);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои инвайты'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: _buildContent(showAppBar: true, isDarkMode: isDarkMode),
    );
  }

  Widget _buildContent({required bool showAppBar, required bool isDarkMode}) {
    return Container(
      color: isDarkMode ? Color(0xFF1E1E1E) : Colors.grey[50],
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
                      'Мои инвайты',
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
          _buildActionButtons(isDarkMode),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                    color: Color(0xFF7C3AED),
                  ))
                : _buildInvitesList(isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : () => _createInvite(),
              icon: const Icon(Icons.add),
              label: const Text('Создать код'),
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
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _showSendInviteDialog,
              icon: const Icon(Icons.send),
              label: const Text('Отправить SMS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
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
      color: Color(0xFF7C3AED),
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
    final isUsed = invite['is_used'] == true || invite['is_used'] == 1;
    final phone = invite['phone'];
    final usedBy = invite['used_by_username'];
    final createdAt = invite['created_at'];
    final expiresAt = invite['expires_at'];
    final isExpired = _isExpired(expiresAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                              ? Colors.grey[300]
                              : const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            color: isUsed || isExpired
                                ? Colors.grey[700]
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
                          color: Color(0xFF7C3AED),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Код скопирован'),
                                duration: Duration(seconds: 1),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          tooltip: 'Копировать код',
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
                    PopupMenuButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 10),
                              Text('Удалить'),
                            ],
                          ),
                          onTap: () {
                            Future.delayed(Duration.zero, () {
                              _confirmDelete(code);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1),
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
                    color: isExpired ? Colors.red : Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getTimeRemaining(expiresAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: isExpired ? Colors.red : Color(0xFF7C3AED),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // ИСПРАВЛЕНО: Заменили Icons.person_check на Icons.check_circle
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
      ),
    );
  }
}
