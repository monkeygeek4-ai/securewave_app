// lib/screens/profile/profile_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../invites_screen.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({Key? key}) : super(key: key);

  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  // Controllers
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _avatarUrl;

  final _phoneMask = MaskTextInputFormatter(
    mask: '+7 (###) ###-##-##',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      setState(() {
        _usernameController.text = user.username;
        _fullNameController.text = user.fullName ?? '';
        _phoneController.text = user.phone ?? '';
        _bioController.text = user.bio ?? '';
        _nicknameController.text =
            user.username; // можно добавить отдельное поле nickname
        _avatarUrl = user.avatar;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;

      final file = files[0];
      final reader = html.FileReader();

      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((event) async {
        setState(() => _isLoading = true);

        try {
          // Отправляем на сервер
          final response = await _api.post('/users/upload-avatar', {
            'avatar': reader.result.toString(),
            'filename': file.name,
          });

          if (response['success'] == true) {
            setState(() {
              _avatarUrl = response['avatarUrl'];
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Аватар обновлен'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка загрузки: $e'),
              backgroundColor: Colors.red,
            ),
          );
        } finally {
          setState(() => _isLoading = false);
        }
      });
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final response = await _api.post('/users/update-profile', {
        'username': _usernameController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
        'bio': _bioController.text.trim(),
        'nickname': _nicknameController.text.trim(),
      });

      if (response['success'] == true) {
        // Обновляем данные в провайдере
        final authProvider = context.read<AuthProvider>();
        await authProvider.checkAuthStatus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Профиль обновлен'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Ошибка сохранения'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки профиля'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProfile,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 30),
              _buildPersonalInfoSection(),
              const SizedBox(height: 30),
              _buildContactSection(),
              const SizedBox(height: 30),
              _buildInviteSection(),
              const SizedBox(height: 40),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? NetworkImage(_avatarUrl!)
                    : null,
                child: _avatarUrl == null || _avatarUrl!.isEmpty
                    ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                    : null,
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 20),
                    onPressed: _pickAvatar,
                    tooltip: 'Изменить фото',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Нажмите на камеру для смены фото',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Личная информация'),
        const SizedBox(height: 15),
        TextFormField(
          controller: _fullNameController,
          decoration: InputDecoration(
            labelText: 'Полное имя',
            hintText: 'Иван Иванов',
            prefixIcon: const Icon(Icons.badge),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите полное имя';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: 'Имя пользователя',
            hintText: 'username',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            helperText: 'Используется для входа в систему',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Введите имя пользователя';
            }
            if (value.trim().length < 3) {
              return 'Минимум 3 символа';
            }
            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
              return 'Только буквы, цифры и _';
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _nicknameController,
          decoration: InputDecoration(
            labelText: 'Никнейм (как в Telegram)',
            hintText: '@nickname',
            prefixIcon: const Icon(Icons.alternate_email),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            helperText: 'Используется в ссылках: securewave.com/@nickname',
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                return 'Только буквы, цифры и _';
              }
              if (value.length < 3) {
                return 'Минимум 3 символа';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 15),
        TextFormField(
          controller: _bioController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: 'О себе',
            hintText: 'Расскажите немного о себе...',
            prefixIcon: const Icon(Icons.info_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Контактные данные'),
        const SizedBox(height: 15),
        TextFormField(
          controller: _phoneController,
          inputFormatters: [_phoneMask],
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Номер телефона',
            hintText: '+7 (XXX) XXX-XX-XX',
            prefixIcon: const Icon(Icons.phone),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            suffixIcon:
                context.watch<AuthProvider>().currentUser?.phoneVerified == true
                    ? const Icon(Icons.verified, color: Colors.green)
                    : null,
          ),
        ),
      ],
    );
  }

  Widget _buildInviteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Инвайты'),
        const SizedBox(height: 15),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
                        color: Color(0xFF7C3AED),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Пригласите друзей',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Создавайте инвайт-коды и приглашайте друзей в SecureWave',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InvitesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Управление инвайтами'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7C3AED),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Сохранить изменения',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
      ),
    );
  }
}
