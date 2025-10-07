// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/invite_register_screen.dart';
import 'screens/home_screen.dart';
import 'services/webrtc_service.dart';
import 'models/call.dart';
import 'widgets/incoming_call_overlay.dart';

// Проверка инвайт-кода в URL (только для веб)
String? _checkInviteLink() {
  if (kIsWeb) {
    try {
      final html = Uri.base;
      print('[Init] Текущий URL: ${html.toString()}');
      print('[Init] Путь: ${html.path}');
      print('[Init] Сегменты пути: ${html.pathSegments}');

      if (html.pathSegments.isNotEmpty && html.pathSegments.length >= 2) {
        if (html.pathSegments[0] == 'invite') {
          final inviteCode = html.pathSegments[1];
          print('[Init] ✅ Обнаружен инвайт-код: $inviteCode');
          return inviteCode;
        }
      }
    } catch (e) {
      print('[Init] ⚠️ Ошибка при проверке URL: $e');
    }
  }
  return null;
}

void main() {
  print('[Main] ========================================');
  print('[Main] Запуск приложения SecureWave');
  print('[Main] Платформа: ${kIsWeb ? "Web" : "Mobile"}');
  print('[Main] ========================================');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, previous) {
            final chatProvider = previous ?? ChatProvider();
            if (auth.isAuthenticated && auth.currentUser != null) {
              chatProvider.setCurrentUserId(auth.currentUser!.id.toString());
            }
            return chatProvider;
          },
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, authProvider, _) {
        return MaterialApp(
          title: 'SecureWave',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: Color(0xFF2B5CE6),
            useMaterial3: true,
          ),
          themeMode: themeProvider.themeMode,
          // КРИТИЧНО: Всегда используем home, игнорируя URL
          home: CallOverlayWrapper(
            child: InitializationWrapper(),
          ),
          // Маршруты для программной навигации
          routes: {
            '/login': (context) => LoginScreen(),
            '/register': (context) => RegisterScreen(),
            '/home': (context) => HomeScreen(),
          },
        );
      },
    );
  }
}

// Виджет инициализации приложения
class InitializationWrapper extends StatefulWidget {
  @override
  _InitializationWrapperState createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  bool _isInitializing = true;
  bool _isAuthenticated = false;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    print('[Init] ========================================');
    print('[Init] Начало инициализации приложения');
    print('[Init] ========================================');

    try {
      // Проверяем инвайт-код (только для /invite/XXX)
      _inviteCode = _checkInviteLink();

      if (_inviteCode != null) {
        print('[Init] 🎫 Обнаружен инвайт-код, показываем регистрацию');
        setState(() {
          _isInitializing = false;
          _isAuthenticated = false;
        });
        return;
      }

      // КРИТИЧНО: Проверяем авторизацию ВСЕГДА, игнорируя URL
      final authProvider = context.read<AuthProvider>();

      print('[Init] 🔍 Проверка авторизации...');
      await authProvider.checkAuth();

      if (!mounted) return;

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        print('[Init] ========================================');
        print('[Init] ✅ Пользователь авторизован');
        print('[Init] 👤 Username: ${authProvider.currentUser!.username}');
        print('[Init] 🆔 User ID: ${authProvider.currentUser!.id}');
        print('[Init] ========================================');

        // Инициализируем WebRTC
        print('[Init] 🔌 Инициализация WebRTC...');
        try {
          await WebRTCService.instance.initialize(
            authProvider.currentUser!.id.toString(),
          );
          print('[Init] ✅ WebRTC успешно инициализирован');
        } catch (e) {
          print('[Init] ⚠️ Ошибка инициализации WebRTC: $e');
        }

        // Загружаем чаты
        final chatProvider = context.read<ChatProvider>();
        print('[Init] 📨 Загружаем чаты...');
        chatProvider.setCurrentUserId(authProvider.currentUser!.id.toString());

        try {
          await chatProvider.loadChats();
          print('[Init] ✅ Чаты загружены (${chatProvider.chats.length} шт.)');
        } catch (e) {
          print('[Init] ⚠️ Ошибка загрузки чатов: $e');
        }

        setState(() {
          _isAuthenticated = true;
          _isInitializing = false;
        });
      } else {
        print('[Init] ========================================');
        print('[Init] ℹ️ Пользователь не авторизован');
        print('[Init] ========================================');

        setState(() {
          _isAuthenticated = false;
          _isInitializing = false;
        });
      }
    } catch (e, stackTrace) {
      print('[Init] ========================================');
      print('[Init] ❌ КРИТИЧЕСКАЯ ОШИБКА инициализации');
      print('[Init] Ошибка: $e');
      print('[Init] Stack trace: $stackTrace');
      print('[Init] ========================================');

      setState(() {
        _isAuthenticated = false;
        _isInitializing = false;
      });
    }

    print('[Init] ========================================');
    print('[Init] Инициализация завершена');
    print('[Init] Статус авторизации: $_isAuthenticated');
    print('[Init] ========================================');
  }

  @override
  Widget build(BuildContext context) {
    // Показываем загрузку
    if (_isInitializing) {
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
                Text(
                  '🔐',
                  style: TextStyle(fontSize: 80),
                ),
                SizedBox(height: 20),
                Text(
                  'SecureWave',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 40),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  'Загрузка...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Если есть инвайт-код
    if (_inviteCode != null) {
      return InviteRegisterScreen(inviteCode: _inviteCode!);
    }

    // КРИТИЧНО: Показываем HomeScreen если авторизован, иначе LoginScreen
    return _isAuthenticated ? HomeScreen() : LoginScreen();
  }
}

