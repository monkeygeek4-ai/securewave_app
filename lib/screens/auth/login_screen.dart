// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/websocket_manager.dart';
import '../../services/webrtc_service.dart';
import '../../helpers/ios_callkit_handler.dart';
import '../../services/api_service.dart';
import '../home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'dart:io' show Platform;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();

      // print('[Login] 🔐 Начинаем вход: ${_usernameController.text.trim()}');

      final success = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        // print('[Login] ✅ Успешный вход');

        final chatProvider = context.read<ChatProvider>();

        if (authProvider.currentUser != null) {
          // print('[Login] 👤 User ID: ${authProvider.currentUser!.id}');
          // print(             // '[Login] 🔑 Token: ${authProvider.currentToken?.substring(0, 20)}...');

          chatProvider.setCurrentUserId(authProvider.currentUser!.id);

          // КРИТИЧЕСКИ ВАЖНО: Подключаемся к WebSocket
          // print('[Login] 🔌 Подключаемся к WebSocket...');
          try {
            await WebSocketManager.instance.connect(
              token: authProvider.currentToken,
              userId: authProvider.currentUser!.id,
            );
            // print('[Login] ✅ WebSocket подключение инициировано');
          } catch (e) {
            // print('[Login] ⚠️ Ошибка подключения WebSocket: $e');
          }

          // ⭐⭐⭐ КРИТИЧНО: Инициализируем WebRTC после входа
          // print('[Login] 📞 Инициализируем WebRTC...');
          try {
            await WebRTCService.instance.initialize(
              authProvider.currentUser!.id.toString(),
            );
            // print('[Login] ✅ WebRTC инициализирован');
          } catch (e) {
            // print('[Login] ⚠️ Ошибка инициализации WebRTC: $e');
          }

          // ⭐⭐⭐ КРИТИЧНО: Инициализируем iOS CallKit Handler после входа
          if (!kIsWeb && Platform.isIOS) {
            // print('[Login] ========================================');
            // print('[Login] 📱 Инициализация iOS CallKit Handler');
            // print('[Login] ========================================');
            try {
              IOSCallKitHandler().initialize();
              // print('[Login] ✅ IOSCallKitHandler инициализирован');
            } catch (e) {
              // print('[Login] ⚠️ Ошибка инициализации IOSCallKitHandler: $e');
            }
          }
        }

        // Задержка для стабильности WebSocket подключения
        await Future.delayed(const Duration(milliseconds: 1000));

        try {
          // print('[Login] 💬 Загружаем чаты...');
          await chatProvider.loadChats();
          // print('[Login] ✅ Чаты загружены успешно');
        } catch (e) {
          // print('[Login] ⚠️ Ошибка загрузки чатов: $e');
        }

        // Проверяем статус удаления аккаунта
        try {
          final deletionStatus = await ApiService.instance.checkDeletionStatus();
          if (deletionStatus['success'] == true && deletionStatus['is_deleted'] == true) {
            if (mounted) {
              final shouldRestore = await _showRestoreAccountDialog(
                deletionStatus['days_remaining'] ?? 0,
              );
              if (shouldRestore == true) {
                await ApiService.instance.restoreAccount();
              }
            }
          }
        } catch (e) {
          // Игнорируем ошибку проверки статуса
        }

        setState(() => _isLoading = false);

        // Переходим на главный экран
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        }
      } else {
        // print('[Login] ❌ Ошибка входа: ${authProvider.errorMessage}');

        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage ??
                  'Неверное имя пользователя или пароль'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // print('[Login] ❌ Критическая ошибка: $e');

      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка соединения с сервером'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<bool?> _showRestoreAccountDialog(int daysRemaining) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Аккаунт помечен для удаления'),
        content: Text(
          'Ваш аккаунт запланирован к удалению.\n\n'
          'Осталось дней до удаления: $daysRemaining\n\n'
          'Хотите восстановить аккаунт?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Нет, удалить'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text(
              'Восстановить',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
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
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '🔐',
                          style: TextStyle(fontSize: 60),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'SecureWave',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Добро пожаловать',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 30),
                        TextFormField(
                          controller: _usernameController,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Имя пользователя',
                            hintText: 'Введите ваше имя',
                            prefixIcon: const Icon(Icons.person,
                                color: Color(0xFF7C3AED)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Пожалуйста, введите имя пользователя';
                            }
                            if (value.trim().length < 3) {
                              return 'Минимум 3 символа';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            hintText: 'Введите ваш пароль',
                            prefixIcon: const Icon(Icons.lock,
                                color: Color(0xFF7C3AED)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
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
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите пароль';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              disabledBackgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 3,
                            ),
                            child: _isLoading
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Вход...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Войти',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            'Забыли пароль?',
                            style: TextStyle(
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Нет аккаунта? '),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => const RegisterScreen()),
                                );
                              },
                              child: const Text(
                                'Зарегистрироваться',
                                style: TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
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
}
