// lib/services/webrtc_service.dart
// ФИНАЛЬНАЯ ВЕРСИЯ с heartbeat и улучшенным логированием

import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call.dart';
import '../helpers/ios_audio_helper.dart';
import '../helpers/ios_callkit_helper.dart';
import '../helpers/ios_callkit_handler.dart';
import 'websocket_manager.dart';

class WebRTCService {
  static WebRTCService? _instance;
  static WebRTCService get instance {
    _instance ??= WebRTCService._internal();
    return _instance!;
  }

  WebRTCService._internal() {
    _initializeStreams();
  }

  static const platform = MethodChannel('com.securewave.app/call');
  static const audioChannel = MethodChannel('com.securewave.app/audio');

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentUserId;
  Call? _currentCall;
  Call? get currentCall => _currentCall;
  bool get isInitialized => _currentUserId != null;
  String? get userId => _currentUserId;

  Map<String, dynamic>? _pendingOffer;
  bool _isAnswering = false;
  
  // ⭐⭐⭐ НОВОЕ: Отслеживание уже обработанных call_offer для предотвращения дублирования
  final Set<String> _processedCallOffers = {};

  StreamController<Call?>? _callStateController;
  StreamController<MediaStream?>? _localStreamController;
  StreamController<MediaStream?>? _remoteStreamController;

  Stream<Call?> get callState =>
      _callStateController?.stream ?? const Stream.empty();
  Stream<MediaStream?> get localStream =>
      _localStreamController?.stream ?? const Stream.empty();
  Stream<MediaStream?> get remoteStream =>
      _remoteStreamController?.stream ?? const Stream.empty();

  StreamSubscription? _wsSubscription;
  Timer? _heartbeatTimer; // ⭐ НОВОЕ: Heartbeat timer
  Timer? _iceTimeoutTimer; // ⭐⭐⭐ НОВОЕ: Таймаут для ICE connection

  final List<RTCIceCandidate> _iceCandidatesQueue = [];
  bool _isRemoteDescriptionSet = false;

  Map<String, dynamic> get _iceServers {
    // Используем два сервера STUN/TURN:
    // 1) Новый сервер 85.198.75.33 (teta-instrument.ru) — ставим ПЕРВЫМ для приоритета
    // 2) Старый сервер 62.109.4.44 — как резервный
    // Это повышает надёжность и даёт возможность плавного переноса нагрузки.
    final stunPrimary = 'stun:85.198.75.33:3478';
    final turnPrimary = 'turn:85.198.75.33:3478';
    final stunBackup = 'stun:62.109.4.44:3478';
    final turnBackup = 'turn:62.109.4.44:3478';

    // ⭐⭐⭐ ИСПРАВЛЕНО: Для Web тоже используем TURN для надежного соединения
    if (kIsWeb) {
      return {
        'iceServers': [
          // STUN: сначала новый, затем резервный
          {'urls': stunPrimary},
          {'urls': stunBackup},
          // TURN: сначала новый, затем резервный (критично для Web!)
          {
            'urls': turnPrimary,
            'username': 'securewave',
            'credential': 'SecureWave2024!Turn'
          },
          {
            'urls': turnBackup,
            'username': 'securewave',
            'credential': 'SecureWave2024!Turn'
          },
        ]
      };
    } else {
      // Для мобильных устройств используем и STUN, и TURN для большей надежности
      return {
        'iceServers': [
          // STUN: сначала новый, затем резервный
          {'urls': stunPrimary},
          {'urls': stunBackup},
          // TURN: сначала новый, затем резервный
          {
            'urls': turnPrimary,
            'username': 'securewave',
            'credential': 'SecureWave2024!Turn'
          },
          {
            'urls': turnBackup,
            'username': 'securewave',
            'credential': 'SecureWave2024!Turn'
          },
        ]
      };
    }
  }

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  void _initializeStreams() {
    // print('[WebRTC] 🔄 Переинициализация stream controllers');
    _callStateController?.close();
    _localStreamController?.close();
    _remoteStreamController?.close();

    _callStateController = StreamController<Call?>.broadcast();
    _localStreamController = StreamController<MediaStream?>.broadcast();
    _remoteStreamController = StreamController<MediaStream?>.broadcast();
  }

  void _safeAddToCallState(Call? call) {
    if (_callStateController != null && !_callStateController!.isClosed) {
      _callStateController!.add(call);
    }
  }

  void _safeAddToLocalStream(MediaStream? stream) {
    if (_localStreamController != null && !_localStreamController!.isClosed) {
      _localStreamController!.add(stream);
    }
  }

  void _safeAddToRemoteStream(MediaStream? stream) {
    if (_remoteStreamController != null && !_remoteStreamController!.isClosed) {
      _remoteStreamController!.add(stream);
    }
  }

  // ⭐⭐⭐ НОВОЕ: Обработчик событий от Android ConnectionService
  void _setupAndroidCallHandler() {
    // ⭐⭐⭐ На Web Platform.isAndroid недоступен, поэтому сначала проверяем kIsWeb
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    
    // print('[WebRTC] ========================================');
    // print('[WebRTC] 📱 Настройка обработчика Android ConnectionService');
    // print('[WebRTC] ========================================');
    
    platform.setMethodCallHandler((call) async {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 📥 Событие от Android ConnectionService: ${call.method}');
      // print('[WebRTC] Arguments: ${call.arguments}');
      // print('[WebRTC] ========================================');
      
      switch (call.method) {
        case 'callAccepted':
          final data = Map<String, dynamic>.from(call.arguments ?? {});
          final callId = data['callId'] as String?;
          final callerName = data['callerName'] as String?;
          
          // print('[WebRTC] ========================================');
          // print('[WebRTC] ✅ Пользователь ПРИНЯЛ звонок через ConnectionService');
          // print('[WebRTC] Call ID: $callId');
          // print('[WebRTC] Caller: $callerName');
          // print('[WebRTC] ========================================');
          
          if (callId != null) {
            // Принимаем звонок через WebRTC
            try {
              await answerCall(callId);
              // print('[WebRTC] ✅ Звонок принят через WebRTC');
            } catch (e) {
              // print('[WebRTC] ❌ Ошибка принятия звонка: $e');
            }
          }
          break;
          
        case 'callDeclined':
          final data = Map<String, dynamic>.from(call.arguments ?? {});
          final callId = data['callId'] as String?;
          
          // print('[WebRTC] ========================================');
          // print('[WebRTC] ❌ Пользователь ОТКЛОНИЛ звонок через ConnectionService');
          // print('[WebRTC] Call ID: $callId');
          // print('[WebRTC] ========================================');
          
          if (callId != null) {
            try {
              WebSocketManager.instance.declineCall(callId);
              // print('[WebRTC] ✅ Decline отправлен на сервер');
            } catch (e) {
              // print('[WebRTC] ❌ Ошибка отправки decline: $e');
            }
          }
          break;
          
        case 'callEnded':
          final data = Map<String, dynamic>.from(call.arguments ?? {});
          final callId = data['callId'] as String?;
          
          // print('[WebRTC] ========================================');
          // print('[WebRTC] 🔴 Пользователь ЗАВЕРШИЛ звонок через ConnectionService');
          // print('[WebRTC] Call ID: $callId');
          // print('[WebRTC] ========================================');
          
          if (callId != null && _currentCall?.id == callId) {
            try {
              await endCall('user_ended');
              // print('[WebRTC] ✅ Звонок завершен');
            } catch (e) {
              // print('[WebRTC] ❌ Ошибка завершения звонка: $e');
            }
          }
          break;
          
        default:
          // print('[WebRTC] ⚠️ Неизвестное событие: ${call.method}');
      }
    });
    
    // print('[WebRTC] ✅ Обработчик Android ConnectionService настроен');
    // print('[WebRTC] ========================================');
  }

  Future<void> initialize(String userId) async {
    try {
      _currentUserId = userId;
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🚀 ИНИЦИАЛИЗАЦИЯ WebRTC Service');
      // print('[WebRTC] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      // print('[WebRTC] User ID: $userId');
      // print('[WebRTC] ========================================');

      if (_callStateController == null || _callStateController!.isClosed) {
        _initializeStreams();
      }

      _wsSubscription?.cancel();
      _wsSubscription = WebSocketManager.instance.messages.listen(
        _handleWebSocketMessage,
        onError: (error) {
          // print('[WebRTC] ❌ WebSocket error: $error');
        },
        cancelOnError: false,
      );

      // ⭐⭐⭐ КРИТИЧНО: Сохраняем userId в UserDefaults для проверки callerId в AppDelegate
      if (!kIsWeb && Platform.isIOS) {
        try {
          await platform.invokeMethod('saveUserId', userId);
          // print('[WebRTC] ✅ UserId сохранен в UserDefaults: $userId');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка сохранения userId в UserDefaults: $e');
        }
      }

      // ⭐⭐⭐ НОВОЕ: Настраиваем обработчик событий от Android ConnectionService
      _setupAndroidCallHandler();

      // print('[WebRTC] ✅ Сервис инициализирован');
      // print('[WebRTC] ========================================');
    } catch (e, stackTrace) {
      // print('[WebRTC] ❌ Ошибка инициализации: $e');
      // print('[WebRTC] Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];
    // print('[WebRTC] ========================================');
    // print('[WebRTC] 📨 WebSocket message получен!');
    // print('[WebRTC] Type: $type');
    // print('[WebRTC] Message keys: ${message.keys}');
    // print('[WebRTC] ========================================');

    switch (type) {
      case 'call_offer':
        _handleIncomingCall(message);
        break;
      case 'call_answer':
        _handleCallAnswer(message);
        break;
      case 'call_ice_candidate':
        _handleIceCandidate(message);
        break;
      case 'call_ended':
        _handleCallEnded(message);
        break;
      case 'call_declined':
        _handleCallDeclined(message);
        break;
      case 'call_connected':
        _handleCallConnected(message);
        break;
      case 'user_offline':
        _handleUserOffline(message);
        break;
    }
  }

  void _handleCallConnected(Map<String, dynamic> message) {
    // print('[WebRTC] ========================================');
    // print('[WebRTC] ✅✅✅ CALL_CONNECTED получен от сервера');
    // print('[WebRTC] Call ID: ${message['callId']}');
    // print('[WebRTC] Timestamp: ${message['timestamp']}');
    // print('[WebRTC] ========================================');
    
    // Обновляем статус звонка если он еще не active
    if (_currentCall != null && 
        _currentCall!.id == message['callId'] &&
        _currentCall!.status != CallStatus.active) {
      _currentCall = _currentCall!.copyWith(status: CallStatus.active);
      _safeAddToCallState(_currentCall);
      // print('[WebRTC] ✅ Статус звонка обновлен на active');
    }
  }

  // ⭐⭐⭐ НОВОЕ: Запуск heartbeat
  void _startHeartbeat() {
    // print('[WebRTC] ========================================');
    // print('[WebRTC] 💓 Запуск heartbeat');
    // print('[WebRTC] ========================================');

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_currentCall != null && _currentCall!.status == CallStatus.active) {
        try {
          WebSocketManager.instance.send({
            'type': 'call_heartbeat',
            'callId': _currentCall!.id,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          // print('[WebRTC] 💓 Heartbeat отправлен: ${_currentCall!.id}');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка отправки heartbeat: $e');
        }
      }
    });

    // print('[WebRTC] ✅ Heartbeat запущен');
  }

