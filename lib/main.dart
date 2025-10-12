// lib/main.dart
// ⭐⭐⭐ ИСПРАВЛЕНО: Правильная обработка accept/decline через MethodChannel

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/invite_register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/call_screen.dart';
import 'services/webrtc_service.dart';
import 'services/fcm_service.dart';
import 'models/call.dart';
import 'widgets/incoming_call_overlay.dart';

// GlobalKey для навигации из нативного кода
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// УПРОЩЕННЫЙ Background Handler (вся логика в MyFirebaseMessagingService.kt)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCM BG] ========================================');
  print('[FCM BG] 📩 Background сообщение получено!');
  print('[FCM BG] Message ID: ${message.messageId}');
  print('[FCM BG] Type: ${message.data['type']}');
  print('[FCM BG] ℹ️ Обработка происходит в MyFirebaseMessagingService.kt');
  print('[FCM BG] ========================================');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('[FCM BG] ✅ Background handler завершен');
}

String? _checkInviteLink() {
  if (kIsWeb) {
    try {
      final html = Uri.base;
      if (html.pathSegments.isNotEmpty && html.pathSegments.length >= 2) {
        if (html.pathSegments[0] == 'invite') {
          return html.pathSegments[1];
        }
      }
    } catch (e) {
      print('[Init] ⚠️ Ошибка при проверке URL: $e');
    }
  }
  return null;
}

