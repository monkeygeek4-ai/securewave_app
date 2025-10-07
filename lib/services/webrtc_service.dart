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
      {'urls': 'stun:securewave.sbk-19.ru:3478'},
      {
        'urls': 'turn:securewave.sbk-19.ru:3478?transport=udp',
        'username': 'user',
        'credential': 'VerySecureRandomKey123ChangeThis'
      },
      {
        'urls': 'turn:securewave.sbk-19.ru:3478?transport=tcp',
        'username': 'user',
        'credential': 'VerySecureRandomKey123ChangeThis'
      },
      {
        'urls': 'turns:securewave.sbk-19.ru:5349?transport=tcp',
        'username': 'user',
        'credential': 'VerySecureRandomKey123ChangeThis'
      }
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
      print('[WebRTC] 📢 CallState обновлен: ${call?.status}');
    } else {
      print('[WebRTC] ⚠️ CallStateController закрыт или null!');
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

  bool get isReady {
    final ready = _callStateController != null &&
        !_callStateController!.isClosed &&
        _currentCall == null &&
        _peerConnection == null;

    print('[WebRTC] 🔍 Проверка готовности: $ready');
    if (!ready) {
      print(
          '[WebRTC]   - Controller: ${_callStateController != null ? "OK" : "NULL"}');
      print('[WebRTC]   - Closed: ${_callStateController?.isClosed ?? true}');
      print(
          '[WebRTC]   - Current call: ${_currentCall == null ? "NONE" : "EXISTS"}');
      print(
          '[WebRTC]   - Peer connection: ${_peerConnection == null ? "NONE" : "EXISTS"}');
    }

    return ready;
  }

  Future<void> initialize(String userId) async {
    try {
      _currentUserId = userId;
      print('[WebRTC] ========================================');
      print('[WebRTC] Инициализация для пользователя: $userId');

      // Проверяем, не осталось ли что-то от предыдущего звонка
      if (_peerConnection != null || _localStream != null) {
        print('[WebRTC] ⚠️ Обнаружены остатки предыдущего звонка, очищаем');
        _cleanup();
      }

      // Всегда переинициализируем stream controllers
      print('[WebRTC] 🔄 Переинициализация stream controllers');
      _initializeStreams();

      _wsSubscription?.cancel();

      print('[WebRTC] 🔌 Подписываемся на WebSocket сообщения...');
      _wsSubscription = WebSocketManager.instance.messages.listen(
        _handleWebSocketMessage,
        onError: (error) {
          print('[WebRTC] ❌ Ошибка WebSocket подписки: $error');
        },
        cancelOnError: false, // Не отменять подписку при ошибках
      );

      print('[WebRTC] ✅ Сервис успешно инициализирован');
      print('[WebRTC] ✅ Подписка на WebSocket активна');
      print('[WebRTC] 🌐 TURN сервер: securewave.sbk-19.ru:3478');
      print('[WebRTC] ========================================');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка инициализации: $e');
      rethrow;
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    print('[WebRTC] ========================================');
    print('[WebRTC] 📨 Получено WebSocket сообщение: ${message['type']}');
    print('[WebRTC] Данные: $message');
    print('[WebRTC] ========================================');

    switch (message['type']) {
      case 'call_offer':
        print('[WebRTC] 📞 Обработка входящего звонка');
        _handleIncomingCall(message);
        break;
      case 'call_answer':
        print('[WebRTC] 📞 Получен call_answer от получателя');
        _handleCallAnswer(message);
        break;
      case 'call_ice_candidate':
        print('[WebRTC] 🧊 Получен ICE кандидат');
        _handleIceCandidate(message);
        break;
      case 'call_ended':
      case 'call_end':
        print('[WebRTC] 📞 Звонок завершен');
        _handleCallEnded(message);
        break;
      case 'call_declined':
      case 'call_decline':
        print('[WebRTC] 📞 Звонок отклонен');
        _handleCallDeclined(message);
        break;
      default:
        print('[WebRTC] ⚠️ Неизвестный тип сообщения: ${message['type']}');
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
      // Проверка готовности
      if (!isReady) {
        print(
            '[WebRTC] ⚠️ Сервис не готов к новому звонку, переинициализируем');
        await initialize(_currentUserId!);
        await Future.delayed(Duration(milliseconds: 500));
      }

      print('[WebRTC] ========================================');
      print('[WebRTC] 📞 Начинаем звонок: $callType с $receiverName');
      print('[WebRTC] callId: $callId');
      print('[WebRTC] chatId: $chatId');
      print('[WebRTC] receiverId: $receiverId');
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

      print('[WebRTC] ✅ Offer отправлен, ожидаем answer...');

      Timer(Duration(seconds: 15), () {
        if (_currentCall != null &&
            (_currentCall!.status == CallStatus.calling ||
                _currentCall!.status == CallStatus.connecting)) {
          print('[WebRTC] ⚠️ ВНИМАНИЕ: Соединение не установилось за 15 сек');
          print('[WebRTC] Текущий статус: ${_currentCall!.status}');
          print('[WebRTC] Проверьте: получен ли call_answer от получателя');
        }
      });
    } catch (e) {
      print('[WebRTC] ❌ Ошибка начала звонка: $e');
      await endCall('error');
      rethrow;
    }
  }

  Future<void> _initializeMediaStreams(bool video) async {
    try {
      print('[WebRTC] 🎤 Инициализация медиа стримов (видео: $video)');

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
      print('[WebRTC] 🌐 Используем TURN сервер: securewave.sbk-19.ru');
      print(
          '[WebRTC] 📊 ICE серверы: ${_iceServers['iceServers'].length} конфигураций');

      _peerConnection = await createPeerConnection(_iceServers);

      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        final candidateStr = candidate.candidate ?? '';
        print('[WebRTC] 🧊 Новый ICE кандидат: $candidateStr');

        if (candidateStr.contains('typ relay')) {
          print(
              '[WebRTC] ✅ RELAY кандидат через TURN! IP: ${candidateStr.split(' ')[4]}');
        } else if (candidateStr.contains('typ srflx')) {
          print(
              '[WebRTC] ✅ SRFLX кандидат через STUN! IP: ${candidateStr.split(' ')[4]}');
        } else if (candidateStr.contains('typ host')) {
          print('[WebRTC] 📍 HOST кандидат (локальный)');
        }

        if (_currentCall != null) {
          WebSocketManager.instance.sendIceCandidate(
            _currentCall!.id,
            candidate.toMap(),
          );
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        print('[WebRTC] 🎬 Получен удаленный трек!');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams.first;
          _safeAddToRemoteStream(_remoteStream);
          print('[WebRTC] ✅ Удаленный стрим добавлен');
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('[WebRTC] 🔗 Состояние соединения: $state');

        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          print('[WebRTC] ✅ УСПЕХ! Соединение установлено!');
          if (_currentCall != null) {
            _currentCall = _currentCall!.copyWith(status: CallStatus.active);
            _safeAddToCallState(_currentCall);
          }
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          print('[WebRTC] ❌ ОШИБКА! Соединение не удалось');
          endCall('connection_failed');
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          print('[WebRTC] 🔌 Соединение разорвано');
          endCall('connection_lost');
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('[WebRTC] 🧊 ICE состояние: $state');

        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          print('[WebRTC] ✅ ICE соединение установлено!');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          print('[WebRTC] ❌ ICE соединение провалилось!');
        } else if (state ==
            RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
          print('[WebRTC] 🔌 ICE соединение разорвано');
        }
      };

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        print('[WebRTC] 🧊 ICE gathering: $state');

        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          print('[WebRTC] ✅ Все ICE кандидаты собраны');
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
      print('[WebRTC] 📞 ВХОДЯЩИЙ ЗВОНОК!');
      print('[WebRTC] От: ${message['callerName']}');
      print('[WebRTC] CallId: ${message['callId']}');
      print('[WebRTC] ChatId: ${message['chatId']}');
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

      print('[WebRTC] 📢 Отправка входящего звонка в callState stream');
      _safeAddToCallState(_currentCall);

      _currentCall = _currentCall!.copyWith(
        offer: message['offer'],
      );

      print(
          '[WebRTC] ✅ Звонок добавлен в состояние, ожидаем ответ пользователя');
      print('[WebRTC] ========================================');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка обработки входящего звонка: $e');
      print('[WebRTC] Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> answerCall(String callId) async {
    try {
      if (_currentCall == null || _currentCall!.id != callId) {
        print('[WebRTC] ❌ Звонок не найден');
        return;
      }

      print('[WebRTC] ========================================');
      print('[WebRTC] 📞 Отвечаем на звонок $callId');
      print('[WebRTC] ========================================');

      _currentCall = _currentCall!.copyWith(status: CallStatus.connecting);
      _safeAddToCallState(_currentCall);

      await _initializeMediaStreams(_currentCall!.callType == 'video');
      await _createPeerConnection();

      final offer = RTCSessionDescription(
        _currentCall!.offer!['sdp'],
        _currentCall!.offer!['type'],
      );

      print('[WebRTC] 📝 Устанавливаем remote description (offer)');
      await _peerConnection!.setRemoteDescription(offer);
      _isRemoteDescriptionSet = true;

      await _processIceCandidatesQueue();

      print('[WebRTC] 📝 Создаём answer');
      final answer = await _peerConnection!.createAnswer(_constraints);
      await _peerConnection!.setLocalDescription(answer);

      print('[WebRTC] 📤 Отправляем answer звонящему');
      WebSocketManager.instance.sendCallAnswer(callId, answer.toMap());

      print('[WebRTC] ✅ Answer отправлен, ожидаем установки соединения');
      print('[WebRTC] ========================================');
    } catch (e) {
      print('[WebRTC] ❌ Ошибка ответа на звонок: $e');
      await endCall('error');
    }
  }

  Future<void> _handleCallAnswer(Map<String, dynamic> message) async {
    try {
      print('[WebRTC] ========================================');
      print('[WebRTC] 📝 Обрабатываем answer от получателя');
      print('[WebRTC] ========================================');

      if (_peerConnection == null) {
        print('[WebRTC] ❌ ОШИБКА: Peer connection не существует!');
        return;
      }

      final answer = RTCSessionDescription(
        message['answer']['sdp'],
        message['answer']['type'],
      );

      print('[WebRTC] 📝 Устанавливаем remote description (answer)');
      await _peerConnection!.setRemoteDescription(answer);
      _isRemoteDescriptionSet = true;

      print('[WebRTC] 🧊 Answer применен, обрабатываем очередь ICE кандидатов');
      await _processIceCandidatesQueue();

      if (_currentCall != null) {
        _currentCall = _currentCall!.copyWith(status: CallStatus.connecting);
        _safeAddToCallState(_currentCall);
      }

      print('[WebRTC] ✅ Answer обработан, ожидаем установки соединения');
      print('[WebRTC] ========================================');
    } catch (e) {
      print('[WebRTC] ❌ ОШИБКА обработки answer: $e');
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> message) async {
    try {
      final candidateData = message['candidate'];
      print('[WebRTC] 🧊 Получен ICE кандидат от удаленного peer');

      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      if (_peerConnection != null && _isRemoteDescriptionSet) {
        await _peerConnection!.addCandidate(candidate);
        print('[WebRTC] ✅ ICE кандидат добавлен');
      } else {
        _iceCandidatesQueue.add(candidate);
        print(
            '[WebRTC] 📋 ICE кандидат добавлен в очередь (remote description не установлен)');
      }
    } catch (e) {
      print('[WebRTC] ❌ Ошибка обработки ICE кандидата: $e');
    }
  }

  Future<void> _processIceCandidatesQueue() async {
    if (_iceCandidatesQueue.isEmpty) {
      print('[WebRTC] ℹ️ Очередь ICE кандидатов пуста');
      return;
    }

    print(
        '[WebRTC] 🧊 Обработка очереди ICE кандидатов (${_iceCandidatesQueue.length} шт.)');

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
    print('[WebRTC] 📞 Звонок завершен: ${message['reason']}');
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
    print('[WebRTC] 📞 Звонок отклонен');
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
    print('[WebRTC] 📞 Отклоняем звонок $callId');

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
    print('[WebRTC] 📞 Завершаем звонок: ${reason ?? 'user'}');
    print('[WebRTC] ========================================');

    if (_currentCall != null) {
      final callId = _currentCall!.id;

      // Отправляем сообщение о завершении
      WebSocketManager.instance.endCall(callId, reason ?? 'user');

      // Обновляем статус
      _currentCall = _currentCall!.copyWith(
        status: CallStatus.ended,
        endTime: DateTime.now(),
      );
      _safeAddToCallState(_currentCall);

      // Очищаем ресурсы
      _cleanup();

      // Сбрасываем состояние через 2 секунды
      await Future.delayed(Duration(seconds: 2));
      _currentCall = null;
      _safeAddToCallState(null);

      print('[WebRTC] ✅ Звонок полностью завершен, готов к новому вызову');
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
    _isRemoteDescriptionSet = false; // КРИТИЧНО: Сброс флага!

    print('[WebRTC] ✅ Очистка завершена');
  }

  void dispose() {
    print('[WebRTC] 🗑️ Dispose сервиса');

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

    print('[WebRTC] ✅ Dispose завершен');
  }
}
