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
import 'screens/home_screen.dart';
import 'screens/call_screen.dart';
import 'services/webrtc_service.dart';
import 'services/fcm_service.dart';
import 'services/websocket_manager.dart';
import 'services/api_service.dart';
import 'services/permissions_service.dart';
import 'models/call.dart';
import 'helpers/ios_callkit_handler.dart'
    if (dart.library.html) 'helpers/ios_callkit_handler_stub.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // print('[FCM BG] ========================================');
  // print('[FCM BG] Background message: ${message.data['type']}');
  // print('[FCM BG] Data: ${message.data}');
  // print('[FCM BG] ========================================');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final type = message.data['type'];
  
  // ⭐⭐⭐ КРИТИЧНО: В background handler НЕ вызываем native код
  // Обработка входящих звонков происходит в MyFirebaseMessagingService.kt
  // который вызывается автоматически при получении FCM сообщения
  if (type == 'incoming_call' || type == 'call') {
    // print('[FCM BG] 📞 ВХОДЯЩИЙ ЗВОНОК в background!');
    // print('[FCM BG] Call ID: ${message.data['callId'] ?? message.data['call_id']}');
    // print('[FCM BG] Caller: ${message.data['callerName'] ?? message.data['caller_name'] ?? 'Unknown'}');
    // print('[FCM BG] ⚠️ Обработка происходит в MyFirebaseMessagingService.kt');
    // print('[FCM BG] ConnectionService будет вызван автоматически');
  } else if (type == 'new_message') {
    // ⭐⭐⭐ ИСПРАВЛЕНО: Для iOS уведомления о сообщениях обрабатываются через AppDelegate.swift
    // В background handler мы только логируем, но не показываем уведомление
    // iOS автоматически покажет уведомление если оно правильно настроено в payload
    // print('[FCM BG] 💬 НОВОЕ СООБЩЕНИЕ в background!');
    // print('[FCM BG] Chat ID: ${message.data['chatId'] ?? message.data['chat_id']}');
    // print('[FCM BG] Sender: ${message.data['senderName'] ?? message.data['sender_name'] ?? 'Unknown'}');
    // print('[FCM BG] Message: ${message.data['messageText'] ?? message.data['message'] ?? ''}');
    // print('[FCM BG] ========================================');
    // print('[FCM BG] ⚠️ КРИТИЧНО для iOS:');
    // print('[FCM BG] ⚠️ Backend должен отправлять payload с полем "notification":');
    // print('[FCM BG] ⚠️ {');
    // print('[FCM BG] ⚠️   "notification": {');
    // print('[FCM BG] ⚠️     "title": "Новое сообщение",');
    // print('[FCM BG] ⚠️     "body": "Текст сообщения"');
    // print('[FCM BG] ⚠️   },');
    // print('[FCM BG] ⚠️   "data": { ... }');
    // print('[FCM BG] ⚠️ }');
    // print('[FCM BG] ⚠️ Без поля "notification" iOS НЕ покажет уведомление!');
    // print('[FCM BG] ========================================');
  }
  
  // print('[FCM BG] ========================================');
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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
    } else {
      // ✅ Firebase теперь работает на Android и iOS (есть платная подписка Apple Developer)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      if (kIsWeb) {
        // print('[Main] ✅ Firebase инициализирован для Web');
      } else {
        // print(           // '[Main] ✅ Firebase инициализирован для ${Platform.operatingSystem}');
      }
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
          home: CallHandler(child: InitializationWrapper()),
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
      final authProvider = context.read<AuthProvider>();
      await authProvider.checkAuth();

      if (!mounted) return;

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        // print('[Init] ✅ Авторизован: ${authProvider.currentUser!.email}');

        // Запрашиваем разрешения при первом запуске
        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          final isFirstLaunch = await PermissionsService.isFirstLaunch();
          if (isFirstLaunch) {
            // print('[Init] 📱 Первый запуск - запрашиваем разрешения');
            try {
              await PermissionsService.requestAllPermissions();
              await PermissionsService.markFirstLaunchCompleted();
              // print('[Init] ✅ Разрешения запрошены');
            } catch (e) {
              // print('[Init] ⚠️ Ошибка запроса разрешений: $e');
            }
          }
        }

        try {
          await WebRTCService.instance.initialize(
            authProvider.currentUser!.id.toString(),
          );
          // print('[Init] ✅ WebRTC готов');

          if (mounted) _notifyWebRTCReady();
        } catch (e) {
          // print('[Init] ⚠️ WebRTC error: $e');
        }

        if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
          final platformName = Platform.isIOS ? 'iOS' : (Platform.isAndroid ? 'Android' : 'Unknown');
          // print(             // '[Init] Обнаружена платформа: $platformName. Запуск инициализации FCM...');
          // ✅ FCM теперь включён на iOS (есть платная подписка Apple Developer)
          try {
            await FCMService().initialize();
            final fcmToken = await FCMService().getToken();
            if (fcmToken != null) {
              // print('[Init] ✅ FCM токен получен: $fcmToken');
              await FCMService().refreshToken();
              // print('[Init] ✅ FCM готов');
            } else {
              // print(                 // '[Init] ⚠️ Не удалось получить FCM токен, но инициализация продолжается.');
            }
          } catch (e) {
            // print('[Init] ⚠️ Ошибка FCM: $e');
          }
        }

        // ⭐⭐⭐ ВАЖНО: На Web Platform.isIOS недоступен, поэтому сначала проверяем kIsWeb
        if (!kIsWeb && Platform.isIOS) {
          // ⭐⭐⭐ Инициализируем iOS CallKit и VoIP Push
          try {
            // print('[Init] ========================================');
            // print('[Init] 📱 Инициализация iOS CallKit Handler');
            // print('[Init] Platform.isIOS: ${Platform.isIOS}');
            // print('[Init] ========================================');
            IOSCallKitHandler().initialize();
            // print('[Init] ✅ IOSCallKitHandler.initialize() вызван');

            // Регистрируем callback для получения VoIP токена
            IOSCallKitHandler().setVoipTokenCallback((token) async {
              // print('[Init] ========================================');
              // print('[Init] 📱 VoIP токен получен в main.dart');
              // print('[Init] Token: ${token.substring(0, 30)}...');
              // print('[Init] Длина токена: ${token.length}');
              // print('[Init] ========================================');

              // Отправляем токен на backend
              try {
                final apiService = ApiService.instance;
                // print('[Init] 📤 Отправка VoIP токена на backend...');

                final response = await apiService.registerVoIPToken(token);

                if (response != null && response['success'] == true) {
                  // print('[Init] ========================================');
                  // print(                     // '[Init] ✅ VoIP токен успешно зарегистрирован на backend');
                  if (response['tokenId'] != null) {
                    // print('[Init] Token ID: ${response['tokenId']}');
                  }
                  // print('[Init] ========================================');
                } else {
                  // print('[Init] ========================================');
                  // print('[Init] ⚠️ Не удалось зарегистрировать VoIP токен');
                  if (response != null) {
                    // print('[Init] Ответ сервера: $response');
                  } else {
                    // print('[Init] Ответ сервера: null');
                  }
                  // print('[Init] ========================================');
                }
              } catch (e, stackTrace) {
                // print('[Init] ========================================');
                // print('[Init] ❌ Ошибка регистрации VoIP токена');
                // print('[Init] Error: $e');
                // print('[Init] Stack trace: $stackTrace');
                // print('[Init] ========================================');
              }
            });

            // print('[Init] ✅ iOS CallKit Handler готов');
          } catch (e) {
            // print('[Init] ⚠️ iOS CallKit error: $e');
          }
        }

        await Future.delayed(Duration(milliseconds: 1500));

        try {
          final chatProvider = context.read<ChatProvider>();
          chatProvider
              .setCurrentUserId(authProvider.currentUser!.id.toString());
          await chatProvider.loadChats();
          // print('[Init] ✅ Чаты загружены');
        } catch (e) {
          // print('[Init] ⚠️ Chats error: $e');
        }

        // print('[Init] 🔄 Вызываем setState для обновления UI...');
        // print('[Init] _isAuthenticated будет: true');
        // print('[Init] _isInitializing будет: false');
        
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _isInitializing = false;
          });
          // print('[Init] ✅✅✅ ГОТОВО!');
          // print('[Init] Состояние после setState: _isAuthenticated=$_isAuthenticated, _isInitializing=$_isInitializing');
          
          // ⭐⭐⭐ ПРИНУДИТЕЛЬНОЕ ОБНОВЛЕНИЕ UI
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // print('[Init] 🔄 Принудительное обновление UI через addPostFrameCallback');
              setState(() {});
            }
          });
        } else {
          // print('[Init] ⚠️ Widget не mounted, setState не вызван');
        }
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
    // print('[Init] 🔨 build() вызван: _isInitializing=$_isInitializing, _isAuthenticated=$_isAuthenticated');
    
    if (_isInitializing) {
      // print('[Init] 🔨 Возвращаем экран загрузки (Initializing...)');
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

    if (_isAuthenticated) {
      // print('[Init] 🔨 Возвращаем HomeScreen (авторизован)');
      return HomeScreen();
    } else {
      // print('[Init] 🔨 Возвращаем LoginScreen (не авторизован)');
      return LoginScreen();
    }
  }
}

