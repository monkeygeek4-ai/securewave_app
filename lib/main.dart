// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'services/webrtc_service.dart';
import 'services/api_service.dart';
import 'models/call.dart';
import 'widgets/incoming_call_overlay.dart';

void main() {
  print('[Main] Запуск приложения');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
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
          // Оборачиваем в CallOverlayWrapper
          home: CallOverlayWrapper(
            child: InitializationWrapper(),
          ),
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

// Виджет для отображения входящих звонков
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

    print('[CallOverlay] initState - подписываемся на callState');

    // Подписываемся ОДИН РАЗ в initState
    _callSubscription = WebRTCService.instance.callState.listen((call) {
      print('[CallOverlay] Получено обновление звонка: ${call?.status}');

      if (!mounted) return;

      if (call != null && call.status == CallStatus.incoming) {
        print(
            '[CallOverlay] 📞 ПОКАЗЫВАЕМ входящий звонок от ${call.callerName}');
        setState(() {
          _incomingCall = call;
        });
      } else if (call == null ||
          call.status == CallStatus.ended ||
          call.status == CallStatus.declined) {
        print('[CallOverlay] Скрываем overlay (статус: ${call?.status})');
        setState(() {
          _incomingCall = null;
        });
      }
    });
  }

  @override
  void dispose() {
    print('[CallOverlay] dispose - отменяем подписку');
    _callSubscription?.cancel();
    // НЕ вызываем WebRTCService.instance.dispose()!
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Overlay входящего звонка поверх всего контента
        if (_incomingCall != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3), // Затемнение фона
              child: IncomingCallOverlay(
                incomingCall: _incomingCall!,
                onDismiss: () {
                  print('[CallOverlay] onDismiss вызван');
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

// Виджет инициализации
class InitializationWrapper extends StatefulWidget {
  @override
  _InitializationWrapperState createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final authProvider = context.read<AuthProvider>();
    final apiService = ApiService.instance;

    print('[Init] Проверяем авторизацию...');

    // Ждем загрузки токена
    final hasToken = await apiService.waitForToken();

    if (hasToken) {
      print('[Init] Инициализация для авторизованного пользователя');

      try {
        // Получаем текущего пользователя
        final user = await apiService.getCurrentUser();

        if (user != null && user.id.isNotEmpty) {
          print('[Init] Пользователь подтвержден: ${user.username}');

          // Инициализируем WebRTC
          print('[Init] Инициализация WebRTC для пользователя: ${user.id}');

          try {
            await WebRTCService.instance.initialize(user.id);
            print('[Init] ✅ WebRTC успешно инициализирован');
          } catch (e) {
            print('[Init] ❌ Ошибка инициализации WebRTC: $e');
          }

          // Инициализируем ChatProvider
          final chatProvider = context.read<ChatProvider>();
          try {
            // Если у ChatProvider есть метод initialize, вызываем его
            // В противном случае, просто пропускаем
            print('[Init] Инициализация ChatProvider');
            // await chatProvider.initialize(); // Раскомментируйте, если метод существует
          } catch (e) {
            print('[Init] ChatProvider initialize не требуется или ошибка: $e');
          }
        }
      } catch (e) {
        print('[Init] Ошибка получения пользователя: $e');
      }
    } else {
      print('[Init] Токен не найден, пользователь не авторизован');
    }

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          return HomeScreen();
        }

        return LoginScreen();
      },
    );
  }
}
