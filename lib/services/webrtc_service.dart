// lib/services/webrtc_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // Peer connections
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // User info
  String? _currentUserId;

  // Call state
  Call? _currentCall;

  // Stream controllers
  StreamController<Call?>? _callStateController;
  StreamController<MediaStream?>? _localStreamController;
  StreamController<MediaStream?>? _remoteStreamController;

  // Public streams
  Stream<Call?> get callState => _callStateController?.stream ?? Stream.empty();
  Stream<MediaStream?> get localStream =>
      _localStreamController?.stream ?? Stream.empty();
  Stream<MediaStream?> get remoteStream =>
      _remoteStreamController?.stream ?? Stream.empty();

  // WebSocket subscription
  StreamSubscription? _wsSubscription;

  // Ice candidates queue
  final List<RTCIceCandidate> _iceCandidatesQueue = [];
  bool _isRemoteDescriptionSet = false;

  // Configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
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

      print('[WebRTC] Инициализация для пользователя: $userId');

      if (_callStateController == null || _callStateController!.isClosed) {
        _initializeStreams();
      }

      _wsSubscription?.cancel();

      _wsSubscription =
          WebSocketManager.instance.messages.listen(_handleWebSocketMessage);

      print('[WebRTC] Сервис успешно инициализирован');
    } catch (e) {
      print('[WebRTC] Ошибка инициализации: $e');
      throw e;
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    print('[WebRTC] Получено сообщение: ${message['type']}');

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
      print('[WebRTC] Начинаем звонок: $callType с $receiverName');
      print('[WebRTC] callId: $callId');
      print('[WebRTC] chatId: $chatId');
      print('[WebRTC] receiverId: $receiverId');

      // Создаем новый звонок
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

      // Инициализируем медиа стримы
      await _initializeMediaStreams(callType == 'video');

      // Создаем peer connection
      await _createPeerConnection();

      // Создаем и отправляем offer
      final offer = await _peerConnection!.createOffer(_constraints);
      await _peerConnection!.setLocalDescription(offer);

      // ✅ ИСПРАВЛЕНО: передаем receiverId
      print('[WebRTC] Отправляем offer через WebSocket');
      WebSocketManager.instance.sendCallOffer(
        callId,
        chatId,
        callType,
        offer.toMap(),
        receiverId, // Добавили этот параметр
      );

      print('[WebRTC] Offer отправлен');
    } catch (e) {
      print('[WebRTC] Ошибка начала звонка: $e');
      await endCall('error');
      rethrow;
    }
  }

  Future<void> _initializeMediaStreams(bool video) async {
    try {
      print('[WebRTC] Инициализация медиа стримов (видео: $video)');

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

      print('[WebRTC] Локальный стрим создан');
    } catch (e) {
      print('[WebRTC] Ошибка получения медиа: $e');
      throw e;
    }
  }

  Future<void> _createPeerConnection() async {
    try {
      print('[WebRTC] Создание peer connection');

      _peerConnection = await createPeerConnection(_iceServers);

      // Добавляем локальные треки
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }

      // Обработчики событий
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('[WebRTC] Новый ICE кандидат');
        if (_currentCall != null) {
          WebSocketManager.instance.sendIceCandidate(
            _currentCall!.id,
            candidate.toMap(),
          );
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('[WebRTC] Получен удаленный трек');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams.first;
          _safeAddToRemoteStream(_remoteStream);
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('[WebRTC] Состояние соединения: $state');

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

      print('[WebRTC] Peer connection создан');
    } catch (e) {
      print('[WebRTC] Ошибка создания peer connection: $e');
      throw e;
    }
  }

  Future<void> _handleIncomingCall(Map<String, dynamic> message) async {
    try {
      print('[WebRTC] Входящий звонок');

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
    } catch (e) {
      print('[WebRTC] Ошибка обработки входящего звонка: $e');
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      if (_currentCall == null || _currentCall!.id != callId) {
        print('[WebRTC] Звонок не найден');
        return;
      }

      print('[WebRTC] Отвечаем на звонок');

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

      print('[WebRTC] Answer отправлен');
    } catch (e) {
      print('[WebRTC] Ошибка ответа на звонок: $e');
      await endCall('error');
    }
  }

  Future<void> _handleCallAnswer(Map<String, dynamic> message) async {
    try {
      print('[WebRTC] Получен answer');

      if (_peerConnection == null) {
        print('[WebRTC] Peer connection не существует');
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
    } catch (e) {
      print('[WebRTC] Ошибка обработки answer: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> message) async {
    try {
      print('[WebRTC] Получен ICE кандидат');

      final candidate = RTCIceCandidate(
        message['candidate']['candidate'],
        message['candidate']['sdpMid'],
        message['candidate']['sdpMLineIndex'],
      );

      if (_peerConnection != null && _isRemoteDescriptionSet) {
        await _peerConnection!.addCandidate(candidate);
      } else {
        _iceCandidatesQueue.add(candidate);
        print('[WebRTC] ICE кандидат добавлен в очередь');
      }
    } catch (e) {
      print('[WebRTC] Ошибка обработки ICE кандидата: $e');
    }
  }

  Future<void> _processIceCandidatesQueue() async {
    if (_iceCandidatesQueue.isEmpty) return;

    print(
        '[WebRTC] Обработка очереди ICE кандидатов (${_iceCandidatesQueue.length})');

    for (final candidate in _iceCandidatesQueue) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        print('[WebRTC] Ошибка добавления ICE кандидата из очереди: $e');
      }
    }

    _iceCandidatesQueue.clear();
  }

  void _handleCallEnded(Map<String, dynamic> message) {
    print('[WebRTC] Звонок завершен: ${message['reason']}');
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
    print('[WebRTC] Звонок отклонен');
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
    print('[WebRTC] Отклоняем звонок');

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
            '[WebRTC] Микрофон: ${audioTrack.enabled ? "включен" : "выключен"}');
      }
    }
  }

  Future<void> toggleVideo() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
        print(
            '[WebRTC] Видео: ${videoTrack.enabled ? "включено" : "выключено"}');
      }
    }
  }

  Future<void> toggleSpeaker() async {
    print('[WebRTC] Переключение динамика (недоступно в веб-версии)');
  }

  Future<void> acceptCall(String callId) async {
    return answerCall(callId);
  }

  Future<void> endCall([String? reason]) async {
    print('[WebRTC] Завершаем звонок: ${reason ?? 'user'}');

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
    print('[WebRTC] Очистка ресурсов');

    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream?.dispose();
    _localStream = null;
    _safeAddToLocalStream(null);

    _remoteStream = null;
    _safeAddToRemoteStream(null);

    _peerConnection?.close();
    _peerConnection = null;

    _iceCandidatesQueue.clear();
    _isRemoteDescriptionSet = false;
  }

  void dispose() {
    print('[WebRTC] Dispose');
    _cleanup();
    _wsSubscription?.cancel();

    _callStateController?.close();
    _localStreamController?.close();
    _remoteStreamController?.close();

    _callStateController = null;
    _localStreamController = null;
    _remoteStreamController = null;

    _currentCall = null;
  }
}
