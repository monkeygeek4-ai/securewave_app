import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  _DeleteAccountScreenState createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _isLoading = false;
  bool _confirmed = false;

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.instance.requestAccountDeletion();

      if (mounted) {
        setState(() => _isLoading = false);

        if (response['success'] == true) {
          // Выходим из аккаунта
          await context.read<AuthProvider>().logout();

          if (mounted) {
            // Показываем сообщение
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Аккаунт удалён'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Перекидываем на страницу авторизации
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Ошибка удаления аккаунта'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Удаление аккаунта'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Внимание! Это действие нельзя отменить после истечения 30-дневного срока.',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Что произойдёт при удалении:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
              Icons.timer,
              '30 дней на восстановление',
              'В течение 30 дней вы можете войти в приложение и восстановить аккаунт',
            ),
            _buildInfoItem(
              Icons.delete_forever,
              'Безвозвратное удаление',
              'После 30 дней все ваши данные будут удалены навсегда',
            ),
            _buildInfoItem(
              Icons.chat_bubble_outline,
              'Удаление сообщений',
              'Все ваши чаты и сообщения будут удалены',
            ),
            _buildInfoItem(
              Icons.person_off,
              'Удаление профиля',
              'Ваш профиль и контактная информация будут удалены',
            ),
            const SizedBox(height: 32),
            CheckboxListTile(
              value: _confirmed,
              onChanged: (value) {
                setState(() => _confirmed = value ?? false);
              },
              title: const Text(
                'Я понимаю, что мой аккаунт будет удалён, и подтверждаю это действие',
                style: TextStyle(fontSize: 14),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: Colors.red,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isLoading || !_confirmed) ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _confirmed ? Colors.red[700] : Colors.grey[400],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[500],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Удалить аккаунт',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Отмена',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[700], size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