class CallHandler extends StatefulWidget {
  final Widget child;

  const CallHandler({Key? key, required this.child}) : super(key: key);

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
      Future.delayed(Duration(seconds: 2), () {
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
      } else if (call.method == 'declineCall') {
        try {
          final callId = call.arguments['callId'] as String;
          // print('[CallHandler] 🚫 Decline from notification: $callId');

          // Отправляем decline на backend
          WebSocketManager.instance.declineCall(callId);

          // Закрываем CallScreen если открыт
          if (_isCallScreenOpen) {
            Navigator.of(context).pop();
            _isCallScreenOpen = false;
          }

          // print('[CallHandler] ✅ Call declined via notification');
        } catch (e) {
          // print('[CallHandler] ❌ Error declining call: $e');
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

      Future.delayed(Duration(seconds: 10), () {
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
      await Future.delayed(Duration(milliseconds: 100));
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
      Timer.periodic(Duration(milliseconds: 100), (timer) {
        attempts++;

        final currentCall = WebRTCService.instance.currentCall;
        if (currentCall?.id == callId) {
          timer.cancel();
          // print('[CallHandler] ========================================');
          // print('[CallHandler] ✅ Offer получен через WebSocket!');
          // print('[CallHandler] 🎯 Открываем CallScreen, затем принимаем звонок');
          // print('[CallHandler] ========================================');

          // ⭐⭐⭐ ИСПРАВЛЕНО: Сначала открываем CallScreen
          _openCallScreen(currentCall!, autoAccept: true);

          // ⭐⭐⭐ КРИТИЧНО: Принимаем звонок после задержки (когда UI готов)
          Future.delayed(Duration(milliseconds: 500), () {
            // print('[CallHandler] ========================================');
            // print('[CallHandler] 🎯 CallScreen открыт, принимаем звонок через WebRTC');
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
        // print('[CallHandler]   - callerName: $callerName');
        // print('[CallHandler]   - callType: $callType');
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

          Future.delayed(Duration(seconds: 10), () {
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
          Timer.periodic(Duration(milliseconds: 100), (timer) {
            attempts++;

            final currentCall = WebRTCService.instance.currentCall;
            if (currentCall?.id == callId) {
              timer.cancel();
              // print('[CallHandler] ========================================');
              // print('[CallHandler] ✅ Offer получен!');
              // print(                 // '[CallHandler] 🎯 Открываем CallScreen, затем принимаем звонок');
              // print('[CallHandler] ========================================');

              // ⭐⭐⭐ ИСПРАВЛЕНО: Сначала открываем CallScreen
              _openCallScreen(currentCall!, autoAccept: true);

              // ⭐⭐⭐ ОПТИМИЗИРОВАНО: Принимаем звонок после минимальной задержки (было 500ms, стало 200ms)
              Future.delayed(Duration(milliseconds: 200), () {
                // print('[CallHandler] ========================================');
                // print(                   // '[CallHandler] 🎯 CallScreen открыт, принимаем звонок через WebRTC');
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

          return;
        }

        // ⭐⭐⭐ НОВАЯ ЛОГИКА: Обычный входящий звонок без action или action == 'open'
        // Ждем offer от WebSocket и открываем CallScreen
        // print('[CallHandler] ========================================');
        // print('[CallHandler] 📲 Обработка входящего звонка (action: $action)');
        // print('[CallHandler] Call ID: $callId');
        // print('[CallHandler] AutoAccept: $autoAccept');
        // print('[CallHandler] 🚫 СРАЗУ отменяем уведомление');
        // print('[CallHandler] 🎯 Ждем offer от WebSocket и откроем CallScreen');
        // print('[CallHandler] ========================================');

        // 🚫 КРИТИЧНО: Отменяем уведомление СРАЗУ, не дожидаясь offer!
        if (!kIsWeb && Platform.isAndroid) {
          FCMService().cancelCallNotification(callId);
          // print('[CallHandler] ✅ Уведомление отменено для callId: $callId');
        }

        int attempts = 0;
        Timer.periodic(Duration(milliseconds: 100), (timer) {
          attempts++;

          final currentCall = WebRTCService.instance.currentCall;
          if (currentCall?.id == callId) {
            timer.cancel();
            // print('[CallHandler] ========================================');
            // print('[CallHandler] ✅ Offer получен от WebSocket!');
            // print('[CallHandler] 🎯 Открываем CallScreen');
            // print('[CallHandler] ========================================');

            _openCallScreen(currentCall!, autoAccept: autoAccept);
          } else if (attempts >= 100) { // ⭐⭐⭐ УВЕЛИЧЕНО: 10 секунд для pending звонков
            timer.cancel();
            // print('[CallHandler] ========================================');
            // print('[CallHandler] ⚠️ Timeout: offer не получен от WebSocket за 10 секунд');
            // print('[CallHandler] ⚠️ Возможно, звонок уже завершен или не был отправлен');
            // print('[CallHandler] ⚠️ Ожидаем pending звонок от сервера...');
            // print('[CallHandler] ========================================');
          } else if (attempts % 10 == 0) {
            // print(               // '[CallHandler] ⏳ Ожидание offer от WebSocket... (${attempts * 100}ms)');
          }
        });
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

        Future.delayed(Duration(seconds: 10), () {
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
        // print(           // '[CallHandler] 🔒 БЛОКИРОВАНО: Ждем native accept для ${call.id}');
        // print('[CallHandler] НЕ открываем CallScreen через callState');
        // print('[CallHandler] ========================================');
        return;
      }

      if (call != null &&
          call.status == CallStatus.incoming &&
          !_isCallScreenOpen) {
        // ⭐⭐⭐ НОВОЕ: Для iOS проверяем CallKit accept flag
        bool shouldAutoAccept = false;
        if (!kIsWeb && Platform.isIOS) {
          final callKitHandler = IOSCallKitHandler();
          shouldAutoAccept = callKitHandler.wasCallAcceptedViaCallKit(call.id);

          if (shouldAutoAccept) {
            // print('[CallHandler] ========================================');
            // print('[CallHandler] ✅ CallKit Accept обнаружен!');
            // print('[CallHandler] Открываем CallScreen с auto-accept');
            // print('[CallHandler] Call ID: ${call.id}');
            // print('[CallHandler] ========================================');
          }
        }

        if (!shouldAutoAccept) {
          // print('[CallHandler] ========================================');
          // print('[CallHandler] 📞 ВХОДЯЩИЙ ЗВОНОК через WebSocket!');
          // print('[CallHandler] Открываем CallScreen БЕЗ auto-accept');
          // print('[CallHandler] ========================================');
        }

        _openCallScreen(call, autoAccept: shouldAutoAccept);

        // ⭐⭐⭐ ИСПРАВЛЕНО: НЕ принимаем звонок здесь, если IOSCallKitHandler уже принял его
        // IOSCallKitHandler сам принимает звонок через _acceptCallSafely
        // Это предотвращает двойное принятие звонка
        if (shouldAutoAccept && !kIsWeb && Platform.isIOS) {
          // print('[CallHandler] ========================================');
          // print('[CallHandler] ✅ CallKit Accept обнаружен');
          // print('[CallHandler] Call ID: ${call.id}');
          // print('[CallHandler] ⚠️ IOSCallKitHandler сам примет звонок, не дублируем');
          // print('[CallHandler] ========================================');
          
          // ⭐⭐⭐ КРИТИЧНО: НЕ вызываем acceptCall здесь
          // IOSCallKitHandler._acceptCallSafely уже примет звонок
          // Это предотвращает конфликт при первом принятии звонка через слайдер
        }
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
    // print(       // '[CallHandler]   - navigatorKey.currentState: ${navigatorKey.currentState}');
    // print(       // '[CallHandler]   - navigatorKey.currentContext: ${navigatorKey.currentContext}');
    // print('[CallHandler]   - mounted: $mounted');
    // print('[CallHandler] ========================================');

    if (navigatorKey.currentState == null ||
        navigatorKey.currentContext == null) {
      // print('[CallHandler] ❌❌❌ Navigator не готов!');
      // print('[CallHandler] Пробуем через 500ms...');

      Future.delayed(Duration(milliseconds: 500), () {
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

    // 🚫 Отменяем уведомление для этого звонка (если есть)
    if (!kIsWeb && Platform.isAndroid) {
      FCMService().cancelCallNotification(call.id);
      // print('[CallHandler] 🚫 Отменяем уведомление для callId: ${call.id}');
    }

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
              // print(                 // '[CallHandler]   Создаем CallScreen с autoAccept=$autoAccept');

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