  void _stopHeartbeat() {
    // print('[WebRTC] 💔 Остановка heartbeat');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ⭐⭐⭐ НОВОЕ: Уведомление backend о соединении
  bool _hasNotifiedConnection = false; // ⭐⭐⭐ Защита от дублирования
  
  void _notifyConnectionEstablished() {
    try {
      // ⭐⭐⭐ КРИТИЧНО: Защита от дублирования call_connected
      if (_hasNotifiedConnection) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] ⚠️ call_connected уже был отправлен, пропускаем');
        // print('[WebRTC] ========================================');
        return;
      }

      // print('[WebRTC] ========================================');
      // print('[WebRTC] 📤 Уведомляем backend о соединении');
      // print('[WebRTC] ========================================');

      if (_currentCall == null) return;

      WebSocketManager.instance.send({
        'type': 'call_connected',
        'callId': _currentCall!.id,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      _hasNotifiedConnection = true; // ⭐⭐⭐ Помечаем как отправленное
      // print('[WebRTC] ✅ Уведомление отправлено');
    } catch (e) {
      // print('[WebRTC] ⚠️ Ошибка уведомления: $e');
    }
  }

  Future<void> startCall({
    required String callId,
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String callType,
  }) async {
    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 📞 НАЧИНАЕМ ИСХОДЯЩИЙ ЗВОНОК');
      // print('[WebRTC] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      // print('[WebRTC] ========================================');

      // ⭐⭐⭐ КРИТИЧНО: Проверяем что WebRTC сервис инициализирован
      if (_currentUserId == null) {
        // print('[WebRTC] ❌❌❌ ОШИБКА: WebRTC сервис не инициализирован!');
        // print('[WebRTC] _currentUserId = null');
        // print(           // '[WebRTC] Необходимо вызвать WebRTCService.initialize() перед startCall()');
        throw Exception(
            'WebRTC service not initialized. Call initialize() first.');
      }

      _currentCall = Call(
        id: callId,
        chatId: chatId,
        callerId: _currentUserId!,
        callerName: 'Вы',
        receiverId: receiverId,
        receiverName: receiverName,
        callType: callType,
        status: CallStatus.calling,
        startTime: DateTime.now(),
      );

      _safeAddToCallState(_currentCall);

      await _configureAudioForCall(callType);
      await _initializeMediaStreams(callType == 'video');
      await _createPeerConnection();

      final offer = await _peerConnection!.createOffer(_constraints);
      await _peerConnection!.setLocalDescription(offer);

      // print('[WebRTC] 📤 Отправляем offer');
      WebSocketManager.instance.sendCallOffer(
        callId,
        chatId,
        callType,
        offer.toMap(),
        receiverId,
      );

      // print('[WebRTC] ✅ Offer отправлен');
    } catch (e, stackTrace) {
      // print('[WebRTC] ❌ Ошибка: $e');
      // print('[WebRTC] Stack: $stackTrace');
      await endCall('error');
      rethrow;
    }
  }

  Future<void> _configureAudioForCall(String callType) async {
    if (kIsWeb) return;

    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🔊 Настройка Android AudioManager');
      // print('[WebRTC] Call type: $callType');
      // print('[WebRTC] ========================================');

      if (callType == 'video') {
        await audioChannel.invokeMethod('setAudioModeForVideoCall');
        await Helper.setSpeakerphoneOn(true);
        // print('[WebRTC] ✅ Режим: VIDEO (speaker ON)');
      } else {
        await audioChannel.invokeMethod('setAudioModeForVoiceCall');
        await Helper.setSpeakerphoneOn(false);
        // print('[WebRTC] ✅ Режим: VOICE (earpiece)');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      await audioChannel.invokeMethod('logAudioState');

      // print('[WebRTC] ========================================');
    } catch (e) {
      // print('[WebRTC] ⚠️ Ошибка настройки аудио: $e');
    }
  }

  Future<void> _initializeMediaStreams(bool video) async {
    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🎥 Инициализация медиа (видео: $video)');
      // print('[WebRTC] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      // print('[WebRTC] ========================================');

      Map<String, dynamic> mediaConstraints;

      if (kIsWeb) {
        mediaConstraints = {
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': video
              ? {
                  'width': {'ideal': 640},
                  'height': {'ideal': 480},
                  'frameRate': {'ideal': 30},
                  'facingMode': 'user',
                }
              : false,
        };
      } else {
        mediaConstraints = {
          'audio': true,
          'video': video
              ? {
                  'mandatory': {
                    'minWidth': '640',
                    'minHeight': '480',
                    'minFrameRate': '30',
                  },
                  'facingMode': 'user',
                }
              : false,
        };
      }

      // print('[WebRTC] 📋 Media constraints:');
      // print('[WebRTC] ${mediaConstraints.toString()}');

      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);

      // print('[WebRTC] ========================================');
      // print('[WebRTC] ✅ Локальный stream создан');
      // print('[WebRTC] Stream ID: ${_localStream!.id}');
      // print('[WebRTC] Аудио треков: ${_localStream!.getAudioTracks().length}');
      // print('[WebRTC] Видео треков: ${_localStream!.getVideoTracks().length}');

      for (var track in _localStream!.getAudioTracks()) {
        // print('[WebRTC] ----------------------------------------');
        // print('[WebRTC] 🔊 Audio Track:');
        // print('[WebRTC]   ID: ${track.id}');
        // print('[WebRTC]   Label: ${track.label}');
        // print('[WebRTC]   Enabled: ${track.enabled}');
        // print('[WebRTC]   Muted: ${track.muted ?? false}');
        // print('[WebRTC]   Kind: ${track.kind}');

        if (!track.enabled) {
          // print('[WebRTC]   ⚠️⚠️⚠️ TRACK DISABLED! Включаем...');
          track.enabled = true;
        }
      }

      // print('[WebRTC] ========================================');

