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
        _nicknameController.text = user.nickname ?? '';
        _avatarUrl = user.avatar;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;

    final file = files[0];
    final reader = html.FileReader();

    setState(() => _isLoading = true);

    reader.readAsDataUrl(file);
    await reader.onLoad.first;

    try {
      final response = await _api.post('/users/upload-avatar', {
        'avatar': reader.result.toString(),
        'filename': file.name,
      });

      if (response['success'] == true) {
        setState(() {
          _avatarUrl = response['avatarUrl'];
        });

        await context.read<AuthProvider>().checkAuthStatus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Аватар обновлен'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки аватара: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? phone = _phoneController.text.isNotEmpty
          ? _phoneMask.getUnmaskedText()
          : null;

      final response = await _api.post('/users/update-profile', {
        'username': _usernameController.text.trim(),
        'fullName': _fullNameController.text.trim().isNotEmpty
            ? _fullNameController.text.trim()
            : null,
        'phone': phone,
        'bio': _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        'nickname': _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : null,
      });

      if (response['success'] == true) {
        await context.read<AuthProvider>().checkAuthStatus();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
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
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (isTablet) {
      return _buildContent(showAppBar: false);
    }

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
      body: _buildContent(showAppBar: true),
    );
  }

  Widget _buildContent({required bool showAppBar}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                      'Настройки профиля',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.save, color: Colors.white),
                    onPressed: _isSaving ? null : _saveProfile,
                    tooltip: 'Сохранить',
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
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
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF7C3AED),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt,
                        size: 20, color: Colors.white),
                    onPressed: _isLoading ? null : _pickAndUploadAvatar,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Нажмите на камеру для смены фото',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Личная информация'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _fullNameController,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Полное имя',
                labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54),
                prefixIcon: const Icon(Icons.badge, color: Color(0xFF7C3AED)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDarkMode ? Color(0xFF3D3D3D) : Colors.grey[50],
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty && value.length < 2) {
                  return 'Минимум 2 символа';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Имя пользователя',
                labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54),
                helperText: 'Используется для входа в систему',
                helperStyle: TextStyle(
                    color: isDarkMode ? Colors.white60 : Colors.black45),
                prefixIcon: const Icon(Icons.person, color: Color(0xFF7C3AED)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDarkMode ? Color(0xFF3D3D3D) : Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Обязательное поле';
                }
                if (value.trim().length < 3) {
                  return 'Минимум 3 символа';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nicknameController,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Никнейм (как в Telegram)',
                labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54),
                helperText: 'Используется в ссылках: securewave.com/@nickname',
                helperStyle: TextStyle(
                    color: isDarkMode ? Colors.white60 : Colors.black45),
                prefixIcon:
                    const Icon(Icons.alternate_email, color: Color(0xFF7C3AED)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDarkMode ? Color(0xFF3D3D3D) : Colors.grey[50],
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Только латиница, цифры и _';
                  }
                  if (value.length < 3) {
                    return 'Минимум 3 символа';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 200,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'О себе',
                labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54),
                hintText: 'Расскажите немного о себе...',
                hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white38 : Colors.black38),
                prefixIcon:
                    const Icon(Icons.info_outline, color: Color(0xFF7C3AED)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDarkMode ? Color(0xFF3D3D3D) : Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Контактные данные'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneController,
              inputFormatters: [_phoneMask],
              keyboardType: TextInputType.phone,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: 'Телефон',
                labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54),
                hintText: '+7 (999) 999-99-99',
                hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white38 : Colors.black38),
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF7C3AED)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: isDarkMode ? Color(0xFF3D3D3D) : Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDarkMode ? Color(0xFF2D2D2D) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Инвайты'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => InvitesScreen()),
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
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
            color: isDarkMode ? Colors.white : Color(0xFF7C3AED),
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
