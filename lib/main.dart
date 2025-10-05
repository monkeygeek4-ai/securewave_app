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

// ИСПРАВЛЕНО: Условный импорт для веб-версии
String? _checkInviteLink() {
  if (kIsWeb) {
    try {
      // Для веб используем dart:html
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
      print('[Init] Ошибка при проверке URL: $e');
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
          home: CallOverlayWrapper(
            child: _buildHome(authProvider, context),
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

  Widget _buildHome(AuthProvider authProvider, BuildContext context) {
    // Проверяем инвайт-код (только для веб)
    String? inviteCode = _checkInviteLink();
    if (inviteCode != null) {
      return InviteRegisterScreen(inviteCode: inviteCode);
    }

    // Показываем загрузку пока проверяется авторизация
    if (authProvider.isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF7C3AED),
          ),
        ),
      );
    }

    // Если пользователь авторизован
    if (authProvider.isAuthenticated && authProvider.currentUser != null) {
      print('[Init] ========================================');
      print(
          '[Init] Пользователь авторизован: ${authProvider.currentUser?.username}');
      print('[Init] User ID: ${authProvider.currentUser?.id}');
      print('[Init] ========================================');

      // КРИТИЧЕСКИ ВАЖНО: Инициализация WebRTC для входящих звонков
      WebRTCService.instance.initialize(authProvider.currentUser!.id).then((_) {
        print('[Init] ✅ WebRTC успешно инициализирован');
      }).catchError((e) {
        print('[Init] ❌ Ошибка инициализации WebRTC: $e');
      });

      // Загружаем чаты
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chatProvider = context.read<ChatProvider>();
        print(
            '[Init] 📨 Загружаем чаты для пользователя ${authProvider.currentUser!.id}');
        chatProvider.loadChats();
      });

      return HomeScreen();
    }

    // Показываем экран входа
    print('[Init] ℹ️ Пользователь не авторизован, показываем экран входа');
    return LoginScreen();
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
        print('[CallOverlay] Call ID: ${call?.id}');
        print('[CallOverlay] Status: ${call?.status}');
        print('[CallOverlay] Caller: ${call?.callerName}');
        print('[CallOverlay] Type: ${call?.callType}');
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
        if (_incomingCall != null)
          Positioned.fill(
            child: Container(
              color: Colors.black
                  .withOpacity(0.8), // УВЕЛИЧЕНО для лучшей видимости
              child: IncomingCallOverlay(
                incomingCall: _incomingCall!,
                onDismiss: () {
                  print(
                      '[CallOverlay] ========================================');
                  print('[CallOverlay] onDismiss вызван');
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
