// lib/screens/invites_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

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
      final data = phone != null
          ? {'phone': phone.replaceAll(RegExp(r'[^\d]'), '')}
          : {};

      final response = await _api.post('/invites/create', data);

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
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои инвайты'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildActionButtons(),
                Expanded(child: _buildInvitesList()),
              ],
            ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitesList() {
    if (_invites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'У вас пока нет инвайтов',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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
      onRefresh: _loadInvites,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _invites.length,
        itemBuilder: (context, index) {
          final invite = _invites[index];
          return _buildInviteCard(invite);
        },
      ),
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    final code = invite['code'] ?? '';
    final isUsed = invite['is_used'] == true || invite['is_used'] == 1;
    final phone = invite['phone'];
    final usedBy = invite['used_by_username'];
    final createdAt = invite['created_at'];
    final expiresAt = invite['expires_at'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
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
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isUsed
                              ? Colors.grey[300]
                              : const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          code,
                          style: TextStyle(
                            color: isUsed ? Colors.grey[700] : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (!isUsed)
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Код скопирован'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          tooltip: 'Копировать код',
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isUsed ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isUsed ? 'Использован' : 'Активен',
                    style: TextStyle(
                      color: isUsed ? Colors.green[700] : Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (phone != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 5),
                  Text(
                    phone,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (usedBy != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 5),
                  Text(
                    'Использован: $usedBy',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (createdAt != null)
                  Text(
                    'Создан: ${_formatDate(createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                if (expiresAt != null && !isUsed)
                  Text(
                    'Истекает: ${_formatDate(expiresAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Сегодня ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Вчера';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} дн. назад';
      } else {
        return '${date.day}.${date.month}.${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }
}
