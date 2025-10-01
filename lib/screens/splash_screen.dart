// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'home_screen.dart';
import 'auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    // Предотвращаем повторную инициализацию
    if (_isInitializing) return;
    _isInitializing = true;

    print('[Splash] Начало инициализации приложения');

    try {
      // Минимальная задержка для показа splash
      await Future.delayed(Duration(seconds: 1));

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();

      // ВАЖНО: Проверяем авторизацию (включает валидацию токена на сервере)
      await authProvider.checkAuthStatus();

      if (!mounted) return;

      Widget nextScreen;

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        print(
            '[Splash] Пользователь авторизован: ${authProvider.currentUser!.username}');

        // Устанавливаем userId
        chatProvider.setCurrentUserId(authProvider.currentUser!.id);

        // Даем время на установку WebSocket соединения
        await Future.delayed(Duration(milliseconds: 500));

        // Загружаем чаты
        try {
          await chatProvider.loadChats();
          print('[Splash] Чаты загружены');
        } catch (e) {
          print('[Splash] Ошибка загрузки чатов: $e');
        }

        nextScreen = HomeScreen();
      } else {
        print('[Splash] Пользователь не авторизован');
        nextScreen = LoginScreen();
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => nextScreen),
        );
      }
    } catch (e) {
      print('[Splash] Ошибка инициализации: $e');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667EEA),
              Color(0xFF764BA2),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Логотип или иконка приложения
              Icon(
                Icons.security,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                'SecureWave',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 48),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
