import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/chat_provider.dart';

class ReportDialog extends StatefulWidget {
  final int reportedUserId;
  final String reportedUsername;
  final int? messageId;
  final int? chatId;
  final String? messageContent;
  final String? messageIdString; // ID сообщения для скрытия после жалобы

  const ReportDialog({
    super.key,
    required this.reportedUserId,
    required this.reportedUsername,
    this.messageId,
    this.chatId,
    this.messageContent,
    this.messageIdString,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int reportedUserId,
    required String reportedUsername,
    int? messageId,
    int? chatId,
    String? messageContent,
    String? messageIdString,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportDialog(
        reportedUserId: reportedUserId,
        reportedUsername: reportedUsername,
        messageId: messageId,
        chatId: chatId,
        messageContent: messageContent,
        messageIdString: messageIdString,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedType;
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  final _reportTypes = [
    {'value': 'spam', 'label': 'Спам', 'icon': Icons.mail_outline},
    {'value': 'harassment', 'label': 'Оскорбления', 'icon': Icons.mood_bad},
    {'value': 'inappropriate', 'label': 'Непристойный контент', 'icon': Icons.no_adult_content},
    {'value': 'violence', 'label': 'Насилие', 'icon': Icons.warning_amber},
    {'value': 'hate_speech', 'label': 'Разжигание ненависти', 'icon': Icons.gavel},
    {'value': 'other', 'label': 'Другое', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите причину жалобы')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.instance.reportContent(
        reportedUserId: widget.reportedUserId,
        messageId: widget.messageId,
        chatId: widget.chatId,
        reportType: _selectedType!,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (response['success'] == true) {
          // Скрываем сообщение из чата, если жалоба на конкретное сообщение
          if (widget.messageIdString != null) {
            context.read<ChatProvider>().removeMessage(widget.messageIdString!);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Жалоба отправлена. Мы рассмотрим её в течение 24 часов.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Ошибка отправки жалобы'),
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Пожаловаться на ${widget.reportedUsername}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Выберите причину жалобы',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),

            // Message preview if available
            if (widget.messageContent != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.messageContent!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Report types
            ...(_reportTypes.map((type) => _buildReportTypeOption(
              value: type['value'] as String,
              label: type['label'] as String,
              icon: type['icon'] as IconData,
            ))),

            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Дополнительные детали (необязательно)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Отправить жалобу',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedType == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.red : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.red[900] : Colors.grey[800],
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.red[600]),
          ],
        ),
      ),
    );
  }
}
