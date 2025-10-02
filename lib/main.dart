// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:html' as html;
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

void main() {
  print('[Main] Запуск приложения');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
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

    _callSubscription = WebRTCService.instance.callState.listen((call) {
      print('[CallOverlay] Получено обновление звонка: ${call?.status}');

      if (!mounted) return;

      if (call != null && call.status == CallStatus.incoming) {
        print('[CallOverlay] Показываем входящий звонок от ${call.callerName}');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_incomingCall != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
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

// Инициализация приложения с проверкой инвайт-ссылок
class InitializationWrapper extends StatefulWidget {
  @override
  _InitializationWrapperState createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  bool _isInitialized = false;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    _checkInviteLink();
    _initialize();
  }

  void _checkInviteLink() {
    try {
      // Проверяем URL на наличие /invite/CODE
      final currentUrl = html.window.location.href;
      print('[Init] Текущий URL: $currentUrl');

      final uri = Uri.parse(currentUrl);
      print('[Init] Путь: ${uri.path}');
      print('[Init] Сегменты пути: ${uri.pathSegments}');

      if (uri.pathSegments.isNotEmpty && uri.pathSegments.length >= 2) {
        if (uri.pathSegments[0] == 'invite') {
          _inviteCode = uri.pathSegments[1];
          print('[Init] ✅ Обнаружен инвайт-код: $_inviteCode');
        }
      }
    } catch (e) {
      print('[Init] Ошибка при проверке URL: $e');
    }
  }

  Future<void> _initialize() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthStatus();

    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      print(
          '[Init] Пользователь авторизован: ${authProvider.currentUser!.username}');

      // Инициализируем WebRTC
      try {
        await WebRTCService.instance.initialize(authProvider.currentUser!.id);
        print('[Init] WebRTC успешно инициализирован');
      } catch (e) {
        print('[Init] Ошибка инициализации WebRTC: $e');
      }

      final chatProvider = context.read<ChatProvider>();
      chatProvider.setCurrentUserId(authProvider.currentUser!.id);

      try {
        await chatProvider.loadChats();
      } catch (e) {
        print('[Init] Ошибка загрузки чатов: $e');
      }
    } else {
      print('[Init] Пользователь не авторизован');
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

    // Если есть инвайт-код, показываем страницу регистрации
    if (_inviteCode != null) {
      return InviteRegisterScreen(inviteCode: _inviteCode);
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

        if (authProvider.isAuthenticated && authProvider.currentUser != null) {
          return HomeScreen();
        }

        return LoginScreen();
      },
    );
  }
}
