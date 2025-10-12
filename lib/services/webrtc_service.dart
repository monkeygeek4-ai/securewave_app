// lib/services/webrtc_service.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call.dart';
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

  // MethodChannel для вызова нативных методов
  static const platform = MethodChannel('com.securewave.app/call');

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentUserId;
  Call? _currentCall;
  Call? get currentCall => _currentCall;
  // Хранение offer для входящих звонков
  Map<String, dynamic>? _pendingOffer;

  // Флаг защиты от повторного вызова
  bool _isAnswering = false;

  StreamController<Call?>? _callStateController;
  StreamController<MediaStream?>? _localStreamController;
  StreamController<MediaStream?>? _remoteStreamController;

  Stream<Call?> get callState => _callStateController?.stream ?? Stream.empty();
  Stream<MediaStream?> get localStream =>
      _localStreamController?.stream ?? Stream.empty();
  Stream<MediaStream?> get remoteStream =>
      _remoteStreamController?.stream ?? Stream.empty();

  StreamSubscription? _wsSubscription;

  final List<RTCIceCandidate> _iceCandidatesQueue = [];
  bool _isRemoteDescriptionSet = false;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
      {
        'urls': 'turn:securewave.sbk-19.ru:3478',
        'username': 'securewave',
        'credential': 'SecureWave2024!Turn'
      },
    ]
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  void _initializeStreams() {
    print('[WebRTC] 🔄 Переинициализация stream controllers');
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
      print('[WebRTC] 📢 CallState обновлен: ${call?.status}');
    } else {
      print('[WebRTC] ⚠️ CallStateController закрыт или null');
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

  Future<void> initialize(String userId) async {
    try {
      _currentUserId = userId;
      print('[WebRTC] ========================================');
      print('[WebRTC] 🚀 ИНИЦИАЛИЗАЦИЯ WebRTC Service');
      print('[WebRTC] ========================================');
      print('[WebRTC] User ID: $userId');

      if (_callStateController == null || _callStateController!.isClosed) {
        _initializeStreams();
      }

      print('[WebRTC] 📡 Подписываемся на WebSocket сообщения...');
      _wsSubscription?.cancel();
      _wsSubscription = WebSocketManager.instance.messages.listen(
        (data) {
          print('[WebRTC] 📨 Получено WebSocket сообщение');
          _handleWebSocketMessage(data);
        },
        onError: (error) {
          print('[WebRTC] ❌ Ошибка WebSocket: $error');
        },
        cancelOnError: false,
      );

      print('[WebRTC] ✅ Сервис успешно инициализирован');
      print('[WebRTC] ✅ Подписка на WebSocket активна');
      print('[WebRTC] 🌐 TURN сервер: securewave.sbk-19.ru:3478');
      print('[WebRTC] ========================================');
    } catch (e, stackTrace) {
      print('[WebRTC] ❌ Ошибка инициализации: $e');
      print('[WebRTC] Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];

    print('[WebRTC] ========================================');
    print('[WebRTC] 📨 WebSocket message: $type');
    print('[WebRTC] ========================================');

    switch (type) {
      case 'call_offer':
        print('[WebRTC] 📞 Обработка ВХОДЯЩЕГО ЗВОНКА!');
        _handleIncomingCall(message);
        break;

      case 'call_answer':
        print('[WebRTC] ✅ Обработка ответа на звонок');
        _handleCallAnswer(message);
        break;

      case 'call_ice_candidate':
        print('[WebRTC] 🧊 Обработка ICE candidate');
        _handleIceCandidate(message);
        break;

      case 'call_ended':
        print('[WebRTC] 📵 Звонок завершен');
        _handleCallEnded(message);
        break;

      case 'call_declined':
        print('[WebRTC] ❌ Звонок отклонен');
        _handleCallDeclined(message);
        break;

      default:
        print('[WebRTC] ℹ️ Сообщение типа "$type" не относится к звонкам');
        print('[WebRTC] (Должно обрабатываться ChatProvider)');
        break;
    }

    print('[WebRTC] ========================================');
  }

  Future<void> startCall({
    required String callId,
    required String chatId,
    required String receiverId,
    required String receiverName,
    required String callType,
  }) async {
    try {
      print('[WebRTC] ========================================');
      print('[WebRTC] 📞 НАЧИНАЕМ ИСХОДЯЩИЙ ЗВОНОК');
      print('[WebRTC] ========================================');
      print('[WebRTC] Тип: $callType');
      print('[WebRTC] Кому: $receiverName (ID: $receiverId)');
      print('[WebRTC] callId: $callId');
      print('[WebRTC] chatId: $chatId');

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

      print('[WebRTC] 📢 Отправляем уведомление в UI (calling)');
      _safeAddToCallState(_currentCall);

      await _initializeMediaStreams(callType == 'video');
      await _createPeerConnection();

      final offer = await _peerConnection!.createOffer(_constraints);
      await _peerConnection!.setLocalDescription(offer);

      print('[WebRTC] 📤 Отправляем offer через WebSocket');
      WebSocketManager.instance.sendCallOffer(
        callId,
        chatId,
        callType,
        offer.toMap(),
        receiverId,
      );

      print('[WebRTC] ✅ Offer отправлен');
      print('[WebRTC] ========================================');
    } catch (e, stackTrace) {
      print('[WebRTC] ❌ Ошибка начала звонка: $e');
      print('[WebRTC] Stack trace: $stackTrace');
      await endCall('error');
      rethrow;
    }
  }

  Future<void> _initializeMediaStreams(bool video) async {
    try {
      print('[WebRTC] 🎥 Инициализация медиа стримов (видео: $video)');

      final Map<String, dynamic> mediaConstraints = {
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

      _localStream =
          await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _safeAddToLocalStream(_localStream);

      print('[WebRTC] ✅ Локальный стрим создан');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка получения медиа: $e');
      throw e;
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      print('[WebRTC] 🔗 Создание peer connection');

      _peerConnection = await createPeerConnection(_iceServers);

      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('[WebRTC] 🧊 Новый ICE кандидат');
        if (_currentCall != null) {
          WebSocketManager.instance.sendIceCandidate(
            _currentCall!.id,
            candidate.toMap(),
          );
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('[WebRTC] 📺 Получен удаленный трек');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams.first;
          _safeAddToRemoteStream(_remoteStream);
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('[WebRTC] 🔌 Состояние соединения: $state');

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          if (_currentCall != null) {
            _currentCall = _currentCall!.copyWith(status: CallStatus.active);
            _safeAddToCallState(_currentCall);
          }
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          endCall('connection_lost');
        }
      };

      print('[WebRTC] ✅ Peer connection создан');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка создания peer connection: $e');
      throw e;
    }
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> message) async {
    try {
      print('[WebRTC] ========================================');
      print('[WebRTC] 📞📞📞 ВХОДЯЩИЙ ЗВОНОК!');
      print('[WebRTC] ========================================');
      print('[WebRTC] Полные данные: $message');

      final callId = message['callId'] as String?;
      final chatId = message['chatId'] as String?;
      final callerId = message['callerId'] as String?;
      final callerName = message['callerName'] as String?;
      final callType = message['callType'] as String?;
      final offer = message['offer'] as Map<String, dynamic>?;

      print('[WebRTC] ========================================');
      print('[WebRTC] 📋 Параметры входящего звонка:');
      print('[WebRTC]   - callId: $callId');
      print('[WebRTC]   - chatId: $chatId');
      print('[WebRTC]   - callerId: $callerId');
      print('[WebRTC]   - callerName: $callerName');
      print('[WebRTC]   - callType: $callType');
      print('[WebRTC]   - offer: ${offer != null ? "ЕСТЬ ✅" : "НЕТ ❌"}');

      if (offer != null) {
        print(
            '[WebRTC]   - offer.sdp: ${offer['sdp'] != null ? "ЕСТЬ" : "НЕТ"}');
        print('[WebRTC]   - offer.type: ${offer['type']}');
        if (offer['sdp'] != null) {
          print('[WebRTC]   - offer.sdp size: ${offer['sdp'].length} bytes');
        }
      }
      print('[WebRTC] ========================================');

      // Валидация
      if (callId == null ||
          chatId == null ||
          callerId == null ||
          offer == null) {
        print('[WebRTC] ❌ КРИТИЧЕСКАЯ ОШИБКА: Недостаточно данных!');
        print('[WebRTC]   Missing:');
        if (callId == null) print('[WebRTC]   - callId');
        if (chatId == null) print('[WebRTC]   - chatId');
        if (callerId == null) print('[WebRTC]   - callerId');
        if (offer == null) print('[WebRTC]   - offer');
        print('[WebRTC] ========================================');
        return;
      }

      // ⭐⭐⭐ КРИТИЧНО: Сохраняем offer для использования при ответе
      _pendingOffer = offer;
      print('[WebRTC] ========================================');
      print('[WebRTC] ✅✅✅ OFFER СОХРАНЕН В _pendingOffer!');
      print('[WebRTC] SDP size: ${offer['sdp']?.length ?? 0} bytes');
      print('[WebRTC] ========================================');

      // Создаем объект Call для входящего звонка
      _currentCall = Call(
        id: callId,
        chatId: chatId,
        callerId: callerId,
        callerName: callerName ?? 'Неизвестный',
        receiverId: _currentUserId!,
        receiverName: 'Вы',
        callType: callType ?? 'audio',
        status: CallStatus.incoming,
        startTime: DateTime.now(),
      );

      print('[WebRTC] ========================================');
      print('[WebRTC] ✅ ОБЪЕКТ CALL СОЗДАН');
      print('[WebRTC] ========================================');
      print('[WebRTC]   - ID: ${_currentCall!.id}');
      print('[WebRTC]   - Status: ${_currentCall!.status}');
      print('[WebRTC]   - CallerName: ${_currentCall!.callerName}');
      print('[WebRTC]   - CallType: ${_currentCall!.callType}');
      print('[WebRTC] ========================================');

      // Запускаем CallActivity через нативный метод
      print('[WebRTC] 🚀🚀🚀 ЗАПУСКАЕМ CallActivity через нативный метод!');
      try {
        await platform.invokeMethod('showCallScreen', {
          'callId': callId,
          'callerName': callerName ?? 'Неизвестный',
          'callType': callType ?? 'audio',
        });
        print('[WebRTC] ✅ showCallScreen вызван успешно!');
      } catch (e) {
        print('[WebRTC] ❌ Ошибка вызова showCallScreen: $e');
        print('[WebRTC] Stack trace: ${StackTrace.current}');
      }

      // Уведомляем UI о входящем звонке (для fallback)
      print('[WebRTC] 📢 ОТПРАВЛЯЕМ УВЕДОМЛЕНИЕ В UI!');
      _safeAddToCallState(_currentCall);

      print('[WebRTC] ========================================');
      print('[WebRTC] ✅ _handleIncomingCall ЗАВЕРШЕН');
      print('[WebRTC] ========================================');
    } catch (e, stackTrace) {
      print('[WebRTC] ========================================');
      print('[WebRTC] ❌❌❌ КРИТИЧЕСКАЯ ОШИБКА в _handleIncomingCall!');
      print('[WebRTC] Ошибка: $e');
      print('[WebRTC] Stack trace: $stackTrace');
      print('[WebRTC] ========================================');
    }
  }

  // ⭐⭐⭐ ИСПРАВЛЕНО: Используем УЖЕ СОХРАНЕННЫЙ offer из WebSocket
  Future<void> answerCall(String callId) async {
    try {
      print('[WebRTC] ========================================');
      print('[WebRTC] 📞 answerCall() вызван');
      print('[WebRTC]   - callId: $callId');
      print('[WebRTC]   - _isAnswering: $_isAnswering');
      print('[WebRTC]   - _currentCall: ${_currentCall?.id}');
      print(
          '[WebRTC]   - _pendingOffer: ${_pendingOffer != null ? "ЕСТЬ ✅" : "НЕТ ❌"}');
      print('[WebRTC] ========================================');

      // Проверяем что не выполняется уже
      if (_isAnswering) {
        print(
            '[WebRTC] ⚠️ answerCall уже выполняется, пропускаем повторный вызов');
        return;
      }

      _isAnswering = true;

      // КРИТИЧНО: Звонок и offer ДОЛЖНЫ быть уже сохранены в _handleIncomingCall!
      if (_currentCall == null || _currentCall!.id != callId) {
        print('[WebRTC] ❌ Звонок не найден!');
        print('[WebRTC]   _currentCall: ${_currentCall?.id}');
        print('[WebRTC]   callId: $callId');
        _isAnswering = false;
        return;
      }

      if (_pendingOffer == null) {
        print('[WebRTC] ========================================');
        print('[WebRTC] ❌❌❌ КРИТИЧЕСКАЯ ОШИБКА: Нет сохраненного offer!');
        print(
            '[WebRTC] Это значит что call_offer НЕ БЫЛ получен через WebSocket!');
        print(
            '[WebRTC] Проверьте что сервер отправляет pending call_offer при подключении!');
        print('[WebRTC] ========================================');
        _isAnswering = false;
        return;
      }

      print('[WebRTC] ========================================');
      print('[WebRTC] ✅✅✅ ОТВЕЧАЕМ НА ЗВОНОК!');
      print('[WebRTC] ========================================');
      print('[WebRTC] CallId: $callId');
      print(
          '[WebRTC] Offer SDP size: ${_pendingOffer!['sdp']?.length ?? 0} bytes');

      _currentCall = _currentCall!.copyWith(status: CallStatus.connecting);
      _safeAddToCallState(_currentCall);

      await _initializeMediaStreams(_currentCall!.callType == 'video');
      await _createPeerConnection();

      print('[WebRTC] 📥 Устанавливаем remote description из offer');
      final offer = RTCSessionDescription(
        _pendingOffer!['sdp'],
        _pendingOffer!['type'],
      );
      await _peerConnection!.setRemoteDescription(offer);
      _isRemoteDescriptionSet = true;
      print('[WebRTC] ✅ Remote description установлен');

      await _processIceCandidatesQueue();

      print('[WebRTC] 📤 Создаем answer');
      final answer = await _peerConnection!.createAnswer(_constraints);
      await _peerConnection!.setLocalDescription(answer);

      print('[WebRTC] 📤 Отправляем answer через WebSocket');
      WebSocketManager.instance.sendCallAnswer(callId, answer.toMap());

      print('[WebRTC] ========================================');
      print('[WebRTC] ✅✅✅ ANSWER ОТПРАВЛЕН УСПЕШНО!');
      print('[WebRTC] ========================================');

      _isAnswering = false;
    } catch (e, stackTrace) {
      print('[WebRTC] ========================================');
      print('[WebRTC] ❌❌❌ ОШИБКА ответа на звонок!');
      print('[WebRTC] Ошибка: $e');
      print('[WebRTC] Stack trace: $stackTrace');
      print('[WebRTC] ========================================');

      _isAnswering = false;

      await endCall('error');
    }
  }

  Future<void> _handleCallAnswer(Map<String, dynamic> message) async {
    try {
      print('[WebRTC] ========================================');
      print('[WebRTC] ✅ Получен answer');
      print('[WebRTC] ========================================');

      if (_peerConnection == null) {
        print('[WebRTC] ❌ Peer connection не существует');
        return;
      }

      final answer = RTCSessionDescription(
        message['answer']['sdp'],
        message['answer']['type'],
      );

      await _peerConnection!.setRemoteDescription(answer);
      _isRemoteDescriptionSet = true;

      await _processIceCandidatesQueue();

      if (_currentCall != null) {
        _currentCall = _currentCall!.copyWith(status: CallStatus.connecting);
        _safeAddToCallState(_currentCall);
      }

      print('[WebRTC] ✅ Answer обработан');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка обработки answer: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> message) async {
    try {
      print('[WebRTC] 🧊 Получен ICE кандидат');

      final candidate = RTCIceCandidate(
        message['candidate']['candidate'],
        message['candidate']['sdpMid'],
        message['candidate']['sdpMLineIndex'],
      );

      if (_peerConnection != null && _isRemoteDescriptionSet) {
        await _peerConnection!.addCandidate(candidate);
        print('[WebRTC] ✅ ICE кандидат добавлен');
      } else {
        _iceCandidatesQueue.add(candidate);
        print('[WebRTC] 📋 ICE кандидат добавлен в очередь');
      }
    } catch (e) {
      print('[WebRTC] ❌ Ошибка обработки ICE кандидата: $e');
    }
  }

  // ИСПРАВЛЕНО: Защита от concurrent modification
  Future<void> _processIceCandidatesQueue() async {
    if (_iceCandidatesQueue.isEmpty) return;

    print(
        '[WebRTC] 📋 Обработка очереди ICE кандидатов (${_iceCandidatesQueue.length})');

    // Создаем копию чтобы избежать concurrent modification
    final candidatesToProcess = List<RTCIceCandidate>.from(_iceCandidatesQueue);
    _iceCandidatesQueue.clear();

    for (final candidate in candidatesToProcess) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('[WebRTC] ❌ Ошибка добавления ICE кандидата из очереди: $e');
      }
    }

    print('[WebRTC] ✅ Очередь ICE кандидатов обработана');
  }

  void _handleCallEnded(Map<String, dynamic> message) {
    print('[WebRTC] ========================================');
    print('[WebRTC] 🔴 Звонок завершен: ${message['reason']}');
    print('[WebRTC] ========================================');

    _cleanup();

    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(
        status: CallStatus.ended,
        endTime: DateTime.now(),
      );
      _safeAddToCallState(_currentCall);

      Future.delayed(Duration(seconds: 2), () {
        _currentCall = null;
        _pendingOffer = null;
        _safeAddToCallState(null);
      });
    }
  }

  void _handleCallDeclined(Map<String, dynamic> message) {
    print('[WebRTC] ========================================');
    print('[WebRTC] ❌ Звонок отклонен');
    print('[WebRTC] ========================================');

    _cleanup();

    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(status: CallStatus.declined);
      _safeAddToCallState(_currentCall);

      Future.delayed(Duration(seconds: 2), () {
        _currentCall = null;
        _pendingOffer = null;
        _safeAddToCallState(null);
      });
    }
  }

  Future<void> declineCall(String callId) async {
    print('[WebRTC] ========================================');
    print('[WebRTC] ❌ Отклоняем звонок');
    print('[WebRTC] ========================================');

    if (_currentCall != null && _currentCall!.id == callId) {
      WebSocketManager.instance.declineCall(callId);
      _cleanup();

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
        print(
            '[WebRTC] 🎤 Микрофон: ${audioTrack.enabled ? "включен" : "выключен"}');
      }
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
        print(
            '[WebRTC] 📹 Видео: ${videoTrack.enabled ? "включено" : "выключено"}');
      }
    }
  }

  Future<void> toggleSpeaker() async {
    print('[WebRTC] 🔊 Переключение динамика');
  }

  Future<void> acceptCall(String callId) async {
    return answerCall(callId);
  }

  Future<void> endCall([String? reason]) async {
    print('[WebRTC] ========================================');
    print('[WebRTC] 🔴 Завершаем звонок: ${reason ?? 'user'}');
    print('[WebRTC] ========================================');

    if (_currentCall != null) {
      WebSocketManager.instance.endCall(_currentCall!.id, reason ?? 'user');
      _cleanup();

      _currentCall = _currentCall!.copyWith(
        status: CallStatus.ended,
        endTime: DateTime.now(),
      );
      _safeAddToCallState(_currentCall);

      Future.delayed(Duration(seconds: 2), () {
        _currentCall = null;
        _pendingOffer = null;
        _safeAddToCallState(null);
      });
    }
  }

  void _cleanup() {
    print('[WebRTC] 🧹 Очистка ресурсов');

    try {
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          try {
            track.stop();
          } catch (e) {
            print('[WebRTC] ⚠️ Ошибка остановки трека: $e');
          }
        });

        try {
          _localStream!.dispose();
        } catch (e) {
          print('[WebRTC] ⚠️ Ошибка dispose локального stream: $e');
        }
      }
    } catch (e) {
      print('[WebRTC] ⚠️ Ошибка при очистке локального stream: $e');
    }

    _localStream = null;
    _safeAddToLocalStream(null);

    _remoteStream = null;
    _safeAddToRemoteStream(null);

    try {
      if (_peerConnection != null) {
        _peerConnection!.close();
      }
    } catch (e) {
      print('[WebRTC] ⚠️ Ошибка при закрытии peer connection: $e');
    }

    _peerConnection = null;
    _iceCandidatesQueue.clear();
    _isRemoteDescriptionSet = false;

    print('[WebRTC] ✅ Очистка завершена');
  }

  void dispose() {
    print('[WebRTC] ========================================');
    print('[WebRTC] 🗑️ Dispose сервиса');
    print('[WebRTC] ========================================');

    _cleanup();

    try {
      _wsSubscription?.cancel();
    } catch (e) {
      print('[WebRTC] ⚠️ Ошибка отмены подписки WebSocket: $e');
    }

    try {
      _callStateController?.close();
    } catch (e) {
      print('[WebRTC] ⚠️ Ошибка закрытия callStateController: $e');
    }

    try {
      _localStreamController?.close();
    } catch (e) {
      print('[WebRTC] ⚠️ Ошибка закрытия localStreamController: $e');
    }

    try {
      _remoteStreamController?.close();
    } catch (e) {
      print('[WebRTC] ⚠️ Ошибка закрытия remoteStreamController: $e');
    }

    _callStateController = null;
    _localStreamController = null;
    _remoteStreamController = null;
    _currentCall = null;
    _pendingOffer = null;

    print('[WebRTC] ✅ Dispose завершен');
  }
}