// Виджет для отображения входящих звонков поверх всего приложения
class CallOverlayWrapper extends StatefulWidget {
  final Widget child;

  const CallOverlayWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _CallOverlayWrapperState createState() => _CallOverlayWrapperState();
}

class _CallOverlayWrapperState extends State<CallOverlayWrapper> {
  Call? _incomingCall;
  StreamSubscription<Call?>? _callSubscription;

  @override
  void initState() {
    super.initState();

    print('[CallOverlay] ========================================');
    print('[CallOverlay] initState - инициализация overlay');
    print('[CallOverlay] Платформа: ${kIsWeb ? "Web" : "Mobile"}');
    print('[CallOverlay] ========================================');

    // КРИТИЧЕСКИ ВАЖНО: Подписываемся на входящие звонки НЕМЕДЛЕННО
    _subscribeToCallState();
  }

  void _subscribeToCallState() {
    print('[CallOverlay] 📡 Подписка на callState stream...');

    _callSubscription?.cancel();
    _callSubscription = WebRTCService.instance.callState.listen(
      (call) {
        print('[CallOverlay] ========================================');
        print('[CallOverlay] 📨 Получено обновление звонка');
        print('[CallOverlay] Call: ${call != null ? "EXISTS" : "NULL"}');

        if (call != null) {
          print('[CallOverlay]   - ID: ${call.id}');
          print('[CallOverlay]   - Status: ${call.status}');
          print('[CallOverlay]   - Caller: ${call.callerName}');
          print('[CallOverlay]   - Type: ${call.callType}');
        }
        print('[CallOverlay] ========================================');

        if (!mounted) {
          print('[CallOverlay] ⚠️ Widget не смонтирован, игнорируем');
          return;
        }

        if (call != null && call.status == CallStatus.incoming) {
          print(
              '[CallOverlay] ✅ ПОКАЗЫВАЕМ входящий звонок от ${call.callerName}');
          setState(() {
            _incomingCall = call;
          });
        } else if (call == null ||
            call.status == CallStatus.ended ||
            call.status == CallStatus.declined) {
          print('[CallOverlay] 🔴 Скрываем overlay (статус: ${call?.status})');
          setState(() {
            _incomingCall = null;
          });
        }
      },
      onError: (error) {
        print('[CallOverlay] ❌ Ошибка в callState stream: $error');
      },
      cancelOnError: false,
    );

    print('[CallOverlay] ✅ Подписка на callState активирована');
  }

  @override
  void dispose() {
    print('[CallOverlay] ========================================');
    print('[CallOverlay] dispose - отменяем подписку');
    print('[CallOverlay] ========================================');
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Overlay для входящего звонка
        if (_incomingCall != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.8),
              child: IncomingCallOverlay(
                incomingCall: _incomingCall!,
                onDismiss: () {
                  print(
                      '[CallOverlay] ========================================');
                  print('[CallOverlay] onDismiss вызван вручную');
                  print(
                      '[CallOverlay] ========================================');
                  setState(() {
                    _incomingCall = null;
                  });
                },
              ),
            ),
          ),
      ],
    );
  }
}