void main() async {
  print('[Main] ========================================');
  print('[Main] 🚀 Запуск приложения SecureWave');
  print('[Main] Платформа: ${kIsWeb ? "Web" : "Mobile"}');
  print('[Main] ========================================');

  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('[Main] 🔥 Инициализация Firebase...');

    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: 'AIzaSyAW5HurHMo1l9ub2XKyr2nk-yP22bc_6F4',
          authDomain: 'wave-messenger-56985.firebaseapp.com',
          projectId: 'wave-messenger-56985',
          storageBucket: 'wave-messenger-56985.firebasestorage.app',
          messagingSenderId: '394959992893',
          appId: '1:394959992893:web:c7d493658ad06278661254',
        ),
      );
      print('[Main] ✅ Firebase инициализирован для Web');
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('[Main] ✅ Firebase инициализирован для Mobile');

      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      print('[Main] ✅ Background handler зарегистрирован');
      print('[Main] ℹ️ FCM обрабатывается в MyFirebaseMessagingService.kt');
    }
  } catch (e, stackTrace) {
    print('[Main] ❌ Ошибка инициализации Firebase: $e');
    print('[Main] Stack trace: $stackTrace');
  }

  print('[Main] 🏁 Запуск приложения...');
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
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, authProvider, _) {
        return MaterialApp(
          title: 'SecureWave',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
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

class InitializationWrapper extends StatefulWidget {
  const InitializationWrapper({Key? key}) : super(key: key);

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
    print('[Init] 🚀 Начало инициализации');
    print('[Init] ========================================');

    try {
      _inviteCode = _checkInviteLink();

      if (_inviteCode != null) {
        print('[Init] 🎫 Обнаружен invite code: $_inviteCode');
        setState(() {
          _isInitializing = false;
          _isAuthenticated = false;
        });
        return;
      }

      final authProvider = context.read<AuthProvider>();
      await authProvider.checkAuth();

      if (!mounted) return;

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        print('[Init] ========================================');
        print(
            '[Init] ✅ Пользователь авторизован: ${authProvider.currentUser!.email}');
        print('[Init] ========================================');

        if (!kIsWeb) {
          try {
            print('[Init] 🔔 Инициализация FCM...');
            await Future.delayed(Duration(milliseconds: 500));
            await FCMService().initialize();
            print('[Init] ✅ FCM инициализирован');

            final fcmToken = await FCMService().getToken();
            if (fcmToken != null) {
              print(
                  '[Init] 🔑 FCM токен получен: ${fcmToken.substring(0, 30)}...');
              await FCMService().refreshToken();
              print('[Init] ✅ FCM токен зарегистрирован на сервере');
            }
          } catch (e) {
            print('[Init] ⚠️ Ошибка FCM (не критично): $e');
          }
        }

        // ⭐⭐⭐ КРИТИЧНО: Инициализируем WebRTC ПЕРВЫМ, ДО загрузки чатов!
        try {
          print('[Init] 📞 Инициализация WebRTC...');
          await WebRTCService.instance.initialize(
            authProvider.currentUser!.id.toString(),
          );
          print('[Init] ✅ WebRTC инициализирован');

          // ⭐ Уведомляем CallOverlayWrapper что WebRTC готов
          if (mounted) _notifyWebRTCReady();

          // ⭐ Даем время WebSocket подключиться и получить pending звонки
          await Future.delayed(Duration(milliseconds: 1000));
          print('[Init] ⏳ Даём время WebSocket получить pending звонки...');
        } catch (e) {
          print('[Init] ⚠️ Ошибка WebRTC (не критично): $e');
        }

        try {
          print('[Init] 💬 Загрузка чатов...');
          final chatProvider = context.read<ChatProvider>();
          chatProvider
              .setCurrentUserId(authProvider.currentUser!.id.toString());
          await chatProvider.loadChats();
          print('[Init] ✅ Чаты загружены');
        } catch (e) {
          print('[Init] ⚠️ Ошибка загрузки чатов: $e');
        }

        setState(() {
          _isAuthenticated = true;
          _isInitializing = false;
        });

        print('[Init] ========================================');
        print('[Init] ✅ Инициализация завершена успешно');
        print('[Init] ========================================');
      } else {
        print('[Init] ℹ️ Пользователь не авторизован');
        setState(() {
          _isAuthenticated = false;
          _isInitializing = false;
        });
      }
    } catch (e, stackTrace) {
      print('[Init] ========================================');
      print('[Init] ❌ Ошибка инициализации: $e');
      print('[Init] Stack trace: $stackTrace');
      print('[Init] ========================================');

      setState(() {
        _isAuthenticated = false;
        _isInitializing = false;
      });
    }
  }

  void _notifyWebRTCReady() {
    final callOverlayState =
        context.findAncestorStateOfType<_CallOverlayWrapperState>();
    callOverlayState?.onWebRTCReady();
  }

  @override
  Widget build(BuildContext context) {
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
                Text('🔐', style: TextStyle(fontSize: 80)),
                SizedBox(height: 20),
                Text('SecureWave',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 40),
                CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                SizedBox(height: 20),
                Text('Initializing...',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    if (_inviteCode != null) {
      return InviteRegisterScreen(inviteCode: _inviteCode!);
    }

    return _isAuthenticated ? HomeScreen() : LoginScreen();
  }
}

class CallOverlayWrapper extends StatefulWidget {
  final Widget child;

  const CallOverlayWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _CallOverlayWrapperState createState() => _CallOverlayWrapperState();
}

class _CallOverlayWrapperState extends State<CallOverlayWrapper> {
  StreamSubscription<Call?>? _callSubscription;
  OverlayEntry? _overlayEntry;
  MethodChannel? _notificationChannel;
  bool _isWebRTCReady = false;

  @override
  void initState() {
    super.initState();
    print('[CallOverlay] ========================================');
    print('[CallOverlay] 🎭 CallOverlayWrapper инициализирован');
    print('[CallOverlay] ========================================');

    _setupNotificationChannel();

    if (!kIsWeb) {
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) _setupFCMCallback();
      });
    }
  }

  void _setupNotificationChannel() {
    print('[CallOverlay] 🔧 Настройка notification channel...');

    _notificationChannel =
        const MethodChannel('com.securewave.app/notification');

    _notificationChannel?.setMethodCallHandler((call) async {
      print('[CallOverlay] ========================================');
      print('[CallOverlay] 📱 MethodChannel callback: ${call.method}');
      print('[CallOverlay] ========================================');

      if (call.method == 'onNotificationTap') {
        try {
          final data = Map<String, dynamic>.from(call.arguments);
          _handleNativeIntent(data);
        } catch (e) {
          print('[CallOverlay] ❌ Ошибка: $e');
        }
      }
    });

    print('[CallOverlay] ✅ Notification channel настроен');
  }

  // ⭐⭐⭐ ИСПРАВЛЕНО: Правильная обработка accept/decline
  void _handleNativeIntent(Map<String, dynamic> data) {
    final type = data['type'];

    if (type == 'incoming_call') {
      final callId = data['callId'];
      final callerName = data['callerName'];
      final callType = data['callType'];
      final action = data['action'];

      print('[CallOverlay] ========================================');
      print('[CallOverlay] 📞 Входящий звонок!');
      print('[CallOverlay]   - callId: $callId');
      print('[CallOverlay]   - callerName: $callerName');
      print('[CallOverlay]   - callType: $callType');
      print('[CallOverlay]   - action: $action');
      print('[CallOverlay]   - _isWebRTCReady: $_isWebRTCReady');
      print('[CallOverlay] ========================================');

      if (callId == null) {
        print('[CallOverlay] ❌ callId отсутствует!');
        return;
      }

      // ⭐ КРИТИЧНО: Ждём пока WebRTC инициализируется
      if (!_isWebRTCReady) {
        print('[CallOverlay] ⏳ WebRTC ещё не готов, ждём...');

        // Ждём до 5 секунд пока WebRTC инициализируется
        int attempts = 0;
        Timer.periodic(Duration(milliseconds: 500), (timer) {
          attempts++;

          if (_isWebRTCReady) {
            timer.cancel();
            print('[CallOverlay] ✅ WebRTC готов, обрабатываем звонок!');
            _processCallAction(callId, callerName, callType, action);
          } else if (attempts >= 10) {
            timer.cancel();
            print('[CallOverlay] ❌ Timeout ожидания WebRTC!');
          }
        });

        return;
      }

      _processCallAction(callId, callerName, callType, action);
    }
  }

  void _processCallAction(
      String callId, String? callerName, String? callType, String? action) {
    if (action == 'accept') {
      print('[CallOverlay] ========================================');
      print('[CallOverlay] ✅✅✅ ПРИНИМАЕМ ЗВОНОК!');
      print('[CallOverlay] ========================================');

      final call = Call(
        id: callId,
        chatId: 'unknown',
        callerId: '',
        callerName: callerName ?? 'Unknown',
        receiverId: '',
        receiverName: 'You',
        callType: callType ?? 'audio',
        status: CallStatus.connecting,
        startTime: DateTime.now(),
      );

      // ⭐⭐⭐ АКТИВНОЕ ОЖИДАНИЕ: Проверяем каждые 100ms, готов ли offer
      print('[CallOverlay] ⏳ Ждём получения call_offer через WebSocket...');

      int attempts = 0;
      Timer.periodic(Duration(milliseconds: 100), (timer) {
        attempts++;

        // ⭐ Используем публичный getter
        final hasCall = WebRTCService.instance.currentCall?.id == callId;

        if (hasCall) {
          timer.cancel();
          print('[CallOverlay] ========================================');
          print('[CallOverlay] ✅✅✅ CALL_OFFER ПОЛУЧЕН! (попытка $attempts)');
          print('[CallOverlay] ========================================');

          // Отвечаем на звонок
          print('[CallOverlay] 📞 Вызываем WebRTCService.answerCall()...');
          WebRTCService.instance.answerCall(callId).then((_) {
            print('[CallOverlay] ========================================');
            print('[CallOverlay] ✅ answerCall() выполнен успешно!');
            print('[CallOverlay] ========================================');
          }).catchError((error) {
            print('[CallOverlay] ========================================');
            print('[CallOverlay] ❌ Ошибка answerCall(): $error');
            print('[CallOverlay] ========================================');
          });

          // Открываем CallScreen
          print('[CallOverlay] 🚀 Открываем CallScreen...');
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CallScreen(initialCall: call),
            ),
          );

          print('[CallOverlay] ========================================');
          print('[CallOverlay] ✅ CallScreen запущен');
          print('[CallOverlay] ========================================');
        } else if (attempts >= 30) {
          // Максимум 3 секунды (30 * 100ms)
          timer.cancel();
          print('[CallOverlay] ========================================');
          print('[CallOverlay] ❌ TIMEOUT: call_offer не получен за 3 секунды!');
          print('[CallOverlay] ========================================');
        } else {
          print(
              '[CallOverlay] ⏳ Попытка $attempts/30: offer ещё не получен...');
        }
      });
    } else if (action == 'decline') {
      print('[CallOverlay] ========================================');
      print('[CallOverlay] ❌ ОТКЛОНЯЕМ ЗВОНОК!');
      print('[CallOverlay] ========================================');

      WebRTCService.instance.declineCall(callId);

      print('[CallOverlay] ✅ Звонок отклонён');
      print('[CallOverlay] ========================================');
    } else {
      print('[CallOverlay] ⚠️ Неизвестное действие: $action');
    }
  }

  void _setupFCMCallback() {
    try {
      FCMService().onIncomingCall = (data) {
        if (!mounted) return;

        final callId = data['callId'];
        if (callId == null) return;

        final call = Call(
          id: callId,
          chatId: data['chatId'] ?? 'unknown',
          callerId: '',
          callerName: data['callerName'] ?? 'Unknown',
          receiverId: '',
          receiverName: 'You',
          callType: data['callType'] ?? 'audio',
          status: CallStatus.incoming,
          startTime: DateTime.now(),
        );

        _showIncomingCallOverlay(call);
      };
    } catch (e) {
      print('[CallOverlay] ❌ Ошибка: $e');
    }
  }

  // ⭐ Вызывается когда WebRTC готов
  void onWebRTCReady() {
    if (!mounted) return;
    print('[CallOverlay] ========================================');
    print('[CallOverlay] 📞📞📞 WebRTC ГОТОВ!');
    print('[CallOverlay] ========================================');

    setState(() {
      _isWebRTCReady = true;
    });

    _subscribeToCallState();
  }

  void _subscribeToCallState() {
    print('[CallOverlay] 🔔 Подписка на callState stream...');

    _callSubscription?.cancel();
    _callSubscription = WebRTCService.instance.callState.listen((call) {
      if (!mounted) return;

      print('[CallOverlay] 📢 CallState изменился: ${call?.status}');

      if (call != null && call.status == CallStatus.incoming) {
        print('[CallOverlay] 📞 Показываем overlay для входящего звонка');
        _showIncomingCallOverlay(call);
      } else if (call == null || call.status == CallStatus.ended) {
        print('[CallOverlay] 🔴 Скрываем overlay');
        _hideIncomingCallOverlay();
      }
    });

    print('[CallOverlay] ✅ Подписка на callState активна');
  }

  void _showIncomingCallOverlay(Call call) {
    _overlayEntry?.remove();
    final overlayContext = context;

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: IncomingCallOverlay(
            incomingCall: call,
            onDismiss: _hideIncomingCallOverlay,
            onAccept: () async {
              try {
                await WebRTCService.instance.answerCall(call.id);
              } catch (e) {
                print('[CallOverlay] ❌ Ошибка: $e');
              }
              _hideIncomingCallOverlay();
              Navigator.of(overlayContext).push(
                MaterialPageRoute(
                    builder: (_) => CallScreen(initialCall: call)),
              );
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideIncomingCallOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      try {
        FCMService().onIncomingCall = null;
      } catch (e) {}
    }

    _hideIncomingCallOverlay();
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
