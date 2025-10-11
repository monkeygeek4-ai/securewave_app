// lib/main.dart
// ПОЛНАЯ ВЕРСИЯ с background handler для FCM уведомлений + CallActivity

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Для MethodChannel
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
import 'services/api_service.dart';
import 'models/call.dart';
import 'widgets/incoming_call_overlay.dart';

// ⭐⭐⭐ BACKGROUND MESSAGE HANDLER для FCM
// ВАЖНО: Должен быть TOP-LEVEL функцией (вне классов)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Инициализируем Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('[FCM Background] ========================================');
  print('[FCM Background] 📩 Получено background сообщение');
  print('[FCM Background] Message ID: ${message.messageId}');
  print('[FCM Background] Data: ${message.data}');
  print('[FCM Background] ========================================');

  final data = message.data;
  final type = data['type'];

  if (type == 'incoming_call') {
    print('[FCM Background] 📞 Входящий звонок в background!');

    final callId = data['callId'] ?? 'unknown';
    final callerName = data['callerName'] ?? 'Unknown';
    final callType = data['callType'] ?? 'audio';

    print('[FCM Background] Caller: $callerName');
    print('[FCM Background] CallType: $callType');
    print('[FCM Background] Запуск CallActivity...');

    // ⭐ Вместо показа уведомления - запускаем CallActivity через MethodChannel
    try {
      const platform = MethodChannel('com.securewave.app/call');
      await platform.invokeMethod('showCallScreen', {
        'callId': callId,
        'callerName': callerName,
        'callType': callType,
      });
      print('[FCM Background] ✅ CallActivity запущена');
    } catch (e) {
      print('[FCM Background] ❌ Ошибка запуска CallActivity: $e');
      print('[FCM Background] Fallback: показываем стандартное уведомление');

      // Fallback: показываем обычное уведомление
      final FlutterLocalNotificationsPlugin localNotifications =
          FlutterLocalNotificationsPlugin();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await localNotifications.initialize(initializationSettings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'calls_channel',
        'Incoming Calls',
        description: 'Notifications for incoming calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'calls_channel',
        'Incoming Calls',
        channelDescription: 'Notifications for incoming calls',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        ongoing: true,
        autoCancel: false,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'decline',
            '❌ Decline',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'accept',
            '✅ Accept',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );

      final NotificationDetails notificationDetails =
          NotificationDetails(android: androidDetails);

      await localNotifications.show(
        callId.hashCode,
        '📞 Incoming Call',
        'From: $callerName',
        notificationDetails,
        payload: 'call:$callId:$callerName',
      );

      print('[FCM Background] ✅ Fallback уведомление показано');
    }
  }

  print('[FCM Background] ========================================');
}

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

