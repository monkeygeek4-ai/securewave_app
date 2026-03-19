// lib/main.dart
// ИСПРАВЛЕННАЯ ВЕРСИЯ - предотвращает двойное открытие CallScreen

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:io' show Platform;
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
import 'services/websocket_manager.dart';
import 'models/call.dart';
import 'helpers/ios_callkit_helper.dart'
    if (dart.library.html) 'helpers/ios_callkit_helper_stub.dart';
import 'helpers/ios_callkit_handler.dart'
    if (dart.library.html) 'helpers/ios_callkit_handler_stub.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // print('[FCM BG] Background message: ${message.data['type']}');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
    } catch (e) {}
  }
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyAW5HurHMo1l9ub2XKyr2nk-yP22bc_6F4',
          authDomain: 'wave-messenger-56985.firebaseapp.com',
          projectId: 'wave-messenger-56985',
          storageBucket: 'wave-messenger-56985.firebasestorage.app',
          messagingSenderId: '394959992893',
          appId: '1:394959992893:web:c7d493658ad06278661254',
        ),
      );
    } else if (!Platform.isIOS) {
      // Firebase только для Android (iOS имеет проблемы с APNS)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    } else {
      // print('[Main] ⏭️ Firebase отключен на iOS');
    }
  } catch (e) {
    // print('[Main] Firebase error: $e');
  }

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
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
            primaryColor: const Color(0xFF2B5CE6),
          ),
          themeMode: themeProvider.themeMode,
          home: const CallHandler(child: InitializationWrapper()),
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
  const InitializationWrapper({super.key});

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
    // print('[Init] ========================================');
    // print('[Init] 🚀 Инициализация');
    // print('[Init] ========================================');

    try {
      _inviteCode = _checkInviteLink();

      if (_inviteCode != null) {
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
        // print('[Init] ✅ Авторизован: ${authProvider.currentUser!.email}');

        try {
          await WebRTCService.instance.initialize(
            authProvider.currentUser!.id.toString(),
          );
          // print('[Init] ✅ WebRTC готов');

          if (mounted) _notifyWebRTCReady();
        } catch (e) {
          // print('[Init] ⚠️ WebRTC error: $e');
        }

        if (!kIsWeb && !Platform.isIOS) {
          // FCM отключен на iOS из-за проблем с APNS и бесплатным Apple ID
          try {
            await FCMService().initialize();
            final fcmToken = await FCMService().getToken();
            if (fcmToken != null) {
              await FCMService().refreshToken();
            }
            // print('[Init] ✅ FCM готов');
          } catch (e) {
            // print('[Init] ⚠️ FCM error: $e');
          }
        } else if (Platform.isIOS) {
          // print('[Init] ⏭️ FCM отключен на iOS (APNS не настроен)');
        }

        await Future.delayed(const Duration(milliseconds: 1500));

        try {
          final chatProvider = context.read<ChatProvider>();
          chatProvider
              .setCurrentUserId(authProvider.currentUser!.id.toString());
          await chatProvider.loadChats();
          // print('[Init] ✅ Чаты загружены');
        } catch (e) {
          // print('[Init] ⚠️ Chats error: $e');
        }

        setState(() {
          _isAuthenticated = true;
          _isInitializing = false;
        });

        // print('[Init] ✅✅✅ ГОТОВО!');
      } else {
        setState(() {
          _isAuthenticated = false;
          _isInitializing = false;
        });
      }
    } catch (e) {
      // print('[Init] ❌ Error: $e');
      setState(() {
        _isAuthenticated = false;
        _isInitializing = false;
      });
    }
  }

  void _notifyWebRTCReady() {
    final callHandler = context.findAncestorStateOfType<_CallHandlerState>();
    callHandler?.onWebRTCReady();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
          ),
          child: const Center(
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

class CallHandler extends StatefulWidget {
  final Widget child;

  const CallHandler({super.key, required this.child});

  @override
  _CallHandlerState createState() => _CallHandlerState();
}

class _CallHandlerState extends State<CallHandler> {
  StreamSubscription<Call?>? _callSubscription;
  MethodChannel? _notificationChannel;
  bool _isWebRTCReady = false;
  bool _isCallScreenOpen = false;
  String? _pendingCallIdFromNative;
  bool _waitingForNativeAccept = false;

  final Set<String> _declinedCallIds = {};

  @override
  void initState() {
    super.initState();
    // print('[CallHandler] Инициализирован');

    _setupNotificationChannel();

    if (!kIsWeb && !Platform.isIOS) {
      // FCM callbacks только для Android (iOS использует CallKit)
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _setupFCMCallback();
      });
    }
  }

  void _setupNotificationChannel() {
    _notificationChannel =
        const MethodChannel('com.securewave.app/notification');

    _notificationChannel?.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap') {
        try {
          final data = Map<String, dynamic>.from(call.arguments);
          _handleNativeIntent(data);
        } catch (e) {
          // print('[CallHandler] ❌ Error: $e');
        }
      }
    });
  }

  void _handleNativeIntent(Map<String, dynamic> data) {
    if (data['type'] != 'incoming_call') return;

    final callId = data['callId'];
    final callerName = data['callerName'];
    final callType = data['callType'];
    final action = data['action'];
    final autoAccept = data['autoAccept'] == true;
    final shouldDecline = data['shouldDecline'] == true;

    // print('[CallHandler] ========================================');
    // print('[CallHandler] 📞 Native Intent received');
    // print('[CallHandler]   - action: $action');
    // print('[CallHandler]   - callId: $callId');
    // print('[CallHandler]   - autoAccept: $autoAccept');
    // print('[CallHandler]   - shouldDecline: $shouldDecline');
    // print('[CallHandler] ========================================');

    if (callId == null) return;

    if (shouldDecline) {
      // print('[CallHandler] ========================================');
      // print('[CallHandler] ❌❌❌ НЕМЕДЛЕННОЕ ОТКЛОНЕНИЕ ЗВОНКА');
      // print('[CallHandler] callId: $callId');
      // print('[CallHandler] ========================================');

      _declinedCallIds.add(callId);
      // print('[CallHandler] ✅ Добавлен в _declinedCallIds: $callId');

      try {
        // print('[CallHandler] 📤 Отправляем call_decline через WebSocket');
        WebSocketManager.instance.declineCall(callId);
        // print('[CallHandler] ✅ call_decline отправлен');
      } catch (e) {
        // print('[CallHandler] ❌ Ошибка отправки decline: $e');
      }

      Future.delayed(const Duration(seconds: 10), () {
        _declinedCallIds.remove(callId);
        // print('[CallHandler] 🗑️ Удален из _declinedCallIds: $callId');
      });

      return;
    }

    if (!_isWebRTCReady) {
      // print('[CallHandler] ⏳ Ждём WebRTC...');
      _waitForWebRTC().then((_) {
        if (_isWebRTCReady) {
          _processCallAction(callId, callerName, callType, action, autoAccept);
        }
      });
      return;
    }

    _processCallAction(callId, callerName, callType, action, autoAccept);
  }

  Future<void> _waitForWebRTC() async {
    for (int i = 0; i < 50; i++) {
      if (_isWebRTCReady) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _processCallAction(String callId, String? callerName, String? callType,
      String? action, bool autoAccept) {
    if (action == 'accept') {
      // print('[CallHandler] ========================================');
      // print('[CallHandler] ✅ ACCEPT действие обнаружено');
      // print('[CallHandler] autoAccept: $autoAccept');
      // print('[CallHandler] ========================================');

      _pendingCallIdFromNative = callId;
      _waitingForNativeAccept = true;

      // print('[CallHandler] 🔒 Блокируем открытие через callState для $callId');

      int attempts = 0;
      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        attempts++;

        final currentCall = WebRTCService.instance.currentCall;
        if (currentCall?.id == callId) {
          timer.cancel();
          // print('[CallHandler] ========================================');
          // print('[CallHandler] ✅ Offer получен через WebSocket!');
          // print(
              '[CallHandler] 🎯 Открываем CallScreen, затем принимаем звонок');
          // print('[CallHandler] ========================================');

          // ⭐⭐⭐ ИСПРАВЛЕНО: Сначала открываем CallScreen
          _openCallScreen(currentCall!, autoAccept: true);

          // ⭐⭐⭐ КРИТИЧНО: Принимаем звонок после задержки (когда UI готов)
          Future.delayed(const Duration(milliseconds: 500), () {
            // print('[CallHandler] ========================================');
            // print(
                '[CallHandler] 🎯 CallScreen открыт, принимаем звонок через WebRTC');
            // print('[CallHandler] ========================================');
            WebRTCService.instance.acceptCall(callId);
          });

          _pendingCallIdFromNative = null;
          _waitingForNativeAccept = false;
        } else if (attempts >= 50) {
          timer.cancel();
          // print('[CallHandler] ========================================');
          // print('[CallHandler] ❌ Timeout: Offer не получен за 5 секунд');
          // print('[CallHandler] ========================================');

          _pendingCallIdFromNative = null;
          _waitingForNativeAccept = false;
        } else if (attempts % 10 == 0) {
          // print('[CallHandler] ⏳ Ожидание offer... (${attempts * 100}ms)');
        }
      });
    }
  }

  void _setupFCMCallback() {
    try {
      FCMService().onIncomingCall = (data) {
        // print('[CallHandler] ========================================');
        // print('[CallHandler] 📞 FCM foreground callback');
        // print('[CallHandler] Data: $data');
        // print('[CallHandler] ========================================');

        final callId = data['callId'] as String?;
        final callerName = data['callerName'] as String?;
        final callType = data['callType'] as String?;
        final action = data['action'] as String?;
        final autoAccept = data['autoAccept'] == true;
        final shouldDecline = data['shouldDecline'] == true;

        if (callId == null) {
          // print('[CallHandler] ⚠️ callId отсутствует');
          return;
        }

        // print('[CallHandler] Обработка FCM данных:');
        // print('[CallHandler]   - callId: $callId');
        // print('[CallHandler]   - action: $action');
        // print('[CallHandler]   - autoAccept: $autoAccept');
        // print('[CallHandler]   - shouldDecline: $shouldDecline');

        if (shouldDecline) {
          // print('[CallHandler] ========================================');
          // print('[CallHandler] ❌ DECLINE через FCM callback');
          // print('[CallHandler] ========================================');

          _declinedCallIds.add(callId);

          try {
            WebSocketManager.instance.declineCall(callId);
            // print('[CallHandler] ✅ call_decline отправлен');
          } catch (e) {
            // print('[CallHandler] ❌ Ошибка decline: $e');
          }

          Future.delayed(const Duration(seconds: 10), () {
            _declinedCallIds.remove(callId);
          });

          return;
        }

        if (action == 'accept') {
          // print('[CallHandler] ========================================');
          // print('[CallHandler] ✅ ACCEPT через FCM callback');
          // print('[CallHandler] 🎯 СРАЗУ принимаем звонок через WebRTC');
          // print('[CallHandler] ========================================');

          _pendingCallIdFromNative = callId;
          _waitingForNativeAccept = true;

          // Ждем offer от WebSocket
          int attempts = 0;
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
            attempts++;

            final currentCall = WebRTCService.instance.currentCall;
            if (currentCall?.id == callId) {
              timer.cancel();
              // print('[CallHandler] ========================================');
              // print('[CallHandler] ✅ Offer получен!');
              // print(
                  '[CallHandler] 🎯 Открываем CallScreen, затем принимаем звонок');
              // print('[CallHandler] ========================================');

              // ⭐⭐⭐ ИСПРАВЛЕНО: Сначала открываем CallScreen
              _openCallScreen(currentCall!, autoAccept: true);

              // ⭐⭐⭐ КРИТИЧНО: Принимаем звонок после задержки (когда UI готов)
              Future.delayed(const Duration(milliseconds: 500), () {
                // print('[CallHandler] ========================================');
                // print(
                    '[CallHandler] 🎯 CallScreen открыт, принимаем звонок через WebRTC');
                // print('[CallHandler] ========================================');
                WebRTCService.instance.acceptCall(callId);
              });

              _pendingCallIdFromNative = null;
              _waitingForNativeAccept = false;
            } else if (attempts >= 50) {
              timer.cancel();
              // print('[CallHandler] ❌ Timeout: offer не получен');

              _pendingCallIdFromNative = null;
              _waitingForNativeAccept = false;
            } else if (attempts % 10 == 0) {
              // print('[CallHandler] ⏳ Ожидание offer... (${attempts * 100}ms)');
            }
          });
        }
      };

      FCMService().onDeclineCall = (callId) {
        // print('[CallHandler] ========================================');
        // print('[CallHandler] ❌❌❌ FCM DECLINE CALLBACK');
        // print('[CallHandler] callId: $callId');
        // print('[CallHandler] ========================================');

        _declinedCallIds.add(callId);
        // print('[CallHandler] ✅ Добавлен в _declinedCallIds: $callId');

        try {
          // print('[CallHandler] 📤 Отправляем call_decline через WebSocket');
          WebSocketManager.instance.declineCall(callId);
          // print('[CallHandler] ✅ call_decline отправлен');
        } catch (e) {
          // print('[CallHandler] ❌ Ошибка отправки decline: $e');
        }

        Future.delayed(const Duration(seconds: 10), () {
          _declinedCallIds.remove(callId);
          // print('[CallHandler] 🗑️ Удален из _declinedCallIds: $callId');
        });
      };
    } catch (e) {
      // print('[CallHandler] FCM callback error: $e');
    }
  }

  void onWebRTCReady() {
    if (!mounted) return;

    // print('[CallHandler] ========================================');
    // print('[CallHandler] 📞 WebRTC ГОТОВ!');
    // print('[CallHandler] ========================================');

    setState(() {
      _isWebRTCReady = true;
    });

    _subscribeToCallState();
  }

  // ⭐⭐⭐ ИСПРАВЛЕНО: Добавлена проверка на статус connecting
  void _subscribeToCallState() {
    // print('[CallHandler] 🔔 Подписка на callState');

    _callSubscription?.cancel();
    _callSubscription = WebRTCService.instance.callState.listen((call) {
      if (!mounted) return;

      // print('[CallHandler] CallState изменен: ${call?.status}');

      if (call != null && _declinedCallIds.contains(call.id)) {
        // print('[CallHandler] ========================================');
        // print('[CallHandler] 🚫 БЛОКИРОВАНО: Звонок ${call.id} был declined!');
        // print('[CallHandler] НЕ открываем CallScreen!');
        // print('[CallHandler] ========================================');
        return;
      }

      if (call != null &&
          _waitingForNativeAccept &&
          call.id == _pendingCallIdFromNative) {
        // print('[CallHandler] ========================================');
        // print(
            '[CallHandler] 🔒 БЛОКИРОВАНО: Ждем native accept для ${call.id}');
        // print('[CallHandler] НЕ открываем CallScreen через callState');
        // print('[CallHandler] ========================================');
        return;
      }

      if (call != null &&
          call.status == CallStatus.incoming &&
          !_isCallScreenOpen) {
        // print('[CallHandler] ========================================');
        // print('[CallHandler] 📞 ВХОДЯЩИЙ ЗВОНОК через WebSocket!');
        // print('[CallHandler] Открываем CallScreen БЕЗ auto-accept');
        // print('[CallHandler] ========================================');

        _openCallScreen(call, autoAccept: false);
      }

      // ⭐⭐⭐ НОВОЕ: Сбрасываем флаги когда звонок принят
      if (call != null && call.status == CallStatus.connecting) {
        // print('[CallHandler] ========================================');
        // print('[CallHandler] 📞 Звонок переходит в CONNECTING');
        // print('[CallHandler] Сбрасываем _waitingForNativeAccept');
        // print('[CallHandler] ========================================');
        _waitingForNativeAccept = false;
        _pendingCallIdFromNative = null;
      }

      if (call == null ||
          call.status == CallStatus.ended ||
          call.status == CallStatus.declined) {
        _isCallScreenOpen = false;
        _waitingForNativeAccept = false;
        _pendingCallIdFromNative = null;
      }
    });
  }

  void _openCallScreen(Call call, {bool autoAccept = false}) {
    if (_isCallScreenOpen) {
      // print('[CallHandler] ⚠️ CallScreen уже открыт');
      return;
    }

    // print('[CallHandler] ========================================');
    // print('[CallHandler] 🚀🚀🚀 ОТКРЫВАЕМ CallScreen');
    // print('[CallHandler]   - callId: ${call.id}');
    // print('[CallHandler]   - call.status: ${call.status}');
    // print('[CallHandler]   - autoAccept: $autoAccept');
    // print(
        '[CallHandler]   - navigatorKey.currentState: ${navigatorKey.currentState}');
    // print(
        '[CallHandler]   - navigatorKey.currentContext: ${navigatorKey.currentContext}');
    // print('[CallHandler]   - mounted: $mounted');
    // print('[CallHandler] ========================================');

    if (navigatorKey.currentState == null ||
        navigatorKey.currentContext == null) {
      // print('[CallHandler] ❌❌❌ Navigator не готов!');
      // print('[CallHandler] Пробуем через 500ms...');

      Future.delayed(const Duration(milliseconds: 500), () {
        if (navigatorKey.currentState != null) {
          // print('[CallHandler] ✅ Navigator готов после задержки');
          _openCallScreen(call, autoAccept: autoAccept);
        } else {
          // print('[CallHandler] ❌ Navigator всё ещё NULL!');
        }
      });
      return;
    }

    _isCallScreenOpen = true;

    // ⭐⭐⭐ ИСПОЛЬЗУЕМ Navigator.of(context) напрямую
    scheduleMicrotask(() {
      // print('[CallHandler] 📱 scheduleMicrotask выполняется');

      final context = navigatorKey.currentContext;
      if (context == null) {
        // print('[CallHandler] ❌ Context is NULL!');
        _isCallScreenOpen = false;
        return;
      }

      try {
        // print('[CallHandler] 📱 Вызываем Navigator.of(context).push');

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (buildContext) {
              // print('[CallHandler] 📱 MaterialPageRoute builder вызван');
              // print('[CallHandler]   Context: $buildContext');
              // print(
                  '[CallHandler]   Создаем CallScreen с autoAccept=$autoAccept');

              return CallScreen(
                initialCall: call,
                autoAccept: autoAccept,
              );
            },
          ),
        ).then((_) {
          _isCallScreenOpen = false;
          // print('[CallHandler] CallScreen закрыт');
        });

        // print('[CallHandler] ✅ push() вызван на Navigator');
      } catch (e, stack) {
        // print('[CallHandler] ❌ Ошибка открытия CallScreen: $e');
        // print('[CallHandler] Stack: $stack');
        _isCallScreenOpen = false;
      }
    });
  }

  @override
  void dispose() {
    if (!kIsWeb && !Platform.isIOS) {
      // FCM cleanup только для Android
      try {
        FCMService().onIncomingCall = null;
        FCMService().onDeclineCall = null;
      } catch (e) {}
    }

    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
