import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/websocket_manager.dart';
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
    // Инициализация происходит после построения виджета
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
      final wsManager = WebSocketManager.instance;

      // Проверяем авторизацию (НЕ подключает WebSocket)
      await authProvider.checkAuthStatus();

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        print('[Splash] Пользователь авторизован');

        // Устанавливаем userId
        if (authProvider.currentUser != null) {
          chatProvider.setCurrentUserId(authProvider.currentUser!.id);
        }

        // Подключаем WebSocket ОДИН РАЗ
        if (!wsManager.isConnected && authProvider.currentToken != null) {
          print('[Splash] Подключаем WebSocket...');

          try {
            await wsManager.connect(token: authProvider.currentToken);
            // Ждем установки соединения
            await Future.delayed(Duration(milliseconds: 500));
          } catch (e) {
            print('[Splash] Ошибка подключения WebSocket: $e');
          }
        } else {
          print('[Splash] WebSocket уже подключен или нет токена');
        }

        // Загружаем чаты ОДИН раз после подключения WebSocket
        if (chatProvider.chats.isEmpty) {
          print('[Splash] Загружаем чаты...');
          try {
            await chatProvider.loadChats();
          } catch (e) {
            print('[Splash] Ошибка загрузки чатов: $e');
          }
        } else {
          print('[Splash] Чаты уже загружены');
        }

        // Переходим на главный экран без пересоздания
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen()),
          );
        }
      } else {
        print('[Splash] Пользователь не авторизован');

        // Переходим на экран входа без пересоздания
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => LoginScreen()),
          );
        }
      }
    } catch (e) {
      print('[Splash] Критическая ошибка инициализации: $e');

      // При любой критической ошибке переходим на экран входа
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
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Анимированный логотип
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(seconds: 1),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '🚀',
                          style: TextStyle(fontSize: 50),
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 30),
              Text(
                'SecureWave',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Безопасные сообщения',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 50),
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Загрузка...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
