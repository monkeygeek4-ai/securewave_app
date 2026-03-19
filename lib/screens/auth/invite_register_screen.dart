// lib/screens/auth/invite_register_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/api_service.dart';
import '../home_screen.dart';

class InviteRegisterScreen extends StatefulWidget {
  final String? inviteCode;

  const InviteRegisterScreen({super.key, this.inviteCode});

  @override
  _InviteRegisterScreenState createState() => _InviteRegisterScreenState();
}

class _InviteRegisterScreenState extends State<InviteRegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.inviteCode == null || widget.inviteCode!.isEmpty) {
      setState(() {
        _errorMessage = 'Неверный код приглашения';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _api.post('/auth/register-by-invite', data: {
        'inviteCode': widget.inviteCode,
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'fullName': _fullNameController.text.trim(),
      });

      if (response['success'] == true && response['user'] != null) {
        final authProvider = context.read<AuthProvider>();

        // Сохраняем токен
        if (response['token'] != null) {
          await _api.saveToken(response['token']);
        }

        // Обновляем состояние авторизации
        authProvider.setAuthenticated(
          response['user'],
          response['token'],
        );

        // Обновляем ChatProvider
        final chatProvider = context.read<ChatProvider>();
        chatProvider.setCurrentUserId(response['user']['id']?.toString() ?? '');

        await Future.delayed(const Duration(milliseconds: 500));

        try {
          await chatProvider.loadChats();
        } catch (e) {
          // print('[InviteRegister] Ошибка загрузки чатов: $e');
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = response['error'] ?? 'Ошибка регистрации';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 30),
                        if (_errorMessage != null) _buildErrorMessage(),
                        _buildForm(),
                        const SizedBox(height: 20),
                        _buildBackButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text('👤', style: TextStyle(fontSize: 60)),
        const SizedBox(height: 10),
        const Text(
          'Регистрация',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.inviteCode != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                const SizedBox(width: 8),
                Text(
                  'Код: ${widget.inviteCode}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Имя пользователя',
              hintText: 'username',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'example@mail.com',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Неверный формат email';
              }
              return null;
            },
          ),
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
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите пароль';
              }
              if (value.length < 6) {
                return 'Минимум 6 символов';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Подтвердите пароль',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Подтвердите пароль';
              }
              if (value != _passwordController.text) {
                return 'Пароли не совпадают';
              }
              return null;
            },
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Создать аккаунт',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return TextButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
      },
      icon: const Icon(Icons.arrow_back),
      label: const Text('Назад'),
    );
  }
}