void main() async {
  print('[Main] ========================================');
  print('[Main] Запуск приложения SecureWave');
  print('[Main] Платформа: ${kIsWeb ? "Web" : "Mobile"}');
  print('[Main] ========================================');

  // Инициализация Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Инициализация Firebase
    print('[Main] 🔥 Инициализация Firebase...');

    if (kIsWeb) {
      // Для Web используем конфигурацию напрямую
      print('[Main] 🌐 Инициализация Firebase для Web...');
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
      // Для мобильных платформ используем firebase_options.dart
      print('[Main] 📱 Инициализация Firebase для Mobile...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('[Main] ✅ Firebase инициализирован для Mobile');

      // ⭐⭐⭐ РЕГИСТРАЦИЯ BACKGROUND HANDLER
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
      print('[Main] ✅ Background handler зарегистрирован');

      print('[Main] ℹ️ FCM будет инициализирован после авторизации');
    }
  } catch (e, stackTrace) {
    print('[Main] ❌ Ошибка инициализации Firebase: $e');
    print('[Main] Stack trace: $stackTrace');
    // Продолжаем работу даже при ошибке Firebase
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

// Виджет инициализации приложения
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
    print('[Init] Начало инициализации приложения');
    print('[Init] ========================================');

    try {
      _inviteCode = _checkInviteLink();

      if (_inviteCode != null) {
        print('[Init] 🎫 Обнаружен инвайт-код, показываем регистрацию');
        setState(() {
          _isInitializing = false;
          _isAuthenticated = false;
        });
        return;
      }

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

        // Инициализируем FCM для mobile
        if (!kIsWeb) {
          print('[Init] ========================================');
          print('[Init] 📱 ИНИЦИАЛИЗАЦИЯ FCM (ПОСЛЕ FIREBASE И AUTH)');
          print('[Init] ========================================');

          try {
            // Даем Firebase время на полную инициализацию
            await Future.delayed(Duration(milliseconds: 500));

            // Инициализируем FCM
            print('[Init] 🔥 Вызов FCMService().initialize()...');
            await FCMService().initialize();
            print('[Init] ✅✅✅ FCM УСПЕШНО ИНИЦИАЛИЗИРОВАН!');

            // Получаем токен
            print('[Init] 🔑 Получение FCM токена...');
            final fcmToken = await FCMService().getToken();

            print('[Init] ========================================');
            if (fcmToken != null && fcmToken.isNotEmpty) {
              print('[Init] ✅✅✅ FCM ТОКЕН ПОЛУЧЕН!');
              print(
                  '[Init] Token (первые 50 символов): ${fcmToken.substring(0, fcmToken.length > 50 ? 50 : fcmToken.length)}...');
              print('[Init] Token length: ${fcmToken.length}');

              // Регистрируем токен на бэкенде
              print('[Init] 📤 Регистрация токена на бэкенде...');
              await FCMService().refreshToken();
              print('[Init] ✅✅✅ ТОКЕН ЗАРЕГИСТРИРОВАН НА БЭКЕНДЕ!');
            } else {
              print('[Init] ❌❌❌ FCM ТОКЕН НЕ ПОЛУЧЕН!');
              print('[Init] Token value: $fcmToken');
            }
            print('[Init] ========================================');
          } catch (e, stackTrace) {
            print('[Init] ========================================');
            print('[Init] ❌❌❌ ОШИБКА ИНИЦИАЛИЗАЦИИ FCM');
            print('[Init] Ошибка: $e');
            print('[Init] Stack trace: $stackTrace');
            print('[Init] ========================================');
            // Продолжаем работу даже если FCM не работает
          }
        }

        print('[Init] 🔌 Инициализация WebRTC...');
        try {
          await WebRTCService.instance.initialize(
            authProvider.currentUser!.id.toString(),
          );
          print('[Init] ✅ WebRTC успешно инициализирован');

          if (mounted) {
            print('[Init] 📢 Вызываем _notifyWebRTCReady()');
            _notifyWebRTCReady();
          }
        } catch (e) {
          print('[Init] ⚠️ Ошибка инициализации WebRTC: $e');
        }

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

  void _notifyWebRTCReady() {
    final callOverlayState =
        context.findAncestorStateOfType<_CallOverlayWrapperState>();
    if (callOverlayState != null) {
      print('[Init] 📢 Уведомляем CallOverlay о готовности WebRTC');
      callOverlayState.onWebRTCReady();
    } else {
      print('[Init] ⚠️ CallOverlayWrapper не найден в дереве виджетов');
    }
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

    if (_inviteCode != null) {
      return InviteRegisterScreen(inviteCode: _inviteCode!);
    }

    return _isAuthenticated ? HomeScreen() : LoginScreen();
  }
}

// Виджет для отображения входящих звонков поверх всего приложения
class CallOverlayWrapper extends StatefulWidget {
  final Widget child;

  const CallOverlayWrapper({Key? key, required this.child}) : super(key: key);

  @override
  _CallOverlayWrapperState createState() => _CallOverlayWrapperState();

  static _CallOverlayWrapperState? of(BuildContext context) {
    return context.findAncestorStateOfType<_CallOverlayWrapperState>();
  }
}

class _CallOverlayWrapperState extends State<CallOverlayWrapper> {
  Call? _incomingCall;
  StreamSubscription<Call?>? _callSubscription;
  bool _isWebRTCReady = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();

    print('[CallOverlay] ========================================');
    print('[CallOverlay] initState - инициализация overlay');
    print('[CallOverlay] Платформа: ${kIsWeb ? "Web" : "Mobile"}');
    print('[CallOverlay] ========================================');

    // Подписываемся на FCM callback для мобильных платформ
    if (!kIsWeb) {
      // Задержка для инициализации FCM
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          _setupFCMCallback();
        }
      });
    }

    print('[CallOverlay] ⏳ Ожидаем инициализации WebRTC...');
  }

  // Настройка FCM callback
  void _setupFCMCallback() {
    print('[CallOverlay] ========================================');
    print('[CallOverlay] 📱 Настройка FCM callback для входящих звонков');
    print('[CallOverlay] ========================================');

    try {
      final fcmService = FCMService();

      // Устанавливаем callback для входящих звонков
      fcmService.onIncomingCall = (data) {
        print('[CallOverlay] ========================================');
        print('[CallOverlay] 🔔 FCM CALLBACK: Входящий звонок!');
        print('[CallOverlay] Данные: $data');
        print('[CallOverlay] ========================================');

        if (!mounted) {
          print('[CallOverlay] ⚠️ Widget не смонтирован, игнорируем');
          return;
        }

        // Извлекаем данные
        final callId = data['callId'];
        final chatId = data['chatId'] ?? 'unknown';
        final callerName = data['callerName'] ?? 'Unknown';
        final callType = data['callType'] ?? 'video';
        final callerAvatar = data['callerAvatar'];

        if (callId == null) {
          print('[CallOverlay] ❌ callId отсутствует в данных');
          return;
        }

        print('[CallOverlay] 📞 Создаем Call объект:');
        print('[CallOverlay]   - callId: $callId');
        print('[CallOverlay]   - chatId: $chatId');
        print('[CallOverlay]   - callerName: $callerName');
        print('[CallOverlay]   - callType: $callType');

        // Создаем Call объект из FCM данных
        final incomingCall = Call(
          id: callId,
          chatId: chatId,
          callerId: '',
          callerName: callerName,
          receiverId: '',
          receiverName: 'You',
          callType: callType,
          status: CallStatus.incoming,
          startTime: DateTime.now(),
        );

        print('[CallOverlay] ✅ Call объект создан, показываем overlay');

        // Показываем overlay
        _showIncomingCallOverlay(incomingCall);
      };

      print('[CallOverlay] ✅ FCM callback установлен');
    } catch (e) {
      print('[CallOverlay] ❌ Ошибка настройки FCM callback: $e');
    }
  }

  void onWebRTCReady() {
    print('[CallOverlay] ========================================');
    print('[CallOverlay] 🎉 WebRTC готов! Подписываемся на звонки');
    print('[CallOverlay] ========================================');

    if (!mounted) {
      print('[CallOverlay] ⚠️ Widget не смонтирован, отменяем подписку');
      return;
    }

    setState(() {
      _isWebRTCReady = true;
    });

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

        if (!mounted) return;

        if (call != null && call.status == CallStatus.incoming) {
          print(
              '[CallOverlay] ✅ ПОКАЗЫВАЕМ входящий звонок от ${call.callerName}');
          _showIncomingCallOverlay(call);
        } else if (call == null ||
            call.status == CallStatus.ended ||
            call.status == CallStatus.declined) {
          print('[CallOverlay] 🔴 Скрываем overlay (статус: ${call?.status})');
          _hideIncomingCallOverlay();
        }
      },
      onError: (error) {
        print('[CallOverlay] ❌ Ошибка в callState stream: $error');
      },
      cancelOnError: false,
    );

    print('[CallOverlay] ✅ Подписка на callState активирована');
  }

  void _showIncomingCallOverlay(Call call) {
    _overlayEntry?.remove();

    print('[CallOverlay] 🎨 Создаем OverlayEntry');

    final overlayContext = context;

    _overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: IncomingCallOverlay(
            incomingCall: call,
            onDismiss: () {
              print('[CallOverlay] onDismiss вызван');
              _hideIncomingCallOverlay();
            },
            onAccept: () async {
              print('[CallOverlay] ✅ onAccept - принимаем звонок');

              try {
                await WebRTCService.instance.answerCall(call.id);
                print('[CallOverlay] ✅ answerCall вызван');
              } catch (e) {
                print('[CallOverlay] ❌ Ошибка answerCall: $e');
              }

              _hideIncomingCallOverlay();

              Navigator.of(overlayContext).push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(initialCall: call),
                ),
              );

              print('[CallOverlay] ✅ CallScreen открыт');
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    print('[CallOverlay] ✅ OverlayEntry вставлен');
  }

  void _hideIncomingCallOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    print('[CallOverlay] dispose - отменяем подписку');

    if (!kIsWeb) {
      try {
        FCMService().onIncomingCall = null;
        print('[CallOverlay] ✅ FCM callback очищен');
      } catch (e) {
        print('[CallOverlay] ⚠️ Ошибка очистки FCM callback: $e');
      }
    }

    _hideIncomingCallOverlay();
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