      _safeAddToLocalStream(_localStream);
    } catch (e, stackTrace) {
      // print('[WebRTC] ❌ Ошибка получения медиа: $e');
      // print('[WebRTC] Stack: $stackTrace');
      rethrow;
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🔗 Создание peer connection');
      // print('[WebRTC] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      // print('[WebRTC] ========================================');

      final config = _iceServers;

      if (kIsWeb) {
        config['sdpSemantics'] = 'unified-plan';
        config['iceTransportPolicy'] = 'all';
      }

      // print('[WebRTC] Config: $config');

      _peerConnection = await createPeerConnection(config);

      if (_localStream != null) {
        // print('[WebRTC] 📤 Добавляем локальные треки:');

        for (var track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
          // print('[WebRTC]   ✅ Трек добавлен: ${track.kind} (${track.id})');
          // print('[WebRTC]      Enabled: ${track.enabled}');
          // print('[WebRTC]      Muted: ${track.muted}');
        }
      }

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] 🎯 onTrack TRIGGERED!');
        // print('[WebRTC] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
        // print('[WebRTC] Time: ${DateTime.now()}');
        // print('[WebRTC] ========================================');
        // print('[WebRTC] Track kind: ${event.track.kind}');
        // print('[WebRTC] Track ID: ${event.track.id}');
        // print('[WebRTC] Track enabled: ${event.track.enabled}');
        // print('[WebRTC] Track muted: ${event.track.muted}');
        // print('[WebRTC] Streams count: ${event.streams.length}');

        if (event.streams.isNotEmpty) {
          final stream = event.streams.first;

          // print('[WebRTC] ----------------------------------------');
          // print('[WebRTC] 🌊 Stream received:');
          // print('[WebRTC]   ID: ${stream.id}');
          // print('[WebRTC]   Audio: ${stream.getAudioTracks().length}');
          // print('[WebRTC]   Video: ${stream.getVideoTracks().length}');

          for (var i = 0; i < stream.getAudioTracks().length; i++) {
            final audioTrack = stream.getAudioTracks()[i];
            // print('[WebRTC] ----------------------------------------');
            // print('[WebRTC] 🔊 Audio Track #$i:');
            // print('[WebRTC]   ID: ${audioTrack.id}');
            // print('[WebRTC]   Label: ${audioTrack.label}');
            // print('[WebRTC]   Enabled: ${audioTrack.enabled}');
            // print('[WebRTC]   Muted: ${audioTrack.muted ?? false}');

            if (!audioTrack.enabled) {
              // print('[WebRTC]   ⚠️ ENABLING DISABLED TRACK!');
              audioTrack.enabled = true;
            }

            if (audioTrack.muted == true) {
              // print('[WebRTC]   ⚠️ TRACK IS MUTED!');
              // print('[WebRTC]   ⚠️ Это может быть временное состояние - трек должен размутиться автоматически');
              // print('[WebRTC]   ⚠️ Если трек остается muted, проверьте настройки на стороне отправителя');
            }
          }

          // ⭐⭐⭐ НОВОЕ: Обработка video tracks
          for (var i = 0; i < stream.getVideoTracks().length; i++) {
            final videoTrack = stream.getVideoTracks()[i];
            // print('[WebRTC] ----------------------------------------');
            // print('[WebRTC] 🎥 Video Track #$i:');
            // print('[WebRTC]   ID: ${videoTrack.id}');
            // print('[WebRTC]   Label: ${videoTrack.label}');
            // print('[WebRTC]   Enabled: ${videoTrack.enabled}');
            // print('[WebRTC]   Muted: ${videoTrack.muted ?? false}');

            if (!videoTrack.enabled) {
              // print('[WebRTC]   ⚠️ ENABLING DISABLED VIDEO TRACK!');
              videoTrack.enabled = true;
            }

            if (videoTrack.muted == true) {
              // print('[WebRTC]   ⚠️ VIDEO TRACK IS MUTED!');
              // print('[WebRTC]   ⚠️ Это может быть временное состояние - трек должен размутиться автоматически');
              // print('[WebRTC]   ⚠️ Если трек остается muted, проверьте настройки на стороне отправителя');
            }
          }

          if (stream.getAudioTracks().isEmpty) {
            // print('[WebRTC] ========================================');
            // print('[WebRTC] ❌❌❌ НЕТ АУДИО ТРЕКОВ!');
            // print('[WebRTC] ========================================');
          } else {
            // print('[WebRTC] ========================================');
            // print('[WebRTC] ✅ Устанавливаем remote stream');
            // print('[WebRTC] ========================================');

            _remoteStream = stream;
            _safeAddToRemoteStream(_remoteStream);

            // ⭐⭐⭐ ВАЖНО: Треки автоматически размучиваются когда ICE соединение устанавливается
            // Если треки остаются muted, это означает что ICE соединение не установлено
            // Проверяем состояние треков периодически
            if (kIsWeb) {
              // print('[WebRTC] 🌐 Web platform - checking audio context');
              _ensureAudioPlayback(stream);
              
              // ⭐⭐⭐ НОВОЕ: Периодическая проверка состояния треков (для диагностики)
              Timer.periodic(const Duration(seconds: 2), (timer) {
                if (_remoteStream == null || _currentCall == null) {
                  timer.cancel();
                  return;
                }
                
                bool allUnmuted = true;
                for (var track in _remoteStream!.getTracks()) {
                  if (track.muted == true) {
                    allUnmuted = false;
                    // print('[WebRTC] ⚠️ Трек ${track.id} (${track.kind}) все еще muted');
                  }
                }
                
                if (allUnmuted && _remoteStream!.getTracks().isNotEmpty) {
                  // print('[WebRTC] ✅ Все треки размучены!');
                  timer.cancel();
                }
              });
            }
          }
        } else {
          // print('[WebRTC] ⚠️ No streams in event!');
        }

        // print('[WebRTC] ========================================');
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] 🧊 New ICE candidate');
        // print('[WebRTC] Type: ${candidate.candidate}');
        // print('[WebRTC] sdpMid: ${candidate.sdpMid}');
        // print('[WebRTC] sdpMLineIndex: ${candidate.sdpMLineIndex}');
        // print('[WebRTC] ========================================');
        if (_currentCall != null) {
          final wsManager = WebSocketManager.instance;
          final isWSConnected = wsManager.isConnected;
          // print('[WebRTC] WebSocket подключен: $isWSConnected');
          
          if (isWSConnected) {
            wsManager.sendIceCandidate(
              _currentCall!.id,
              candidate.toMap(),
            );
            // print('[WebRTC] ✅ ICE candidate sent via WebSocket');
          } else {
            // print('[WebRTC] ⚠️ WebSocket не подключен, ICE candidate будет добавлен в очередь WebSocket');
            // WebSocketManager.send() автоматически добавит в очередь
            wsManager.sendIceCandidate(
              _currentCall!.id,
              candidate.toMap(),
            );
            // print('[WebRTC] ⚠️ ICE candidate добавлен в очередь WebSocket (будет отправлен при подключении)');
          }
        } else {
          // print('[WebRTC] ❌ Нет текущего звонка, ICE candidate не отправлен');
        }
      };

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] 🎯 ICE Gathering State: $state');
        // print('[WebRTC] Time: ${DateTime.now()}');
        // print('[WebRTC] ========================================');
      };

      // ⭐⭐⭐ УЛУЧШЕННЫЙ onIceConnectionState
      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] 🧊 ICE State: $state');
        // print('[WebRTC] Time: ${DateTime.now()}');
        // print('[WebRTC] Call ID: ${_currentCall?.id}');
        // print('[WebRTC] ========================================');

        // ⭐⭐⭐ НОВОЕ: Управление таймаутом ICE
        _iceTimeoutTimer?.cancel();
        _iceTimeoutTimer = null;

        if (state == RTCIceConnectionState.RTCIceConnectionStateChecking) {
          // ⭐⭐⭐ НОВОЕ: Запускаем таймаут для Checking (30 секунд)
          // print('[WebRTC] ⏱️ Запускаем таймаут ICE connection (30 сек)');
          _iceTimeoutTimer = Timer(const Duration(seconds: 30), () {
            if (_peerConnection?.iceConnectionState == 
                RTCIceConnectionState.RTCIceConnectionStateChecking) {
              // print('[WebRTC] ========================================');
              // print('[WebRTC] ⏱️⏱️⏱️ ICE TIMEOUT!');
              // print('[WebRTC] Соединение застряло в Checking более 30 секунд');
              // print('[WebRTC] Call ID: ${_currentCall?.id}');
              // print('[WebRTC] ========================================');
              
              if (!_isEndingCall) {
                endCall('ice_timeout');
              }
            }
          });
        }

        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          // print('[WebRTC] ========================================');
          // print('[WebRTC] ✅✅✅ ICE CONNECTED!');
          final icePlatform = kIsWeb
              ? 'WEB'
              : (Platform.isAndroid
                  ? 'Android'
                  : (Platform.isIOS ? 'iOS' : 'Other'));
          // print('[WebRTC] Platform: $icePlatform');
          // print('[WebRTC] Call ID: ${_currentCall?.id}');
          // print('[WebRTC] Call Status: ${_currentCall?.status}');
          // print('[WebRTC] ICE State: $state');
          // print('[WebRTC] Connection State: ${_peerConnection?.connectionState}');
          // print('[WebRTC] Signaling State: ${_peerConnection?.signalingState}');
          // print('[WebRTC] ========================================');

          if (_remoteStream != null) {
            // print('[WebRTC] 🔊 Обеспечиваем воспроизведение аудио из remote stream');
            _ensureAudioPlayback(_remoteStream!);
          } else {
            // print('[WebRTC] ⚠️ Remote stream is null');
          }

          // ⭐⭐⭐ КРИТИЧНО ДЛЯ ANDROID: Дополнительная настройка аудио при ICE connected
          if (!kIsWeb && Platform.isAndroid && _currentCall != null) {
            // print('[WebRTC] 🔊 Дополнительная настройка аудио для Android при ICE connected...');
            Future.delayed(const Duration(milliseconds: 200), () async {
              try {
                await _configureAudioForCall(_currentCall!.callType);
                // print('[WebRTC] ✅ Аудио для Android настроено при ICE connected');
              } catch (e) {
                // print('[WebRTC] ⚠️ Ошибка настройки аудио для Android: $e');
              }
            });
          }

          // ⭐ Уведомляем backend
          if (_currentCall != null) {
            // print('[WebRTC] 📤 Уведомляем backend о соединении...');
            _notifyConnectionEstablished();
          } else {
            // print('[WebRTC] ⚠️ _currentCall is null, не можем уведомить backend');
          }
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          // ⭐⭐⭐ КРИТИЧНО: Игнорируем ice_failed если звонок уже завершается
          if (_isEndingCall) {
            // print('[WebRTC] ⚠️ Звонок уже завершается, игнорируем ice_failed');
            return;
          }
          // print('[WebRTC] ❌ ICE FAILED!');
          endCall('ice_failed');
        } else if (state ==
            RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          // print('[WebRTC] ⚠️ ICE DISCONNECTED!');
          
          // ⭐⭐⭐ КРИТИЧНО: Игнорируем ice_disconnected если звонок уже завершается
          if (_isEndingCall) {
            // print('[WebRTC] ⚠️ Звонок уже завершается, игнорируем ice_disconnected');
            // print('[WebRTC] Это нормально - соединение закрывается после завершения звонка');
            return;
          }
          
          // print('[WebRTC] ⏳ Даём время на восстановление ICE (10 секунд)...');
          // ⭐⭐⭐ УВЕЛИЧЕН ТАЙМАУТ: с 5 до 10 секунд для лучшего восстановления
          Future.delayed(const Duration(seconds: 10), () {
            // ⭐⭐⭐ КРИТИЧНО: Проверяем еще раз, не завершается ли звонок
            if (_isEndingCall) {
              // print('[WebRTC] ⚠️ Звонок уже завершается, игнорируем ice_disconnected');
              return;
            }
            
            if (_peerConnection?.iceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
              // print('[WebRTC] ❌ ICE не восстановился за 10 секунд');
              endCall('ice_disconnected');
            } else {
              // print('[WebRTC] ✅ ICE соединение восстановилось!');
            }
          });
        }
      };

      // ⭐⭐⭐ УЛУЧШЕННЫЙ onConnectionState
      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] 🔌 Connection State: $state');
        // print('[WebRTC] Time: ${DateTime.now()}');
        // print('[WebRTC] Call ID: ${_currentCall?.id}');
        // print('[WebRTC] ========================================');

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          // print('[WebRTC] ========================================');
          // print('[WebRTC] ✅✅✅ PEER CONNECTED!');
          final peerPlatform = kIsWeb
              ? 'WEB'
              : (Platform.isAndroid
                  ? 'Android'
                  : (Platform.isIOS ? 'iOS' : 'Other'));
          // print('[WebRTC] Platform: $peerPlatform');
          // print('[WebRTC] Call ID: ${_currentCall?.id}');
          // print('[WebRTC] Call Status: ${_currentCall?.status}');
          // print('[WebRTC] Connection State: $state');
          // print('[WebRTC] ICE State: ${_peerConnection?.iceConnectionState}');
          // print('[WebRTC] Signaling State: ${_peerConnection?.signalingState}');
          // print('[WebRTC] ========================================');

          if (_currentCall != null &&
              _currentCall!.status != CallStatus.active) {
            // print('[WebRTC] 📝 Обновляем статус звонка на active');
            _currentCall = _currentCall!.copyWith(status: CallStatus.active);
            _safeAddToCallState(_currentCall);
            // print('[WebRTC] ✅ Статус обновлен на active');

            // ⭐ КРИТИЧНО: Запускаем heartbeat
            // print('[WebRTC] 💓 Запускаем heartbeat');
            _startHeartbeat();

            // ⭐ Уведомляем backend
            // print('[WebRTC] 📤 Уведомляем backend о соединении...');
            _notifyConnectionEstablished();

            // ⭐⭐⭐ КРИТИЧНО: Активируем аудио сессию для iOS при установке соединения
            // Это важно для второго и последующих звонков, когда сессия была деактивирована
            // ⭐⭐⭐ ИСПРАВЛЕНО: Активируем немедленно, без задержки, для обеспечения звука
            if (!kIsWeb && Platform.isIOS) {
              // Вызываем асинхронно, так как callback не может быть async
              // ⭐⭐⭐ УБРАНА ЗАДЕРЖКА: Активируем сразу для обеспечения звука
              Future.microtask(() async {
                try {
                  // print('[WebRTC] 🔊 Активируем аудио сессию для iOS (немедленно)...');
                  await IOSAudioHelper.configureAudioSession();
                  // print('[WebRTC] ✅ Аудио сессия активирована');
                } catch (e) {
                  // print('[WebRTC] ⚠️ Ошибка активации аудио сессии: $e');
                  // Не критично - продолжаем работу
                }
              });
            }

            // ⭐ Уведомляем CallKit (iOS)
            // ⭐⭐⭐ ИСПРАВЛЕНО: НЕ вызываем reportCallConnected() для входящих звонков
            // CallKit автоматически обновит UI когда соединение установится
            // reportCallConnected() использует reportOutgoingCall что неправильно для входящих
            if (!kIsWeb && Platform.isIOS) {
              try {
                // ⭐ Для входящих звонков CallKit уже знает о соединении через CXAnswerCallAction
                // Дополнительные уведомления не требуются
                // print('[WebRTC] ✅ CallKit будет автоматически обновлен iOS системой');
              } catch (e) {
                // print('[WebRTC] ⚠️ Ошибка CallKit: $e');
              }
            }
          }
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          // ⭐⭐⭐ КРИТИЧНО: Игнорируем connection_failed если звонок уже завершается
          if (_isEndingCall) {
            // print('[WebRTC] ⚠️ Звонок уже завершается, игнорируем connection_failed');
            return;
          }
          // print('[WebRTC] ❌ Connection FAILED!');
          endCall('connection_failed');
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          // ⭐⭐⭐ КРИТИЧНО: Игнорируем connection_disconnected если звонок уже завершается
          if (_isEndingCall) {
            // print('[WebRTC] ⚠️ Звонок уже завершается, игнорируем connection_disconnected');
            return;
          }
          // print('[WebRTC] ⚠️ Connection DISCONNECTED!');
          // print('[WebRTC] ⏳ Даём время на восстановление (15 секунд)...');
          // ⭐⭐⭐ УВЕЛИЧЕН ТАЙМАУТ: с 3 до 15 секунд для лучшего восстановления
          Future.delayed(const Duration(seconds: 15), () {
            // ⭐⭐⭐ КРИТИЧНО: Проверяем еще раз, не завершается ли звонок
            if (_isEndingCall) {
              // print('[WebRTC] ⚠️ Звонок уже завершается, игнорируем connection_disconnected');
              return;
            }
            if (_peerConnection?.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
              // print('[WebRTC] ❌ Соединение не восстановилось за 15 секунд');
              endCall('connection_lost');
            } else {
              // print('[WebRTC] ✅ Соединение восстановилось!');
            }
          });
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          // ⭐⭐⭐ КРИТИЧНО: Игнорируем connection_closed если звонок уже завершается
          if (_isEndingCall) {
            // print('[WebRTC] ⚠️ Звонок уже завершается, игнорируем connection_closed');
            // print('[WebRTC] Это нормально - соединение закрывается после завершения звонка');
            return;
          }
          // print('[WebRTC] 🔴 Connection CLOSED!');
          endCall('connection_closed');
        }
      };

      // print('[WebRTC] ✅ Peer connection создан');
      // print('[WebRTC] ========================================');

      // ⭐⭐⭐ КРИТИЧНО для iOS: Настраиваем AVAudioSession ПОСЛЕ создания PeerConnection
      // Аналогично Android где мы настраиваем AudioManager после PeerConnection
      if (!kIsWeb && Platform.isIOS) {
        await IOSAudioHelper.configureAudioSession();
      }
    } catch (e, stackTrace) {
      // print('[WebRTC] ❌ Ошибка создания peer connection: $e');
      // print('[WebRTC] Stack: $stackTrace');
      rethrow;
    }
  }

  void _ensureAudioPlayback(MediaStream stream) {
    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🔊 Обеспечиваем воспроизведение аудио');
      // print('[WebRTC] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      // print('[WebRTC] ========================================');

      final audioTracks = stream.getAudioTracks();
      if (audioTracks.isEmpty) {
        // print('[WebRTC] ⚠️ Нет аудио треков');
        return;
      }

      for (var track in audioTracks) {
        // print('[WebRTC] 🔊 Audio track: ${track.id}');
        // print('[WebRTC]   Enabled: ${track.enabled}');
        // print('[WebRTC]   Muted: ${track.muted ?? false}');

        if (!track.enabled) {
          // print('[WebRTC]   ⚠️ Включаем disabled трек');
          track.enabled = true;
        }
      }

      // print('[WebRTC] ✅ Аудио готово к воспроизведению');
      // print('[WebRTC] ========================================');
    } catch (e) {
      // print('[WebRTC] ⚠️ Ошибка: $e');
    }
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> message) async {
    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 📞 ВХОДЯЩИЙ ЗВОНОК');
      // print('[WebRTC] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      // print('[WebRTC] ========================================');

      final callId = message['callId'] as String?;
      final chatId = message['chatId'] as String?;
      final callerId = message['callerId'] as String?;
      final callerName = message['callerName'] as String?;
      final callerAvatar = message['callerAvatar'] as String?;
      final callType = message['callType'] as String?;
      final offer = message['offer'] as Map<String, dynamic>?;
      final isPending = message['isPending'] == true;

      if (callId == null ||
          chatId == null ||
          callerId == null ||
          offer == null) {
        // print('[WebRTC] ❌ Недостаточно данных');
        return;
      }
      
      // ⭐⭐⭐ НОВОЕ: Проверка на дублирование call_offer
      if (_processedCallOffers.contains(callId)) {
        // print('[WebRTC] ⚠️⚠️⚠️ ДУБЛИРУЮЩИЙСЯ call_offer обнаружен!');
        // print('[WebRTC] Call ID: $callId');
        // print('[WebRTC] ⚠️ Пропускаем обработку - этот call_offer уже был обработан');
        // print('[WebRTC] ========================================');
        return;
      }
      
      // ⭐⭐⭐ Добавляем callId в Set обработанных
      _processedCallOffers.add(callId);
      // print('[WebRTC] ✅ Call_offer добавлен в Set обработанных: $callId');

      _pendingOffer = offer;
      // print('[WebRTC] ✅ Offer сохранен');
      // print('[WebRTC] ⏰ Время сохранения offer: ${DateTime.now()}');

      _currentCall = Call(
        id: callId,
        chatId: chatId,
        callerId: callerId,
        callerName: callerName ?? 'Неизвестный',
        callerAvatar: callerAvatar,
        receiverId: _currentUserId!,
        receiverName: 'Вы',
        callType: callType ?? 'audio',
        status: CallStatus.incoming,
        startTime: DateTime.now(),
      );
      
      // print('[WebRTC] ✅ _currentCall создан');
      // print('[WebRTC] Call ID: ${_currentCall!.id}');
      // print('[WebRTC] Call Status: ${_currentCall!.status}');

      if (isPending) {
        // print('[WebRTC] 🎯 PENDING звонок - автоответ');
        await Future.delayed(const Duration(milliseconds: 300));
        await answerCall(callId);
      } else {
        // print('[WebRTC] 📱 Обычный звонок - показываем UI');

        // ⭐⭐⭐ КРИТИЧНО: Проверяем, был ли CallKit уже показан через VoIP push/FCM
        // Если CallKit уже был показан через push уведомление, не показываем его повторно
        // print('[WebRTC] ========================================');
        // print('[WebRTC] 🔍 Проверка: нужно ли показывать CallKit?');
        // print('[WebRTC] Call ID: $callId');
        final callKitPlatform = kIsWeb
            ? 'WEB'
            : (Platform.isIOS ? 'iOS' : 'Other');
        // print('[WebRTC] Platform: $callKitPlatform');
        // print('[WebRTC] ========================================');
        
        bool callKitAlreadyShown = false;
        if (!kIsWeb && Platform.isIOS) {
          try {
            // ⭐⭐⭐ Импортируем IOSCallKitHandler для проверки
            final iosCallKitHandler = IOSCallKitHandler();
            // print('[WebRTC] 🔍 Вызываем wasCallKitShownForCall($callId)...');
            callKitAlreadyShown = iosCallKitHandler.wasCallKitShownForCall(callId);
            // print('[WebRTC] ✅ Результат проверки: $callKitAlreadyShown');
            
            // ⭐⭐⭐ ИСПРАВЛЕНО: НЕ очищаем pending VoIP данные здесь
            // Теперь используется Set _callKitShownCallIds для отслеживания показанных CallKit
            // Очистка происходит только при завершении звонка
          } catch (e, stackTrace) {
            // print('[WebRTC] ⚠️ Ошибка проверки CallKit: $e');
            // print('[WebRTC] Stack: $stackTrace');
          }
        }
        
        // print('[WebRTC] ========================================');
        
        // ⭐⭐⭐ НОВОЕ: Проверяем статус звонка - если уже не incoming, не показываем CallKit
        final currentCallStatus = _currentCall?.status;
        final isCallAlreadyAccepted = currentCallStatus != null && 
            currentCallStatus != CallStatus.incoming;
        
        if (isCallAlreadyAccepted) {
          // print('[WebRTC] ⚠️⚠️⚠️ Звонок УЖЕ принят или обрабатывается!');
          // print('[WebRTC] Текущий статус: $currentCallStatus');
          // print('[WebRTC] Call ID: $callId');
          // print('[WebRTC] ⚠️ Пропускаем показ CallKit - звонок уже не incoming');
          callKitAlreadyShown = true; // Помечаем как уже показанный
        }
        
        if (callKitAlreadyShown) {
          // print('[WebRTC] ⚠️ CallKit уже был показан через VoIP push/FCM');
          // print('[WebRTC] ⚠️ Пропускаем повторный показ CallKit');
          // print('[WebRTC] ✅ Но все равно открываем CallScreen через callState');
        } else {
          // print('[WebRTC] ℹ️ CallKit/ConnectionService еще не был показан');
          // ⭐⭐⭐ Показываем CallKit UI на iOS или ConnectionService на Android
          if (!kIsWeb && Platform.isIOS) {
            try {
              // ⭐⭐⭐ ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: Проверяем еще раз перед показом CallKit
              // Это защита от race condition, когда call_offer приходит раньше, чем обрабатывается incomingVoIPCall
              final iosCallKitHandler = IOSCallKitHandler();
              final doubleCheck = iosCallKitHandler.wasCallKitShownForCall(callId);
              if (doubleCheck) {
                // print('[WebRTC] ⚠️⚠️⚠️ ДВОЙНАЯ ПРОВЕРКА: CallKit уже был показан!');
                // print('[WebRTC] ⚠️ Пропускаем показ CallKit');
              } else {
                // ⭐⭐⭐ НОВОЕ: Проверяем состояние приложения через метод channel
                // Если приложение открыто (foreground), CallKit не показывается на нативном уровне
                // Но если call_offer пришел через WebSocket, нужно проверить, не открыто ли приложение
                // Если приложение открыто, не показываем CallKit - пользователь уже видит приложение
                bool shouldSkipCallKit = false;
                try {
                  final appState = await platform.invokeMethod<String>('getAppState');
                  final isAppInForeground = appState == 'active';
                  
                  // print('[WebRTC] ========================================');
                  // print('[WebRTC] 🔍 Проверка состояния приложения');
                  // print('[WebRTC] App State: $appState');
                  // print('[WebRTC] Is Foreground: $isAppInForeground');
                  // print('[WebRTC] ========================================');
                  
                  if (isAppInForeground) {
                    // print('[WebRTC] ========================================');
                    // print('[WebRTC] 📱 Приложение открыто (foreground)');
                    // print('[WebRTC] ⏭️ НЕ показываем CallKit - пользователь уже видит приложение');
                    // print('[WebRTC] ✅ CallScreen будет открыт через callState');
                    // print('[WebRTC] ========================================');
                    shouldSkipCallKit = true;
                  }
                } catch (e) {
                  // print('[WebRTC] ⚠️ Не удалось проверить состояние приложения: $e');
                  // print('[WebRTC] ⚠️ Продолжаем показ CallKit (fallback)');
                }
                
                // ⭐⭐⭐ ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: Проверяем статус звонка еще раз
                if (!shouldSkipCallKit && !isCallAlreadyAccepted) {
                  // print('[WebRTC] 📞 Показываем CallKit UI...');
                  await IOSCallKitHelper.reportIncomingCall(
                    callId: callId,
                    callerName: callerName ?? 'Неизвестный',
                    hasVideo: callType == 'video',
                  );
                  // print('[WebRTC] ✅ CallKit UI показан');
                  
                  // ⭐⭐⭐ КРИТИЧНО: Явно добавляем callId в Set СРАЗУ после успешного показа CallKit
                  // Это должно произойти ДО того, как может прийти второй call_offer
                  iosCallKitHandler.markCallKitShownForCall(callId);
                  // print('[WebRTC] ✅ CallId добавлен в Set для отслеживания: $callId');
                } else if (shouldSkipCallKit) {
                  // print('[WebRTC] ⏭️ Пропускаем показ CallKit - приложение открыто');
                } else if (isCallAlreadyAccepted) {
                  // print('[WebRTC] ⚠️⚠️⚠️ Звонок уже принят, не показываем CallKit!');
                  // print('[WebRTC] Статус: $currentCallStatus');
                }
              }
            } catch (e) {
              // print('[WebRTC] ⚠️ Ошибка CallKit: $e');
              // Продолжаем показывать обычный UI если CallKit не сработал
            }
          } else if (!kIsWeb && Platform.isAndroid) {
            // ⭐⭐⭐ НОВОЕ: Показываем ConnectionService (аналог CallKit) на Android
            try {
              if (isCallAlreadyAccepted) {
                // print('[WebRTC] ⚠️⚠️⚠️ Звонок уже принят, не показываем ConnectionService!');
                // print('[WebRTC] Статус: $currentCallStatus');
              } else {
                // print('[WebRTC] 📞 Показываем ConnectionService UI (Android)...');
                await platform.invokeMethod('showIncomingCall', {
                  'callId': callId,
                  'callerName': callerName ?? 'Неизвестный',
                  'callType': callType,
                });
                // print('[WebRTC] ✅ ConnectionService UI показан');
              }
            } catch (e) {
              // print('[WebRTC] ⚠️ Ошибка ConnectionService: $e');
              // Продолжаем показывать обычный UI если ConnectionService не сработал
            }
          }
        }
        // print('[WebRTC] ========================================');

        // ⭐⭐⭐ КРИТИЧНО: Всегда добавляем в callState, чтобы CallScreen открылся
        // print('[WebRTC] 📤 Добавляем звонок в callState для открытия CallScreen');
        // print('[WebRTC] Call ID: ${_currentCall?.id}');
        // print('[WebRTC] Call Status: ${_currentCall?.status}');
        _safeAddToCallState(_currentCall);
        // print('[WebRTC] ✅ Звонок добавлен в callState');
        
        // ⭐⭐⭐ УДАЛЕНО: Автоматическое принятие звонка на Android
        // Пользователь должен явно принять звонок, нажав кнопку "Ответить"
        // Автоматическое принятие создавало проблему, когда звонок принимался без согласия пользователя
        
        // ⭐⭐⭐ КРИТИЧНО: Проверяем, был ли звонок уже принят через CallKit
        // Если да, автоматически принимаем звонок СРАЗУ после добавления в callState
        // Это важно для случая, когда call_offer приходит после принятия через CallKit
        if (!kIsWeb && Platform.isIOS) {
          try {
            final iosCallKitHandler = IOSCallKitHandler();
            final wasAccepted = iosCallKitHandler.wasCallAcceptedViaCallKit(callId);
            // print('[WebRTC] 🔍 Проверка: был ли звонок принят через CallKit?');
            // print('[WebRTC] Результат: $wasAccepted');
            // print('[WebRTC] Call ID: $callId');
            
            if (wasAccepted) {
              // print('[WebRTC] ========================================');
              // print('[WebRTC] ✅ Звонок уже принят через CallKit!');
              // print('[WebRTC] 🎯 Автоматически принимаем звонок через WebRTC...');
              // print('[WebRTC] Call ID: $callId');
              // print('[WebRTC] WebSocket подключен: ${WebSocketManager.instance.isConnected}');
              // print('[WebRTC] _pendingOffer: ${_pendingOffer != null ? "есть" : "нет"}');
              // print('[WebRTC] ========================================');
              
              // ⭐⭐⭐ ОПТИМИЗИРОВАНО: Уменьшена задержка для быстрого принятия звонка
              // Минимальная задержка для стабилизации WebSocket и аудио сессии
              Future.delayed(const Duration(milliseconds: 100), () async {
                try {
                  // print('[WebRTC] 🎯 Вызываем answerCall для автоматического принятия...');
                  // print('[WebRTC] Время вызова: ${DateTime.now()}');
                  await answerCall(callId);
                  // print('[WebRTC] ✅ Звонок автоматически принят');
                } catch (e, stackTrace) {
                  // print('[WebRTC] ❌ Ошибка автоматического принятия: $e');
                  // print('[WebRTC] Stack: $stackTrace');
                }
              });
            }
          } catch (e, stackTrace) {
            // print('[WebRTC] ⚠️ Ошибка проверки CallKit accept: $e');
            // print('[WebRTC] Stack: $stackTrace');
          }
        }
      }
    } catch (e, stackTrace) {
      // print('[WebRTC] ❌ Ошибка: $e');
      // print('[WebRTC] Stack: $stackTrace');
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 📞 ОТВЕТ НА ЗВОНОК');
      // print('[WebRTC] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      // print('[WebRTC] Time: ${DateTime.now()}');
      // print('[WebRTC] ========================================');

      if (_isAnswering) {
        // print('[WebRTC] ⚠️ Уже отвечаем');
        return;
      }

      _isAnswering = true;

      // ⭐⭐⭐ КРИТИЧНО ДЛЯ ПЕРВОГО ЗВОНКА: Проверяем готовность WebSocket перед принятием звонка
      final wsManager = WebSocketManager.instance;
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🔍 Проверка WebSocket перед принятием звонка');
      // print('[WebRTC] WebSocket подключен: ${wsManager.isConnected}');
      // print('[WebRTC] ========================================');
      
      if (!wsManager.isConnected) {
        // print('[WebRTC] ⚠️ WebSocket не подключен, пытаемся подключиться...');
        
        // ⭐⭐⭐ НОВОЕ: Пытаемся подключиться, если не подключен
        try {
          // WebSocketManager должен иметь сохраненные token и userId
          // Если их нет, подключение не произойдет, но мы попробуем
          await wsManager.connect();
          // print('[WebRTC] ✅ Попытка подключения WebSocket инициирована');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка при попытке подключения WebSocket: $e');
        }
        
        // ⭐⭐⭐ УВЕЛИЧЕНО ДЛЯ ПЕРВОГО ЗВОНКА: Ждем подключения до 5 секунд
        // Для первого звонка нужно больше времени, так как WebSocket может только что начать подключаться
        const maxAttempts = 100; // 100 попыток по 50мс = 5 секунд
        for (int i = 0; i < maxAttempts; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          if (wsManager.isConnected) {
            // print('[WebRTC] ✅ WebSocket подключен (попытка ${i + 1}/$maxAttempts)');
            break;
          }
          if (i % 20 == 0 && i > 0) {
            // print('[WebRTC] ⏳ Ожидание WebSocket (попытка ${i + 1}/$maxAttempts)...');
          }
        }
        if (!wsManager.isConnected) {
          // print('[WebRTC] ❌❌❌ WebSocket не подключен после ожидания (5 секунд)');
          // print('[WebRTC] ⚠️ Это может быть проблемой для первого звонка');
          // print('[WebRTC] Продолжаем, но answer может не отправиться');
          // ⭐⭐⭐ НОВОЕ: Не прерываем процесс, но предупреждаем
          // WebSocket может подключиться позже
        }
      } else {
        // print('[WebRTC] ✅ WebSocket уже подключен');
      }

      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🔍 Проверка звонка перед принятием:');
      // print('[WebRTC]   _currentCall == null: ${_currentCall == null}');
      if (_currentCall != null) {
        // print('[WebRTC]   _currentCall!.id: ${_currentCall!.id}');
        // print('[WebRTC]   callId (параметр): $callId');
        // print('[WebRTC]   IDs совпадают: ${_currentCall!.id == callId}');
        // print('[WebRTC]   _currentCall!.status: ${_currentCall!.status}');
        // print('[WebRTC]   CallStatus.incoming: ${CallStatus.incoming}');
        // print('[WebRTC]   Статус == incoming: ${_currentCall!.status == CallStatus.incoming}');
      }
      // print('[WebRTC] ========================================');
      
      if (_currentCall == null || _currentCall!.id != callId) {
        // print('[WebRTC] ❌ Звонок не найден');
        // print('[WebRTC]   _currentCall: $_currentCall');
        // print('[WebRTC]   Ожидаемый callId: $callId');
        _isAnswering = false;
        return;
      }
      
      // ⭐⭐⭐ ИСПРАВЛЕНО: Проверяем статус звонка - если уже не incoming, значит уже принят
      // ⭐⭐⭐ НОВОЕ: Для iOS с CallKit разрешаем принимать звонок даже если статус не incoming
      // Это важно для случая, когда CallKit принят, но статус еще не обновлен
      final iosCallKitHandler = IOSCallKitHandler();
      final isIOSCallKitAccept =
          !kIsWeb && Platform.isIOS && iosCallKitHandler.wasCallAcceptedViaCallKit(callId);
      if (_currentCall!.status != CallStatus.incoming && !isIOSCallKitAccept) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] ⚠️⚠️⚠️ Звонок УЖЕ принят или обрабатывается!');
        // print('[WebRTC] Текущий статус: ${_currentCall!.status}');
        // print('[WebRTC] Call ID: $callId');
        // print('[WebRTC] isIOSCallKitAccept: $isIOSCallKitAccept');
        // print('[WebRTC] ⚠️ Пропускаем повторное принятие');
        // print('[WebRTC] ========================================');
        _isAnswering = false;
        return;
      } else if (_currentCall!.status != CallStatus.incoming && isIOSCallKitAccept) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] ⚠️ Статус не incoming, но CallKit принят - продолжаем');
        // print('[WebRTC] Текущий статус: ${_currentCall!.status}');
        // print('[WebRTC] Call ID: $callId');
        // print('[WebRTC] ========================================');
      }

      if (_pendingOffer == null) {
        // print('[WebRTC] ⏳ Ждем offer...');
        // print('[WebRTC] ⚠️ ВАЖНО: Для заблокированного экрана нужно больше времени');
        final waitPlatform = kIsWeb
            ? 'WEB'
            : (Platform.isIOS ? 'iOS' : 'Other');
        // print('[WebRTC] Platform: $waitPlatform');
        
        // ⭐⭐⭐ ОПТИМИЗИРОВАНО: Уменьшено для ускорения соединения
        // iOS: 100 попыток по 50мс = 5 секунд (было 7.5 сек)
        // Другие: 60 попыток по 50мс = 3 секунды (было 5 сек)
        final maxAttempts = (!kIsWeb && Platform.isIOS) ? 100 : 60;
        const checkInterval = Duration(milliseconds: 50);
        
        // ⭐⭐⭐ НОВОЕ: Проверяем готовность WebSocket
        final wsManager = WebSocketManager.instance;
        bool isWSConnected = wsManager.isConnected;
        // print('[WebRTC] WebSocket подключен: $isWSConnected');
        // print('[WebRTC] Таймаут ожидания offer: ${maxAttempts * 50 / 1000} секунд');
        
        for (int i = 0; i < maxAttempts; i++) {
          await Future.delayed(checkInterval);
          
          // ⭐⭐⭐ НОВОЕ: Проверяем подключение WebSocket периодически
          if (i % 10 == 0) { // Каждые 500мс
            isWSConnected = wsManager.isConnected;
            // print('[WebRTC] Проверка WebSocket (попытка ${i + 1}/$maxAttempts): $isWSConnected');
            // print('[WebRTC] _pendingOffer: ${_pendingOffer != null ? "найден" : "null"}');
          }
          
          if (_pendingOffer != null) {
            // print('[WebRTC] ✅ Offer получен! (попытка ${i + 1}/$maxAttempts)');
            // print('[WebRTC] Время ожидания: ${(i + 1) * 50}мс');
            break;
          }
        }

        if (_pendingOffer == null) {
          // print('[WebRTC] ========================================');
          // print('[WebRTC] ❌❌❌ ТАЙМАУТ: offer не получен');
          // print('[WebRTC] Таймаут: ${maxAttempts * 50 / 1000} секунд');
          // print('[WebRTC] WebSocket подключен: ${wsManager.isConnected}');
          // print('[WebRTC] _currentCall: ${_currentCall?.id}');
          // print('[WebRTC] _currentCall?.status: ${_currentCall?.status}');
          final reconnectPlatform = kIsWeb
              ? 'WEB'
              : (Platform.isIOS ? 'iOS' : 'Other');
          // print('[WebRTC] Platform: $reconnectPlatform');
          // print('[WebRTC] ========================================');
          _isAnswering = false;
          await endCall('no_offer');
          return;
        }
      }

      // print('[WebRTC] ✅ Отвечаем на звонок');

      _currentCall = _currentCall!.copyWith(status: CallStatus.connecting);
      _safeAddToCallState(_currentCall);

      // ⭐⭐⭐ ОПТИМИЗИРОВАНО: Последовательное создание media streams и peer connection
      // Peer connection зависит от media streams, поэтому выполняем последовательно
      await _initializeMediaStreams(_currentCall!.callType == 'video');
      await _createPeerConnection();

      // print('[WebRTC] 📥 Устанавливаем remote description');
      final offer = RTCSessionDescription(
        _pendingOffer!['sdp'],
        _pendingOffer!['type'],
      );
      await _peerConnection!.setRemoteDescription(offer);
      _isRemoteDescriptionSet = true;

      // ⭐⭐⭐ КРИТИЧНО: Обрабатываем ICE кандидаты ПЕРЕД созданием answer
      // Это важно для правильной установки соединения
      await _processIceCandidatesQueue();

      // print('[WebRTC] 📤 Создаем answer');
      // print('[WebRTC] WebSocket подключен перед созданием answer: ${WebSocketManager.instance.isConnected}');
      final answer = await _peerConnection!.createAnswer(_constraints);
      // print('[WebRTC] ✅ Answer создан');
      // print('[WebRTC] Answer SDP size: ${answer.sdp?.length ?? 0} bytes');
      // print('[WebRTC] Answer type: ${answer.type}');
      
      await _peerConnection!.setLocalDescription(answer);
      // print('[WebRTC] ✅ Local description установлен');

      // ⭐⭐⭐ КРИТИЧНО: Настраиваем аудио ПОСЛЕ создания PeerConnection
      // чтобы WebRTC плагин не переопределил наши настройки
      await _configureAudioForCall(_currentCall!.callType);
      
      // ⭐⭐⭐ КРИТИЧНО: Для Android дополнительно проверяем и активируем аудио
      // Это важно для обеспечения звука при входящих звонках
      if (!kIsWeb && Platform.isAndroid) {
        // print('[WebRTC] 🔊 Дополнительная проверка и активация аудио для Android...');
        try {
          // Повторно настраиваем аудио для Android, чтобы гарантировать звук
          await Future.delayed(const Duration(milliseconds: 200));
          await _configureAudioForCall(_currentCall!.callType);
          // print('[WebRTC] ✅ Аудио для Android дополнительно настроено');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка дополнительной настройки аудио для Android: $e');
          // Не критично - продолжаем работу
        }
      }
      
      // ⭐⭐⭐ НОВОЕ: Для iOS дополнительно активируем аудио сессию после создания answer
      // Это критично для заблокированного экрана, когда приложение только что проснулось
      if (!kIsWeb && Platform.isIOS) {
        // print('[WebRTC] 🔊 Дополнительная активация Audio Session для заблокированного экрана...');
        try {
          await IOSAudioHelper.configureAudioSession();
          // print('[WebRTC] ✅ Audio Session дополнительно активирована');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка дополнительной активации Audio Session: $e');
          // Не критично - продолжаем работу
        }
      }

      // print('[WebRTC] ========================================');
      // print('[WebRTC] 📤 ОТПРАВКА ANSWER');
      // print('[WebRTC] Answer SDP size: ${answer.sdp?.length ?? 0} bytes');
      // print('[WebRTC] Answer type: ${answer.type}');
      // print('[WebRTC] Call ID: $callId');
      // print('[WebRTC] WebSocket подключен: ${WebSocketManager.instance.isConnected}');
      // print('[WebRTC] ========================================');
      
      if (!WebSocketManager.instance.isConnected) {
        // print('[WebRTC] ❌❌❌ КРИТИЧЕСКАЯ ОШИБКА: WebSocket НЕ подключен!');
        // print('[WebRTC] Answer НЕ будет отправлен!');
        // print('[WebRTC] Пытаемся подключиться...');
        
        try {
          await WebSocketManager.instance.connect();
          // print('[WebRTC] ✅ Попытка подключения WebSocket инициирована');
          
          // Ждем подключения еще 2 секунды
          for (int i = 0; i < 40; i++) {
            await Future.delayed(const Duration(milliseconds: 50));
            if (WebSocketManager.instance.isConnected) {
              // print('[WebRTC] ✅ WebSocket подключен (попытка ${i + 1}/40)');
              break;
            }
          }
        } catch (e) {
          // print('[WebRTC] ❌ Ошибка подключения WebSocket: $e');
        }
        
        if (!WebSocketManager.instance.isConnected) {
          // print('[WebRTC] ❌❌❌ WebSocket все еще не подключен!');
          // print('[WebRTC] Answer НЕ будет отправлен!');
          _isAnswering = false;
          await endCall('websocket_not_connected_for_answer');
          return;
        }
      }
      
      // print('[WebRTC] ✅ WebSocket подключен, отправляем answer...');
      WebSocketManager.instance.sendCallAnswer(callId, answer.toMap());

      // print('[WebRTC] ========================================');
      // print('[WebRTC] ✅✅✅ ANSWER ОТПРАВЛЕН!');
      // print('[WebRTC] WebSocket подключен: ${WebSocketManager.instance.isConnected}');
      // print('[WebRTC] Call ID: $callId');
      // print('[WebRTC] Время отправки: ${DateTime.now()}');
      // print('[WebRTC] ========================================');
      
      // ⭐⭐⭐ КРИТИЧНО: Обновляем статус на connecting после отправки answer
      if (_currentCall != null) {
        _currentCall = _currentCall!.copyWith(status: CallStatus.connecting);
        _safeAddToCallState(_currentCall);
        // print('[WebRTC] ✅ Статус обновлен на connecting');
      }

      _isAnswering = false;
    } catch (e, stackTrace) {
      // print('[WebRTC] ❌ Ошибка: $e');
      // print('[WebRTC] Stack: $stackTrace');
      _isAnswering = false;
      await endCall('error');
    }
  }

  Future<void> _handleCallAnswer(Map<String, dynamic> message) async {
    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] ✅ Получен answer');
      // print('[WebRTC] Time: ${DateTime.now()}');
      final hangupPlatform = kIsWeb
          ? 'WEB'
          : (Platform.isAndroid
              ? 'Android'
              : (Platform.isIOS ? 'iOS' : 'Other'));
      // print('[WebRTC] Platform: $hangupPlatform');
      // print('[WebRTC] ========================================');

      if (_peerConnection == null) {
        // print('[WebRTC] ❌ No peer connection');
        // print('[WebRTC] ⚠️ PeerConnection не создан, возможно звонок еще не инициирован');
        return;
      }

      final answer = RTCSessionDescription(
        message['answer']['sdp'],
        message['answer']['type'],
      );

      // print('[WebRTC] 📥 Устанавливаем remote description (answer)');
      // print('[WebRTC] Answer SDP size: ${answer.sdp?.length ?? 0} bytes');
      // print('[WebRTC] Answer type: ${answer.type}');
      // print('[WebRTC] Current signaling state: ${_peerConnection?.signalingState}');
      // print('[WebRTC] Current ICE state: ${_peerConnection?.iceConnectionState}');
      // print('[WebRTC] Current connection state: ${_peerConnection?.connectionState}');
      
      await _peerConnection!.setRemoteDescription(answer);
      _isRemoteDescriptionSet = true;
      // print('[WebRTC] ✅ Remote description установлен');
      // print('[WebRTC] New signaling state: ${_peerConnection?.signalingState}');

      // print('[WebRTC] 📋 Обрабатываем очередь ICE кандидатов...');
      // print('[WebRTC] Queue size before: ${_iceCandidatesQueue.length}');
      await _processIceCandidatesQueue();
      // print('[WebRTC] ✅ ICE кандидаты обработаны');
      // print('[WebRTC] Queue size after: ${_iceCandidatesQueue.length}');
      
      // ⭐⭐⭐ ДИАГНОСТИКА: Проверяем состояние PeerConnection
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🔍 Диагностика PeerConnection после answer:');
      // print('[WebRTC]   ICE Connection State: ${_peerConnection?.iceConnectionState}');
      // print('[WebRTC]   Connection State: ${_peerConnection?.connectionState}');
      // print('[WebRTC]   Signaling State: ${_peerConnection?.signalingState}');
      // print('[WebRTC]   Remote Description Set: $_isRemoteDescriptionSet');
      // print('[WebRTC] ========================================');

      // ⭐⭐⭐ КРИТИЧНО ДЛЯ ANDROID: Дополнительная настройка аудио после установки answer
      if (!kIsWeb && Platform.isAndroid) {
        // print('[WebRTC] 🔊 Дополнительная настройка аудио для Android после answer...');
        try {
          await Future.delayed(const Duration(milliseconds: 300));
          await _configureAudioForCall(_currentCall?.callType ?? 'audio');
          // print('[WebRTC] ✅ Аудио для Android дополнительно настроено после answer');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка дополнительной настройки аудио для Android: $e');
        }
      }

      // ⭐⭐⭐ ИСПРАВЛЕНО: Не меняем статус на connecting если соединение уже установлено
      // Это может произойти если answer приходит после того как соединение уже установлено
      if (_currentCall != null && _currentCall!.status != CallStatus.active) {
        _currentCall = _currentCall!.copyWith(status: CallStatus.connecting);
        _safeAddToCallState(_currentCall);
        // print('[WebRTC] ✅ Статус установлен на connecting');
      } else if (_currentCall != null && _currentCall!.status == CallStatus.active) {
        // print('[WebRTC] ⚠️ Соединение уже установлено (active), не меняем статус');
      }

      // print('[WebRTC] ✅✅✅ Answer обработан успешно!');
    } catch (e, stackTrace) {
      // print('[WebRTC] ❌ Ошибка обработки answer: $e');
      // print('[WebRTC] Stack trace: $stackTrace');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> message) async {
    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 📥 INCOMING ICE Candidate');
      // print('[WebRTC] candidate: ${message['candidate']['candidate']}');
      // print('[WebRTC] sdpMid: ${message['candidate']['sdpMid']}');
      // print('[WebRTC] sdpMLineIndex: ${message['candidate']['sdpMLineIndex']}');
      // print('[WebRTC] ========================================');

      final candidate = RTCIceCandidate(
        message['candidate']['candidate'],
        message['candidate']['sdpMid'],
        message['candidate']['sdpMLineIndex'],
      );

      if (_peerConnection != null && _isRemoteDescriptionSet) {
        try {
          await _peerConnection!.addCandidate(candidate);
          // print('[WebRTC] ✅ ICE candidate added to peer connection');
          // print('[WebRTC] Current ICE state: ${_peerConnection?.iceConnectionState}');
          // print('[WebRTC] Current connection state: ${_peerConnection?.connectionState}');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка добавления ICE candidate: $e');
          // print('[WebRTC] Добавляем в очередь для повторной попытки');
          _iceCandidatesQueue.add(candidate);
        }
      } else {
        _iceCandidatesQueue.add(candidate);
        // print('[WebRTC] 📋 ICE candidate queued (remote desc not set yet)');
        // print('[WebRTC] Queue size: ${_iceCandidatesQueue.length}');
        // print('[WebRTC] PeerConnection exists: ${_peerConnection != null}');
        // print('[WebRTC] Remote description set: $_isRemoteDescriptionSet');
      }
    } catch (e) {
      // print('[WebRTC] ❌ ICE candidate error: $e');
    }
  }

  Future<void> _processIceCandidatesQueue() async {
    if (_iceCandidatesQueue.isEmpty) {
      // print('[WebRTC] 📋 ICE queue is empty, nothing to process');
      return;
    }

    // print('[WebRTC] ========================================');
    // print('[WebRTC] 📋 Processing ${_iceCandidatesQueue.length} ICE candidates');
    // print('[WebRTC] PeerConnection exists: ${_peerConnection != null}');
    // print('[WebRTC] Remote description set: $_isRemoteDescriptionSet');
    // print('[WebRTC] ========================================');

    if (_peerConnection == null) {
      // print('[WebRTC] ⚠️ PeerConnection is null, cannot process ICE candidates');
      return;
    }

    if (!_isRemoteDescriptionSet) {
      // print('[WebRTC] ⚠️ Remote description not set yet, keeping candidates in queue');
      return;
    }

    final candidates = List<RTCIceCandidate>.from(_iceCandidatesQueue);
    _iceCandidatesQueue.clear();

    int successCount = 0;
    int errorCount = 0;

    for (final candidate in candidates) {
      try {
        // print('[WebRTC] 📥 Adding ICE candidate: ${candidate.candidate}');
        await _peerConnection!.addCandidate(candidate);
        successCount++;
        // print('[WebRTC] ✅ ICE candidate added successfully');
      } catch (e) {
        errorCount++;
        // print('[WebRTC] ⚠️ ICE add error: $e');
        // print('[WebRTC] Candidate: ${candidate.candidate}');
        // print('[WebRTC] sdpMid: ${candidate.sdpMid}');
        // print('[WebRTC] sdpMLineIndex: ${candidate.sdpMLineIndex}');
      }
    }

    // print('[WebRTC] ========================================');
    // print('[WebRTC] ✅ ICE queue processed');
    // print('[WebRTC] Success: $successCount, Errors: $errorCount');
    // print('[WebRTC] ========================================');
  }

  void _handleUserOffline(Map<String, dynamic> message) {
    // print('[WebRTC] ========================================');
    // print('[WebRTC] 👤 Пользователь офлайн');
    // print('[WebRTC] User ID: ${message['userId']}');
    // print('[WebRTC] isOnline: ${message['isOnline']}');
    // print('[WebRTC] ========================================');

    // ⭐⭐⭐ ВАЖНО: Больше НЕ завершаем звонок по событию user_offline
    // Сервер может кратковременно отправлять user_offline даже когда звонок
    // уже устанавливается или активен (особенно с iOS + CallKit),
    // что приводило к ложным обрывам звонка.
    //
    // Теперь это событие используется только как информационное:
    // - для логов;
    // - для возможного обновления on-line статуса в UI (обрабатывается в ChatProvider).
    //
    // Все реальные завершения звонка обрабатываются через:
    // - сообщения call_ended от сервера;
    // - локальные вызовы endCall(), если пользователь сам сбрасывает.
    return;
  }

  void _handleCallEnded(Map<String, dynamic> message) {
    // print('[WebRTC] ========================================');
    // print('[WebRTC] 🔴 Звонок завершен');
    // print('[WebRTC] Time: ${DateTime.now()}');
    // print('[WebRTC] Reason: ${message['reason']}');
    // print('[WebRTC] Duration: ${message['duration']}');
    // print('[WebRTC] ========================================');

    // ⭐⭐⭐ ЗАЩИТА: Если endCall уже выполняется, не обрабатываем повторно
    if (_isEndingCall) {
      // print('[WebRTC] ⚠️ endCall уже выполняется, игнорируем _handleCallEnded');
      return;
    }

    // ⭐⭐⭐ КРИТИЧНО: Если звонок уже завершен (_currentCall == null или status == ended), игнорируем
    if (_currentCall == null || _currentCall!.status == CallStatus.ended) {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] ⚠️ Звонок уже завершен, игнорируем повторный call_ended');
      // print('[WebRTC] _currentCall: ${_currentCall == null ? "null" : _currentCall!.status}');
      // print('[WebRTC] Call ID из сообщения: ${message['callId']}');
      // print('[WebRTC] Это может быть отложенное сообщение от сервера');
      // print('[WebRTC] ========================================');
      return;
    }

    // ⭐⭐⭐ ИСПРАВЛЕНО: Проверяем длительность звонка, но НЕ игнорируем если reason: user или user_ended
    // Если пользователь завершил звонок (reason: user или user_ended), завершаем немедленно, даже если длительность некорректная
    final reason = message['reason'] as String?;
    final duration = message['duration'];
    final isUserEnded = (reason == 'user' || reason == 'user_ended');
    
    // Если это завершение пользователем - завершаем немедленно, независимо от длительности
    if (!isUserEnded && duration != null) {
      final durationMs = duration is int ? duration : (duration is num ? duration.toInt() : null);
      if (durationMs != null && (durationMs < 0 || durationMs < 1000)) {
        // print('[WebRTC] ========================================');
        // print('[WebRTC] ⚠️ ИГНОРИРУЕМ call_ended с некорректной длительностью');
        // print('[WebRTC] Duration: $durationMs мс');
        // print('[WebRTC] Reason: $reason');
        // print('[WebRTC] Это явно ошибка на сервере или со стороны звонящего');
        // print('[WebRTC] ========================================');
        return;
      }
    } else if (isUserEnded) {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] ✅ Пользователь завершил звонок (reason: user)');
      // print('[WebRTC] Завершаем звонок немедленно, даже если длительность некорректная');
      // print('[WebRTC] Duration: $duration');
      // print('[WebRTC] ========================================');
    }

    // ⭐⭐⭐ ИСПРАВЛЕНО: Защита от преждевременного завершения звонка от сервера
    // Если пользователь завершил звонок (reason: user или user_ended) - ВСЕГДА завершаем
    // Игнорируем call_ended от сервера ТОЛЬКО если это не завершение пользователем
    if (!kIsWeb && Platform.isIOS && _currentCall != null && !isUserEnded) {
      final callId = message['callId'] as String?;
      if (callId != null && callId == _currentCall!.id) {
        final callKitHandler = IOSCallKitHandler();
        if (callKitHandler.wasCallAcceptedViaCallKit(callId)) {
          final currentStatus = _currentCall!.status;
          // ⭐⭐⭐ ИСПРАВЛЕНО: Игнорируем только для incoming и connecting, НЕ для active
          if (currentStatus == CallStatus.incoming || 
              currentStatus == CallStatus.connecting) {
            // print('[WebRTC] ========================================');
            // print('[WebRTC] ⚠️ ИГНОРИРУЕМ call_ended от сервера - звонок еще устанавливается');
            // print('[WebRTC] Звонок был принят через CallKit');
            // print('[WebRTC] Статус звонка: $currentStatus');
            // print('[WebRTC] Причина от сервера: $reason');
            // print('[WebRTC] Duration: $duration');
            // print('[WebRTC] Это может быть ложное срабатывание');
            // print('[WebRTC] ========================================');
            return;
          }
        }
      }
    }
    
    // ⭐⭐⭐ КРИТИЧНО: Если пользователь завершил звонок (reason: user или user_ended), завершаем немедленно
    if (isUserEnded) {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] ✅ Пользователь завершил звонок через CallKit');
      // print('[WebRTC] Reason: $reason');
      // print('[WebRTC] Завершаем звонок немедленно');
      // print('[WebRTC] ========================================');
    }

    if (_currentCall != null) {
      final callId = _currentCall!.id;
      
      // ⭐⭐⭐ КРИТИЧНО: Уведомляем CallKit о завершении звонка
      if (!kIsWeb && Platform.isIOS) {
        try {
          // print('[WebRTC] 📞 Уведомляем CallKit о завершении звонка (из WebSocket)');
          IOSCallKitHelper.endCall(callId);
          // print('[WebRTC] ✅ CallKit уведомлен о завершении');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка уведомления CallKit: $e');
        }
      }
    }

    _cleanup();

    if (_currentCall != null) {
      final endedCallId = _currentCall!.id;
      _currentCall = _currentCall!.copyWith(
        status: CallStatus.ended,
        endTime: DateTime.now(),
      );
      _safeAddToCallState(_currentCall);

      Future.delayed(const Duration(seconds: 2), () {
        // ⭐⭐⭐ КРИТИЧНО: Очищаем данные CallKit для завершенного звонка
        if (!kIsWeb && Platform.isIOS) {
          try {
            final iosCallKitHandler = IOSCallKitHandler();
            iosCallKitHandler.clearCallData(endedCallId);
            // print('[WebRTC] ✅ CallKit данные очищены для звонка: $endedCallId');
          } catch (e) {
            // print('[WebRTC] ⚠️ Ошибка очистки CallKit данных: $e');
          }
        }
        
        _currentCall = null;
        _pendingOffer = null;
        _isEndingCall = false; // ⭐⭐⭐ Сбрасываем флаг
        _safeAddToCallState(null);
      });
    }
  }

  void _handleCallDeclined(Map<String, dynamic> message) {
    // print('[WebRTC] ========================================');
    // print('[WebRTC] ❌ Звонок отклонен');
    // print('[WebRTC] Time: ${DateTime.now()}');
    // print('[WebRTC] ========================================');

    _cleanup();

    if (_currentCall != null) {
      final callId = _currentCall!.id; // ⭐⭐⭐ Сохраняем callId до установки в null
      _currentCall = _currentCall!.copyWith(status: CallStatus.declined);
      _safeAddToCallState(_currentCall);

      Future.delayed(const Duration(seconds: 2), () {
        _currentCall = null;
        _pendingOffer = null;
        
        // ⭐⭐⭐ НОВОЕ: Очищаем callId из Set обработанных call_offer
        _processedCallOffers.remove(callId);
        // print('[WebRTC] ✅ CallId удален из Set обработанных: $callId');
        
        _safeAddToCallState(null);
      });
    }
  }

  Future<void> declineCall(String callId) async {
    // print('[WebRTC] ❌ Отклоняем звонок: $callId');

    if (_currentCall != null && _currentCall!.id == callId) {
      // ⭐⭐⭐ КРИТИЧНО: Уведомляем CallKit о отклонении звонка
      if (!kIsWeb && Platform.isIOS) {
        try {
          // print('[WebRTC] 📞 Уведомляем CallKit об отклонении звонка');
          IOSCallKitHelper.endCall(callId);
          // print('[WebRTC] ✅ CallKit уведомлен об отклонении');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка уведомления CallKit: $e');
        }
      }
      
      WebSocketManager.instance.declineCall(callId);
      _cleanup();

      // ⭐⭐⭐ НОВОЕ: Очищаем callId из Set обработанных call_offer
      _processedCallOffers.remove(callId);
      // print('[WebRTC] ✅ CallId удален из Set обработанных: $callId');

      _currentCall = null;
      _pendingOffer = null;
      _safeAddToCallState(null);
    }
  }

  Future<void> toggleMute() async {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        audioTrack.enabled = !audioTrack.enabled;
        // print('[WebRTC] 🎤 Микрофон: ${audioTrack.enabled ? "вкл" : "выкл"}');
      }
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
        // print('[WebRTC] 📹 Видео: ${videoTrack.enabled ? "вкл" : "выкл"}');
      }
    }
  }

  Future<void> toggleSpeaker() async {
    if (kIsWeb) {
      // print('[WebRTC] 🔊 Toggle speaker (Web - no-op)');
      return;
    }

    try {
      // print('[WebRTC] ========================================');
      // print('[WebRTC] 🔊 Toggle Speaker (Android)');
      // print('[WebRTC] ========================================');

      // ⭐⭐⭐ ИСПРАВЛЕНО: Используем правильное имя метода для iOS
      final bool currentState = !kIsWeb && Platform.isIOS
          ? await audioChannel.invokeMethod('isSpeakerEnabled') as bool
          : await audioChannel.invokeMethod('isSpeakerphoneOn') as bool;
      // print('[WebRTC] Текущее: ${currentState ? "Speaker" : "Earpiece"}');

      final bool newState = !currentState;

      try {
        await Helper.setSpeakerphoneOn(newState);
        // print('[WebRTC] ✅ Helper.setSpeakerphoneOn($newState) вызван');
      } catch (e) {
        // print('[WebRTC] ⚠️ Helper.setSpeakerphoneOn не сработал: $e');
        await audioChannel.invokeMethod('toggleSpeaker', {'enable': newState});
      }

      // print('[WebRTC] Новое: ${newState ? "Speaker" : "Earpiece"}');
      // print('[WebRTC] ========================================');

      await audioChannel.invokeMethod('logAudioState');
    } catch (e) {
      // print('[WebRTC] ❌ Ошибка toggleSpeaker: $e');
      rethrow;
    }
  }

  Future<void> acceptCall(String callId) async {
    return answerCall(callId);
  }

  bool _isEndingCall = false; // ⭐⭐⭐ Защита от повторных вызовов

  Future<void> endCall([String? reason]) async {
    // ⭐⭐⭐ ЗАЩИТА: Предотвращаем повторные вызовы
    if (_isEndingCall) {
      // print('[WebRTC] ⚠️ endCall уже выполняется, игнорируем повторный вызов');
      return;
    }

    if (_currentCall == null) {
      // print('[WebRTC] ⚠️ Нет активного звонка для завершения');
      return;
    }

    _isEndingCall = true;
    // print('[WebRTC] ========================================');
    // print('[WebRTC] 🔴 Завершаем звонок');
    // print('[WebRTC] Reason: ${reason ?? "user"}');
    // print('[WebRTC] Time: ${DateTime.now()}');
    // print('[WebRTC] ========================================');

    final callId = _currentCall!.id;
    
    // ⭐⭐⭐ КРИТИЧНО: Останавливаем heartbeat СРАЗУ, чтобы предотвратить отправку heartbeat после завершения
    _stopHeartbeat();
    // print('[WebRTC] ✅ Heartbeat остановлен');
    
    // ⭐⭐⭐ КРИТИЧНО: Уведомляем CallKit о завершении звонка ПЕРЕД cleanup
    // ⚠️ НО: Если звонок завершается через CallKit UI, CallKit уже сам обработал завершение
    // Поэтому вызываем endCall только если reason != 'user_ended' (т.е. завершение не через CallKit UI)
    if (!kIsWeb && Platform.isIOS && reason != 'user_ended') {
      try {
        // print('[WebRTC] 📞 Уведомляем CallKit о завершении звонка (reason: $reason)');
        await IOSCallKitHelper.endCall(callId);
        // print('[WebRTC] ✅ CallKit уведомлен о завершении');
      } catch (e) {
        // print('[WebRTC] ⚠️ Ошибка уведомления CallKit: $e');
      }
    } else if (!kIsWeb && Platform.isIOS && reason == 'user_ended') {
      // print('[WebRTC] ⚠️ Звонок завершен через CallKit UI - CallKit уже обработал завершение');
    }
    
    WebSocketManager.instance.endCall(callId, reason ?? 'user');
    _cleanup();

    _currentCall = _currentCall!.copyWith(
      status: CallStatus.ended,
      endTime: DateTime.now(),
    );
    _safeAddToCallState(_currentCall);

    // ⭐⭐⭐ ОПТИМИЗИРОВАНО: Уменьшена задержка для более быстрой очистки UI
    // Для iOS CallKit UI обновляется сразу, поэтому можем очистить состояние быстрее
    final cleanupDelay = (!kIsWeb && Platform.isIOS)
        ? const Duration(milliseconds: 500)
        : const Duration(seconds: 2);
    Future.delayed(cleanupDelay, () {
      // ⭐⭐⭐ КРИТИЧНО: Очищаем данные CallKit для завершенного звонка
      if (!kIsWeb && Platform.isIOS) {
        try {
          final iosCallKitHandler = IOSCallKitHandler();
          iosCallKitHandler.clearCallData(callId);
          // print('[WebRTC] ✅ CallKit данные очищены для звонка: $callId');
        } catch (e) {
          // print('[WebRTC] ⚠️ Ошибка очистки CallKit данных: $e');
        }
      }
      
      _currentCall = null;
      _pendingOffer = null;
      _isEndingCall = false; // ⭐⭐⭐ Сбрасываем флаг
      
      // ⭐⭐⭐ НОВОЕ: Очищаем callId из Set обработанных call_offer
      _processedCallOffers.remove(callId);
      // print('[WebRTC] ✅ CallId удален из Set обработанных: $callId');
      
      _safeAddToCallState(null);
    });
  }

  void _cleanup() {
    // ⭐⭐⭐ КРИТИЧНО: Сбрасываем флаг уведомления о соединении
    _hasNotifiedConnection = false;
    // print('[WebRTC] ========================================');
    // print('[WebRTC] 🧹 Cleanup');
    // print('[WebRTC] Time: ${DateTime.now()}');
    // print('[WebRTC] ========================================');

    // ⭐ КРИТИЧНО: Останавливаем heartbeat
    _stopHeartbeat();
    
    // ⭐⭐⭐ НОВОЕ: Отменяем таймаут ICE
    _iceTimeoutTimer?.cancel();
    _iceTimeoutTimer = null;

    if (!kIsWeb) {
      try {
        audioChannel.invokeMethod('restoreAudioSettings');
        // print('[WebRTC] ✅ Аудио настройки восстановлены');
      } catch (e) {
        // print('[WebRTC] ⚠️ Ошибка восстановления аудио: $e');
      }
    }

    try {
      _localStream?.getTracks().forEach((track) {
        try {
          track.stop();
        } catch (e) {}
      });
      _localStream?.dispose();
    } catch (e) {}

    _localStream = null;
    _safeAddToLocalStream(null);

    _remoteStream = null;
    _safeAddToRemoteStream(null);

    try {
      _peerConnection?.close();
    } catch (e) {}

    _peerConnection = null;
    _iceCandidatesQueue.clear();
    _isRemoteDescriptionSet = false;

    // print('[WebRTC] ✅ Cleanup done');
    // print('[WebRTC] ========================================');
  }

  void dispose() {
    // print('[WebRTC] 🗑️ Dispose');

    _cleanup();
    _wsSubscription?.cancel();
    _callStateController?.close();
    _localStreamController?.close();
    _remoteStreamController?.close();

    _callStateController = null;
    _localStreamController = null;
    _remoteStreamController = null;
    _currentCall = null;
    _pendingOffer = null;

    // print('[WebRTC] ✅ Disposed');
  }
}
