import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../home_screen.dart';
import '../auth/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _eulaAccepted = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showEulaDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Условия использования'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Пользовательское соглашение SecureWave',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                '1. Общие положения',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Используя приложение SecureWave, вы соглашаетесь соблюдать настоящие правила. '
                'Мы оставляем за собой право заблокировать или удалить аккаунт пользователя, нарушающего эти правила.',
              ),
              SizedBox(height: 16),
              Text(
                '2. Запрещённый контент',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Запрещается публиковать:\n'
                '• Спам и нежелательную рекламу\n'
                '• Оскорбительные и угрожающие сообщения\n'
                '• Контент сексуального характера\n'
                '• Материалы, разжигающие ненависть\n'
                '• Призывы к насилию\n'
                '• Персональные данные третьих лиц без их согласия',
              ),
              SizedBox(height: 16),
              Text(
                '3. Модерация',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Все жалобы рассматриваются в течение 24 часов. '
                'Нарушители правил могут быть заблокированы без предупреждения.',
              ),
              SizedBox(height: 16),
              Text(
                '4. Ваши права',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Вы можете пожаловаться на любое сообщение или пользователя\n'
                '• Вы можете заблокировать любого пользователя\n'
                '• Вы можете удалить свой аккаунт в любое время',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _eulaAccepted = true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            child: const Text('Принять', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();

    // Вызываем метод register с позиционными параметрами в правильном порядке
    final success = await authProvider.register(
      _usernameController.text.trim(),
      _passwordController.text,
      _emailController.text.trim(),
      _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        final chatProvider = context.read<ChatProvider>();

        if (authProvider.currentUser != null) {
          chatProvider.setCurrentUserId(authProvider.currentUser!.id);
        }

        // УБИРАЕМ дублирование WebSocket подключения
        // Оно уже происходит в auth_provider.dart при register()

        // Даем время на установку WebSocket соединения
        await Future.delayed(const Duration(milliseconds: 500));

        // Загружаем чаты
        try {
          await chatProvider.loadChats();
        } catch (e) {
          // print('[Register] Ошибка загрузки чатов: $e');
        }

        // Используем pushReplacement чтобы нельзя было вернуться назад
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                          '🚀',
                          style: TextStyle(fontSize: 60),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Создать аккаунт',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(height: 30),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Имя пользователя',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Имя пользователя обязательно';
                            }
                            if (value.trim().length < 3) {
                              return 'Минимум 3 символа';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                              return 'Только буквы, цифры и подчеркивание';
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
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email обязателен';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Введите корректный email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Полное имя',
                            prefixIcon: const Icon(Icons.badge),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Полное имя обязательно';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Номер телефона',
                            hintText: '+7 (XXX) XXX-XX-XX',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Номер телефона обязателен';
                            }
                            // Проверка формата телефона
                            final cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
                            if (cleanPhone.length < 10) {
                              return 'Введите корректный номер телефона';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пароль обязателен';
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
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Подтвердите пароль',
                            prefixIcon: const Icon(Icons.lock_outline),
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
                        const SizedBox(height: 20),

                        // EULA Checkbox
                        CheckboxListTile(
                          value: _eulaAccepted,
                          onChanged: (value) {
                            setState(() => _eulaAccepted = value ?? false);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: GestureDetector(
                            onTap: () => _showEulaDialog(),
                            child: RichText(
                              text: const TextSpan(
                                style: TextStyle(color: Colors.black87, fontSize: 13),
                                children: [
                                  TextSpan(text: 'Я принимаю '),
                                  TextSpan(
                                    text: 'Условия использования',
                                    style: TextStyle(
                                      color: Color(0xFF7C3AED),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(text: ' и обязуюсь не публиковать нежелательный или оскорбительный контент'),
                                ],
                              ),
                            ),
                          ),
                          activeColor: const Color(0xFF7C3AED),
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (_isLoading || !_eulaAccepted) ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Создать аккаунт',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Уже есть аккаунт? '),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (_) => LoginScreen()),
                                );
                              },
                              child: const Text(
                                'Войти',
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
