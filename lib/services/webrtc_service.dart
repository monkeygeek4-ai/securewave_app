// lib/services/webrtc_service.dart

import 'dart:async';
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

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentUserId;
  Call? _currentCall;

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
      print('[WebRTC] Инициализация для пользователя: $userId');

      if (_callStateController == null || _callStateController!.isClosed) {
        _initializeStreams();
      }

      print('[WebRTC] 🔌 Подписываемся на WebSocket сообщения...');
      _wsSubscription?.cancel();
      _wsSubscription =
          WebSocketManager.instance.messages.listen(_handleWebSocketMessage);

      print('[WebRTC] ✅ Сервис успешно инициализирован');
      print('[WebRTC] ✅ Подписка на WebSocket активна');
      print('[WebRTC] 🌐 TURN сервер: securewave.sbk-19.ru:3478');
      print('[WebRTC] ========================================');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка инициализации: $e');
      throw e;
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    print('[WebRTC] ========================================');
    print('[WebRTC] 📨 Получено WebSocket сообщение: ${message['type']}');
    print('[WebRTC] Данные: $message');
    print('[WebRTC] ========================================');

    switch (message['type']) {
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
      default:
        // ИСПРАВЛЕНО: Логируем сообщения, которые не относятся к звонкам
        // Эти сообщения должны обрабатываться ChatProvider
        print('[WebRTC] ⚠️ Неизвестный тип сообщения: ${message['type']}');
        print('[WebRTC] (Это сообщение должно обработать ChatProvider)');
        break;
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
      print('[WebRTC] ========================================');
      print('[WebRTC] 📞 Начинаем звонок');
      print('[WebRTC] Тип: $callType');
      print('[WebRTC] Кому: $receiverName (ID: $receiverId)');
      print('[WebRTC] callId: $callId');
      print('[WebRTC] chatId: $chatId');
      print('[WebRTC] ========================================');

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
    } catch (e) {
      print('[WebRTC] ❌ Ошибка начала звонка: $e');
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
      print('[WebRTC] 📞 Входящий звонок');
      print(
          '[WebRTC] От: ${message['callerName']} (ID: ${message['callerId']})');
      print('[WebRTC] Тип: ${message['callType']}');
      print('[WebRTC] ========================================');

      _currentCall = Call(
        id: message['callId'],
        chatId: message['chatId'],
        callerId: message['callerId'],
        callerName: message['callerName'] ?? 'Неизвестный',
        receiverId: _currentUserId!,
        receiverName: 'Вы',
        callType: message['callType'] ?? 'audio',
        status: CallStatus.incoming,
        startTime: DateTime.now(),
      );

      _safeAddToCallState(_currentCall);

      _currentCall = _currentCall!.copyWith(
        offer: message['offer'],
      );

      print('[WebRTC] ✅ Входящий звонок обработан');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка обработки входящего звонка: $e');
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      if (_currentCall == null || _currentCall!.id != callId) {
        print('[WebRTC] ❌ Звонок не найден');
        return;
      }

      print('[WebRTC] ========================================');
      print('[WebRTC] ✅ Отвечаем на звонок');
      print('[WebRTC] ========================================');

      _currentCall = _currentCall!.copyWith(status: CallStatus.connecting);
      _safeAddToCallState(_currentCall);

      await _initializeMediaStreams(_currentCall!.callType == 'video');
      await _createPeerConnection();

      final offer = RTCSessionDescription(
        _currentCall!.offer!['sdp'],
        _currentCall!.offer!['type'],
      );
      await _peerConnection!.setRemoteDescription(offer);
      _isRemoteDescriptionSet = true;

      await _processIceCandidatesQueue();

      final answer = await _peerConnection!.createAnswer(_constraints);
      await _peerConnection!.setLocalDescription(answer);

      WebSocketManager.instance.sendCallAnswer(callId, answer.toMap());

      print('[WebRTC] ✅ Answer отправлен');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка ответа на звонок: $e');
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

  Future<void> _processIceCandidatesQueue() async {
    if (_iceCandidatesQueue.isEmpty) return;

    print(
        '[WebRTC] 📋 Обработка очереди ICE кандидатов (${_iceCandidatesQueue.length})');

    for (final candidate in _iceCandidatesQueue) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('[WebRTC] ❌ Ошибка добавления ICE кандидата из очереди: $e');
      }
    }

    _iceCandidatesQueue.clear();
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
    print('[WebRTC] 🔊 Переключение динамика (недоступно в веб-версии)');
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
        _safeAddToCallState(null);
      });
    }
  }

  void _cleanup() {
    print('[WebRTC] 🧹 Очистка ресурсов');

    // Очистка локального стрима с обработкой ошибок
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

    // Очистка удаленного стрима
    _remoteStream = null;
    _safeAddToRemoteStream(null);

    // Закрытие peer connection с обработкой ошибок
    try {
      if (_peerConnection != null) {
        _peerConnection!.close();
      }
    } catch (e) {
      print('[WebRTC] ⚠️ Ошибка при закрытии peer connection: $e');
    }

    _peerConnection = null;

    // Очистка очереди и флагов
    _iceCandidatesQueue.clear();
    _isRemoteDescriptionSet = false;

    print('[WebRTC] ✅ Очистка завершена');
  }

  void dispose() {
    print('[WebRTC] ========================================');
    print('[WebRTC] 🗑️ Dispose сервиса');
    print('[WebRTC] ========================================');

    // Очищаем ресурсы
    _cleanup();

    // Отменяем подписку на WebSocket
    try {
      _wsSubscription?.cancel();
    } catch (e) {
      print('[WebRTC] ⚠️ Ошибка отмены подписки WebSocket: $e');
    }

    // Закрываем контроллеры стримов
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

    // Обнуляем контроллеры
    _callStateController = null;
    _localStreamController = null;
    _remoteStreamController = null;

    // Обнуляем текущий звонок
    _currentCall = null;

    print('[WebRTC] ✅ Dispose завершен');
  }
}
