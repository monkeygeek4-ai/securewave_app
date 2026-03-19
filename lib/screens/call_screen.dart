// lib/screens/call_screen.dart
// ИСПРАВЛЕННАЯ ВЕРСИЯ - убрана ранняя проверка в initState

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/call.dart';
import '../models/message.dart';
import '../services/webrtc_service.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/web_audio.dart' as web_audio;
import '../utils/image_utils.dart';
import '../helpers/ios_callkit_handler.dart';

class CallScreen extends StatefulWidget {
  final Call? initialCall;
  final String? chatId;
  final String? receiverId;
  final String? receiverName;
  final String? receiverAvatar;
  final String? callType;
  final bool autoAccept;

  const CallScreen({
    super.key,
    this.initialCall,
    this.chatId,
    this.receiverId,
    this.receiverName,
    this.receiverAvatar,
    this.callType,
    this.autoAccept = false,
  });

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCService _webrtcService = WebRTCService.instance;
  static const audioChannel = MethodChannel('com.securewave.app/audio');

  Call? _currentCall;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = false;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;

  bool _isDisposing = false;
  bool _isEnding = false;
  bool _hasAutoAccepted = false;

  StreamSubscription? _callStateSubscription;
  StreamSubscription? _localStreamSubscription;
  StreamSubscription? _remoteStreamSubscription;

  final rtc.RTCVideoRenderer _localRenderer = rtc.RTCVideoRenderer();
  final rtc.RTCVideoRenderer _remoteRenderer = rtc.RTCVideoRenderer();
  web_audio.AudioElement? _remoteAudioElement;

  @override
  void initState() {
    super.initState();

    // print('[CallScreen] ========================================');
    // print('[CallScreen] 🚀 initState');
    // print('[CallScreen] autoAccept: ${widget.autoAccept}');
    // print('[CallScreen] initialCall: ${widget.initialCall?.id}');
    // print('[CallScreen] chatId: ${widget.chatId}');
    // print('[CallScreen] receiverId: ${widget.receiverId}');
    // print('[CallScreen] ========================================');

    _initRenderers();
    _listenToStreams();

    // ⭐⭐⭐ УБРАНА ЗАДЕРЖКА - вызываем сразу
    _initializeCall();
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      // print('[CallScreen] ✅ Рендереры инициализированы');

      if (kIsWeb) {
        _createWebAudioElement();
      }
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка инициализации: $e');
    }
  }

  void _createWebAudioElement() {
    if (!kIsWeb) return;

    try {
      // print('[CallScreen] 🌐 Создаем Web Audio Element');
      _remoteAudioElement = web_audio.AudioElement();
      _remoteAudioElement!.autoplay = true;
      _remoteAudioElement!.controls = false;
      _remoteAudioElement!.setAttribute('playsinline', 'true');
      _remoteAudioElement!.setAttribute('autoplay', 'true');
      _remoteAudioElement!.style.display = 'none';

      if (kIsWeb) {
        web_audio.document.body?.append(_remoteAudioElement!);
      }

      // print('[CallScreen] ✅ Audio элемент создан');
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка создания audio элемента: $e');
    }
  }

  void _initializeCall() {
    // print('[CallScreen] ═══════════════════════════════════');
    // print('[CallScreen] 🔧 Инициализация звонка');
    // print('[CallScreen] mounted: $mounted');
    // print('[CallScreen] _isDisposing: $_isDisposing');
    // print('[CallScreen] ═══════════════════════════════════');

    if (widget.initialCall != null) {
      // print('[CallScreen] 📞 Использую initialCall');
      // print('[CallScreen] 📞 initialCall.id: ${widget.initialCall!.id}');
      // print(         // '[CallScreen] 📞 initialCall.status: ${widget.initialCall!.status}');
      _currentCall = widget.initialCall;

      // print('[CallScreen] ========================================');
      // print('[CallScreen] 🔍 ПРОВЕРКА AUTO-ACCEPT:');
      // print('[CallScreen]   - widget.autoAccept: ${widget.autoAccept}');
      // print('[CallScreen]   - _currentCall?.status: ${_currentCall?.status}');
      // print('[CallScreen]   - CallStatus.incoming: ${CallStatus.incoming}');
      // print('[CallScreen]   - _hasAutoAccepted: $_hasAutoAccepted');
      // print('[CallScreen] ========================================');

      // ⭐⭐⭐ ИСПРАВЛЕНО: Для iOS проверяем, был ли звонок уже принят через CallKit
      // Если да, НЕ вызываем auto-accept в CallScreen, так как IOSCallKitHandler уже принял звонок
      bool shouldSkipAutoAccept = false;
      bool wasAcceptedViaCallKit = false;
      if (!kIsWeb && Platform.isIOS) {
        try {
          final iosCallKitHandler = IOSCallKitHandler();
          wasAcceptedViaCallKit = iosCallKitHandler.wasCallAcceptedViaCallKit(_currentCall?.id ?? '');
          if (wasAcceptedViaCallKit) {
            // print('[CallScreen] ========================================');
            // print('[CallScreen] ⚠️ Звонок уже принят через CallKit!');
            // print('[CallScreen] ⚠️ Пропускаем auto-accept в CallScreen');
            // print('[CallScreen] ⚠️ IOSCallKitHandler уже принял звонок');
            // print('[CallScreen] ========================================');
            shouldSkipAutoAccept = true;
            _hasAutoAccepted = true; // Помечаем как принятый, чтобы не пытаться принять снова
          } else {
            // ⭐⭐⭐ НОВОЕ: Проверяем, был ли CallKit показан для этого звонка
            // Если CallKit был показан, но звонок еще не принят, ждем принятия через CallKit
            final wasCallKitShown = iosCallKitHandler.wasCallKitShownForCall(_currentCall?.id ?? '');
            if (wasCallKitShown && _currentCall?.status == CallStatus.incoming) {
              // print('[CallScreen] ========================================');
              // print('[CallScreen] ⚠️ CallKit был показан, но звонок еще не принят');
              // print('[CallScreen] ⏳ Ждем принятия через CallKit...');
              // print('[CallScreen] ========================================');
              // Ждем до 5 секунд, чтобы пользователь принял звонок через CallKit
              int attempts = 0;
              Timer.periodic(const Duration(milliseconds: 200), (timer) {
                attempts++;
                final currentStatus = _webrtcService.currentCall?.status;
                if (currentStatus != CallStatus.incoming || attempts >= 25) {
                  timer.cancel();
                  if (currentStatus == CallStatus.incoming && attempts >= 25) {
                    // print('[CallScreen] ⚠️ Таймаут ожидания принятия через CallKit');
                    // print('[CallScreen] 🎯 Принимаем звонок вручную...');
                    if (mounted && !_isEnding && !_isDisposing) {
                      _acceptCall();
                    }
                  }
                }
              });
              shouldSkipAutoAccept = true;
            }
          }
        } catch (e) {
          // print('[CallScreen] ⚠️ Ошибка проверки CallKit accept: $e');
        }
      }

      // ⭐⭐⭐ АВТОПРИНЯТИЕ ЗВОНКА (только если не принят через CallKit)
      if (!shouldSkipAutoAccept &&
          widget.autoAccept &&
          _currentCall?.status == CallStatus.incoming &&
          !_hasAutoAccepted) {
        // print('[CallScreen] ========================================');
        // print('[CallScreen] 🎯🎯🎯 AUTO-ACCEPT TRIGGERED!');
        // print('[CallScreen] Автоматически принимаем звонок через 300ms...');
        // print('[CallScreen] ========================================');

        _hasAutoAccepted = true;

        Future.delayed(const Duration(milliseconds: 300), () {
          // print('[CallScreen] 🎯 300ms прошло, вызываем _acceptCall()');
          if (mounted && !_isEnding && !_isDisposing) {
            _acceptCall();
          } else {
            // print(               // '[CallScreen] ⚠️ НЕ вызываем _acceptCall(): mounted=$mounted, _isEnding=$_isEnding, _isDisposing=$_isDisposing');
          }
        });
      } else {
        // print('[CallScreen] ⚠️ AUTO-ACCEPT НЕ СРАБОТАЛ!');
        if (shouldSkipAutoAccept) {
          // print('[CallScreen]   Причина: звонок уже принят через CallKit');
        } else if (!widget.autoAccept) {
          // print('[CallScreen]   Причина: widget.autoAccept = FALSE');
        } else if (_currentCall?.status != CallStatus.incoming) {
          // print(             // '[CallScreen]   Причина: status = ${_currentCall?.status} (не incoming)');
        } else if (_hasAutoAccepted) {
          // print('[CallScreen]   Причина: уже был auto-accepted');
        }
        _syncSpeakerState();
      }
    } else {
      // print('[CallScreen] 📞 Создаю исходящий звонок');
      final callId = 'call-${DateTime.now().millisecondsSinceEpoch}';

      Future.delayed(const Duration(milliseconds: 500), () {
        _syncSpeakerState();
      });

      // ⭐⭐⭐ КРИТИЧНО: Проверяем и инициализируем WebRTC если нужно
      _ensureWebRTCInitialized().then((_) {
        if (mounted && !_isDisposing) {
          _webrtcService.startCall(
            callId: callId,
            chatId: widget.chatId!,
            receiverId: widget.receiverId!,
            receiverName: widget.receiverName ?? 'Неизвестный',
            callType: widget.callType ?? 'audio',
          );
        }
      }).catchError((error) {
        // print('[CallScreen] ❌ Ошибка инициализации WebRTC: $error');
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    // print('[CallScreen] ═══════════════════════════════════');
  }

  /// ⭐⭐⭐ НОВОЕ: Обеспечивает инициализацию WebRTC перед началом звонка
  Future<void> _ensureWebRTCInitialized() async {
    // print('[CallScreen] ========================================');
    // print('[CallScreen] 🔍 Проверка инициализации WebRTC');
    // print('[CallScreen] isInitialized: ${_webrtcService.isInitialized}');
    // print('[CallScreen] ========================================');

    if (_webrtcService.isInitialized) {
      // print('[CallScreen] ✅ WebRTC уже инициализирован');
      return;
    }

    // print('[CallScreen] ⚠️ WebRTC не инициализирован, инициализируем...');

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.currentUser == null) {
        throw Exception('Пользователь не авторизован');
      }

      final userId = authProvider.currentUser!.id.toString();
      // print('[CallScreen] 📝 User ID: $userId');

      await _webrtcService.initialize(userId);
      // print('[CallScreen] ✅ WebRTC успешно инициализирован');
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка инициализации WebRTC: $e');
      rethrow;
    }
  }

  Future<void> _syncSpeakerState() async {
    if (kIsWeb || !mounted) return;

    try {
      // print('[CallScreen] 🔄 Синхронизация состояния динамика');
      // ⭐⭐⭐ ИСПРАВЛЕНО: Используем правильное имя метода для iOS
      final bool speakerOn = (!kIsWeb && Platform.isIOS)
          ? await audioChannel.invokeMethod('isSpeakerEnabled') as bool
          : await audioChannel.invokeMethod('isSpeakerphoneOn') as bool;
      // print('[CallScreen] Android speakerphone: $speakerOn');

      if (mounted) {
        setState(() {
          _isSpeakerOn = speakerOn;
        });
        // print(           // '[CallScreen] ✅ UI обновлен: ${_isSpeakerOn ? "Speaker" : "Earpiece"}');
      }
    } catch (e) {
      // print('[CallScreen] ⚠️ Ошибка синхронизации: $e');
    }
  }

  void _listenToStreams() {
    // print('[CallScreen] 👂 Подписываемся на стримы');

    _callStateSubscription = _webrtcService.callState.listen((call) {
      if (_isDisposing || !mounted) {
        // print(           // '[CallScreen] ⚠️ Пропускаем CallState: disposing=$_isDisposing, mounted=$mounted');
        return;
      }

      // print(         // '[CallScreen] 🔔 CallState получен: ${call?.id}, status: ${call?.status}');

      setState(() {
        _currentCall = call;
      });

      // print('[CallScreen] ✅ setState вызван для CallState');

      if (call?.status == CallStatus.active) {
        // print('[CallScreen] 📞 Звонок активен - запускаем таймер');
        _startCallTimer();
        _syncSpeakerState();
      } else if (call?.status == CallStatus.ended ||
          call?.status == CallStatus.declined ||
          call?.status == CallStatus.failed) {
        // print('[CallScreen] 📞 Звонок завершён - вызываем _endCall()');
        _endCall();
      }
    });

    _localStreamSubscription = _webrtcService.localStream.listen((stream) {
      if (_isDisposing || !mounted || stream == null) return;

      // print('[CallScreen] 📹 Локальный stream получен');
      setState(() {
        _localRenderer.srcObject = stream;
      });
    });

    _remoteStreamSubscription = _webrtcService.remoteStream.listen((stream) {
      if (_isDisposing || !mounted || stream == null) return;

      // print('[CallScreen] ========================================');
      // print('[CallScreen] 🔊 УДАЛЕННЫЙ STREAM ПОЛУЧЕН!');
      // print('[CallScreen] Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
      // print('[CallScreen] Stream ID: ${stream.id}');
      // print('[CallScreen] Аудио треков: ${stream.getAudioTracks().length}');
      // print('[CallScreen] Видео треков: ${stream.getVideoTracks().length}');
      // print('[CallScreen] ========================================');

      setState(() {
        _remoteRenderer.srcObject = stream;
      });

      // ⭐⭐⭐ ИСПРАВЛЕНО: Временно отключаем Web audio элемент
      // RTCVideoView сам воспроизводит аудио, дополнительный audio элемент не нужен
      // и вызывает ошибку "The provided value is not of type MediaStream"
      // if (kIsWeb && _remoteAudioElement != null) {
      //   _attachStreamToAudioElement(stream);
      // }

      _checkAudioTracks(stream);
    });
  }

  // ⭐⭐⭐ УДАЛЕНО: Метод _attachStreamToAudioElement больше не используется
  // RTCVideoView сам воспроизводит аудио, дополнительный audio элемент не нужен
  // и вызывал ошибку "The provided value is not of type MediaStream"
  // void _attachStreamToAudioElement(rtc.MediaStream stream) { ... }

  void _checkAudioTracks(rtc.MediaStream stream) {
    try {
      final audioTracks = stream.getAudioTracks();
      // print('[CallScreen] 🔍 Проверка аудио треков: ${audioTracks.length}');

      for (var i = 0; i < audioTracks.length; i++) {
        final track = audioTracks[i];
        // print('[CallScreen] Трек $i: ${track.id}, Enabled: ${track.enabled}');

        if (!track.enabled) {
          // print('[CallScreen] ⚠️ Трек выключен, включаем!');
          track.enabled = true;
        }
      }
    } catch (e) {
      // print('[CallScreen] ⚠️ Ошибка проверки треков: $e');
    }
  }

  void _startCallTimer() {
    if (_isDisposing) return;

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposing) {
        timer.cancel();
        return;
      }
      setState(() {
        _callDuration = Duration(seconds: timer.tick);
      });
    });
  }

  void _toggleMute() {
    if (_isEnding || _isDisposing) return;

    setState(() {
      _isMuted = !_isMuted;
    });

    try {
      _webrtcService.toggleMute();
      // print('[CallScreen] 🎤 Микрофон: ${_isMuted ? "выкл" : "вкл"}');
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка toggleMute: $e');
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  void _toggleVideo() {
    if (_isEnding || _isDisposing) return;

    setState(() {
      _isVideoOff = !_isVideoOff;
    });

    try {
      _webrtcService.toggleVideo();
      // print('[CallScreen] 📹 Видео: ${_isVideoOff ? "выкл" : "вкл"}');
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка toggleVideo: $e');
      setState(() {
        _isVideoOff = !_isVideoOff;
      });
    }
  }

  void _toggleSpeaker() {
    if (_isEnding || _isDisposing) return;

    final newState = !_isSpeakerOn;
    // print('[CallScreen] 🔊 Переключение динамика: $_isSpeakerOn -> $newState');

    try {
      if (kIsWeb && _remoteAudioElement != null) {
        _remoteAudioElement!.volume = newState ? 1.0 : 0.5;
        setState(() {
          _isSpeakerOn = newState;
        });
        // print('[CallScreen] 🔊 Web громкость: ${_remoteAudioElement!.volume}');
      } else {
        // ⭐⭐⭐ ИСПРАВЛЕНО: Сначала переключаем, потом обновляем UI после задержки
        // Это гарантирует, что нативное переключение успеет примениться
        _webrtcService.toggleSpeaker().then((_) {
          // print('[CallScreen] ✅ Динамик переключен в WebRTC');
          // ⭐⭐⭐ КРИТИЧНО: Добавляем задержку перед синхронизацией состояния
          // Это дает время нативному коду применить переключение
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              _syncSpeakerState();
            }
          });
        }).catchError((e) {
          // print('[CallScreen] ❌ Ошибка toggleSpeaker: $e');
          if (mounted) {
            // Откатываем состояние UI при ошибке
            setState(() {
              _isSpeakerOn = !newState;
            });
          }
        });
      }
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка toggleSpeaker: $e');
      if (mounted) {
        setState(() {
          _isSpeakerOn = !newState;
        });
      }
    }
  }

  void _acceptCall() {
    if (_isEnding || _isDisposing) return;

    if (_currentCall != null) {
      // ⭐⭐⭐ ИСПРАВЛЕНО: Ослабляем проверку - позволяем принимать звонок
      // даже если статус уже не incoming (например, если CallKit уже перевёл в connecting)
      // Это гарантирует, что кнопка "принять" в CallScreen всегда работает
      if (_currentCall!.status == CallStatus.ended ||
          _currentCall!.status == CallStatus.declined ||
          _currentCall!.status == CallStatus.failed) {
        // print('[CallScreen] ========================================');
        // print('[CallScreen] ⚠️⚠️⚠️ Звонок уже завершён!');
        // print('[CallScreen] Текущий статус: ${_currentCall!.status}');
        // print('[CallScreen] Call ID: ${_currentCall!.id}');
        // print('[CallScreen] ⚠️ Пропускаем принятие завершённого звонка');
        // print('[CallScreen] ========================================');
        return;
      }
      
      // ⭐⭐⭐ Если звонок уже в connecting/active, всё равно вызываем acceptCall
      // для гарантии, что WebRTC правильно обработает звонок
      if (_currentCall!.status != CallStatus.incoming) {
        // print('[CallScreen] ========================================');
        // print('[CallScreen] ⚠️ Звонок уже в статусе: ${_currentCall!.status}');
        // print('[CallScreen] Call ID: ${_currentCall!.id}');
        // print('[CallScreen] ✅ Всё равно вызываем acceptCall для гарантии');
        // print('[CallScreen] ========================================');
      } else {
        // print('[CallScreen] ========================================');
        // print('[CallScreen] ✅✅✅ ПРИНИМАЕМ ЗВОНОК');
        // print('[CallScreen] Call ID: ${_currentCall!.id}');
        // print('[CallScreen] ========================================');
      }

      _webrtcService.acceptCall(_currentCall!.id);

      Future.delayed(const Duration(milliseconds: 500), () {
        _syncSpeakerState();
      });
    } else {
      // print('[CallScreen] ❌ ERROR: _currentCall is NULL!');
    }
  }

  void _declineCall() {
    if (_isEnding) return;

    // print('[CallScreen] ❌ Отклоняем звонок');
    _isEnding = true;

    if (_currentCall != null) {
      try {
        _webrtcService.declineCall(_currentCall!.id);
      } catch (e) {
        // print('[CallScreen] ❌ Ошибка decline: $e');
      }
    }

    _cleanupAndClose();
  }

  void _endCall() {
    if (_isEnding) return;

    // print('[CallScreen] 🔴 Завершаем звонок');
    _isEnding = true;

    final duration = _callDuration.inSeconds;
    final isVideo =
        _currentCall?.callType == 'video' || widget.callType == 'video';
    final chatId = widget.chatId ?? _currentCall?.chatId;

    // ⭐⭐⭐ КРИТИЧНО: Сохраняем статус звонка ДО вызова endCall()
    // endCall() может изменить статус на ended, и мы потеряем информацию о том, был ли звонок активен
    final callStatusBeforeEnd = _currentCall?.status;
    final isInitiator = callStatusBeforeEnd != CallStatus.incoming;
    // ⭐⭐⭐ ИСПРАВЛЕНО: Звонок считается принятым, если он был в статусе active или connecting
    // Или если длительность больше 0 (значит звонок был активен)
    final wasAccepted = (callStatusBeforeEnd == CallStatus.active || 
                        callStatusBeforeEnd == CallStatus.connecting) ||
                        duration > 0;

    try {
      _webrtcService.endCall();
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка endCall: $e');
    }

    if (mounted && chatId != null) {
      try {
        final chatProvider = context.read<ChatProvider>();
        final currentUserId = chatProvider.currentUserId ?? '';
        
        // ⭐⭐⭐ ИЗМЕНЕНО: Определяем результат звонка вместо callStatus
        // callStatus будет определяться в UI на основе initiatorId
        String callResult;
        if (wasAccepted && duration > 0) {
          callResult = 'completed';
        } else if (isInitiator) {
          // ⭐⭐⭐ ИСПРАВЛЕНО: Используем сохраненный статус вместо текущего
          // К этому моменту _currentCall?.status уже может быть изменен на ended
          callResult = callStatusBeforeEnd == CallStatus.declined
              ? 'rejected'
              : 'cancelled';
        } else {
          callResult = 'missed';
        }
        
        // ⭐⭐⭐ КРИТИЧНО: Определяем initiatorId
        // Если isInitiator = true, значит текущий пользователь инициировал звонок
        // Если isInitiator = false, значит звонок был входящим, инициатор - это callerId
        final initiatorId = isInitiator 
            ? currentUserId 
            : (_currentCall?.callerId ?? currentUserId);

        final callMessage = Message.createCallMessage(
          chatId: chatId,
          senderId: currentUserId,
          callType: isVideo ? 'video' : 'audio',
          initiatorId: initiatorId, // ⭐ НОВОЕ: ID инициатора звонка
          callResult: callResult, // ⭐ НОВОЕ: Результат звонка
          callDuration: wasAccepted ? duration : null,
        );

        chatProvider.sendCallMessage(callMessage);
        // print('[CallScreen] ✅ Сообщение о звонке создано');
        // print('[CallScreen]   initiatorId: $initiatorId');
        // print('[CallScreen]   callResult: $callResult');
      } catch (e) {
        // print('[CallScreen] ❌ Ошибка создания сообщения: $e');
      }
    }

    _cleanupAndClose();
  }

  void _cleanupAndClose() {
    if (_isDisposing) return;

    // print('[CallScreen] 🧹 Cleanup');
    _isDisposing = true;

    _callTimer?.cancel();
    _callTimer = null;

    _callStateSubscription?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();

    _stopAllMediaTracks();

    try {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    } catch (e) {
      // print('[CallScreen] ⚠️ Ошибка очистки рендереров: $e');
    }

    if (kIsWeb && _remoteAudioElement != null) {
      try {
        // print('[CallScreen] 🧹 Удаляем Web audio элемент');
        _remoteAudioElement!.pause();
        _remoteAudioElement!.srcObject = null;
        _remoteAudioElement!.remove();
        _remoteAudioElement = null;
        // print('[CallScreen] ✅ Audio элемент удален');
      } catch (e) {
        // print('[CallScreen] ⚠️ Ошибка удаления audio: $e');
      }
    }

    // print('[CallScreen] ✅ Cleanup завершен');

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _stopAllMediaTracks() {
    // print('[CallScreen] 🛑 Останавливаем треки');

    try {
      final localStream = _localRenderer.srcObject;
      if (localStream != null) {
        _stopStreamTracks(localStream, 'LOCAL');
      }

      final remoteStream = _remoteRenderer.srcObject;
      if (remoteStream != null) {
        _stopStreamTracks(remoteStream, 'REMOTE');
      }
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка остановки: $e');
    }
  }

  void _stopStreamTracks(rtc.MediaStream stream, String type) {
    try {
      final audioTracks = stream.getAudioTracks();
      for (var track in audioTracks) {
        try {
          track.stop();
          // print('[CallScreen] ✅ Остановлен audio ($type): ${track.id}');
        } catch (e) {}
      }

      final videoTracks = stream.getVideoTracks();
      for (var track in videoTracks) {
        try {
          track.stop();
          // print('[CallScreen] ✅ Остановлен video ($type): ${track.id}');
        } catch (e) {}
      }
    } catch (e) {
      // print('[CallScreen] ❌ Ошибка _stopStreamTracks ($type): $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  void dispose() {
    // print('[CallScreen] 🗑️ dispose()');

    if (!_isDisposing) {
      _isDisposing = true;

      _callTimer?.cancel();
      _callStateSubscription?.cancel();
      _localStreamSubscription?.cancel();
      _remoteStreamSubscription?.cancel();

      _stopAllMediaTracks();

      if (kIsWeb && _remoteAudioElement != null) {
        try {
          _remoteAudioElement!.pause();
          _remoteAudioElement!.srcObject = null;
          _remoteAudioElement!.remove();
        } catch (e) {}
      }
    }

    _localRenderer.dispose();
    _remoteRenderer.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // print('[CallScreen] 🎨 build() вызван');
    // print('[CallScreen] _currentCall: ${_currentCall?.id}');
    // print('[CallScreen] _currentCall?.status: ${_currentCall?.status}');

    final isVideo =
        _currentCall?.callType == 'video' || widget.callType == 'video';
    final isIncoming = _currentCall?.status == CallStatus.incoming;
    final isActive = _currentCall?.status == CallStatus.active;
    final isCalling = _currentCall?.status == CallStatus.calling;
    final isConnecting = _currentCall?.status == CallStatus.connecting;

    // print(       // '[CallScreen] isIncoming: $isIncoming, isActive: $isActive, isCalling: $isCalling, isConnecting: $isConnecting');

    final showIncomingButtons = isIncoming && !widget.autoAccept;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ⭐⭐⭐ Для голосовых звонков - аватарка на весь экран
              if (!isVideo)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        // ⭐⭐⭐ КРИТИЧНО: Для входящих звонков используем callerAvatar, для исходящих - receiverAvatar
                        String? avatarUrl;
                        if (isIncoming) {
                          // Входящий звонок - показываем аватар звонящего
                          avatarUrl = _currentCall?.callerAvatar ?? widget.receiverAvatar;
                        } else {
                          // Исходящий звонок - показываем аватар получателя
                          avatarUrl = widget.receiverAvatar ?? _currentCall?.receiverAvatar;
                        }
                        
                        if (avatarUrl != null) {
                          final fullAvatarUrl = ImageUtils.getAvatarUrl(avatarUrl);
                          if (fullAvatarUrl != null && fullAvatarUrl.isNotEmpty) {
                            return Image.network(
                              fullAvatarUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 200,
                                    color: Colors.white54,
                                  ),
                                );
                              },
                            );
                          }
                        }
                        
                        return const Center(
                          child: Icon(
                            Icons.person,
                            size: 200,
                            color: Colors.white54,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              // ⭐⭐⭐ Для видео звонков - видео на весь экран
              if (isVideo && (isActive || isConnecting))
                Positioned.fill(
                  child: rtc.RTCVideoView(_remoteRenderer, mirror: false),
                ),
              // ⭐⭐⭐ Информация о звонке (имя, статус) - показываем поверх
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      // ⭐⭐⭐ Для видео звонков - маленькая аватарка сверху
                      if (isVideo)
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white24,
                          backgroundImage: (widget.receiverAvatar != null ||
                                  _currentCall?.receiverAvatar != null)
                              ? NetworkImage(ImageUtils.getAvatarUrl(
                                      widget.receiverAvatar ??
                                          _currentCall!.receiverAvatar) ??
                                  '')
                              : null,
                          child: (widget.receiverAvatar == null &&
                                  _currentCall?.receiverAvatar == null)
                              ? const Icon(Icons.person,
                                  size: 50, color: Colors.white)
                              : null,
                        ),
                      if (isVideo) const SizedBox(height: 16),
                      Text(
                        widget.receiverName ??
                            _currentCall?.receiverName ??
                            'Неизвестный',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isActive
                            ? _formatDuration(_callDuration)
                            : isCalling
                                ? 'Вызов...'
                                : isIncoming
                                    ? widget.autoAccept
                                        ? 'Соединение...'
                                        : 'Входящий звонок'
                                    : 'Соединение...',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isVideo &&
                  (isActive || isConnecting || isCalling) &&
                  !_isVideoOff)
                Positioned(
                  top: 50,
                  right: 20,
                  width: 120,
                  height: 160,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: rtc.RTCVideoView(_localRenderer, mirror: true),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive || isCalling || isConnecting) ...[
                        if (isActive) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _CallButton(
                                icon: _isMuted
                                    ? FontAwesomeIcons.microphoneSlash
                                    : FontAwesomeIcons.microphone,
                                label: _isMuted ? 'Вкл. микр.' : 'Выкл. микр.',
                                backgroundColor:
                                    _isMuted ? Colors.white24 : Colors.white12,
                                onPressed: _toggleMute,
                                isDisabled: _isEnding || _isDisposing,
                              ),
                              if (isVideo)
                                _CallButton(
                                  icon: _isVideoOff
                                      ? FontAwesomeIcons.videoSlash
                                      : FontAwesomeIcons.video,
                                  label: _isVideoOff
                                      ? 'Вкл. видео'
                                      : 'Выкл. видео',
                                  backgroundColor: _isVideoOff
                                      ? Colors.white24
                                      : Colors.white12,
                                  onPressed: _toggleVideo,
                                  isDisabled: _isEnding || _isDisposing,
                                ),
                              _CallButton(
                                icon: _isSpeakerOn
                                    ? FontAwesomeIcons.volumeHigh
                                    : FontAwesomeIcons.volumeLow,
                                label: _isSpeakerOn ? 'Динамик' : 'Наушник',
                                backgroundColor: _isSpeakerOn
                                    ? Colors.white24
                                    : Colors.white12,
                                onPressed: _toggleSpeaker,
                                isDisabled: _isEnding || _isDisposing,
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                        GestureDetector(
                          onTap: _isEnding ? null : _endCall,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: _isEnding ? Colors.grey : Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: _isEnding
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.4),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                            ),
                            child: _isEnding
                                ? const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(
                                    FontAwesomeIcons.phoneSlash,
                                    color: Colors.white,
                                    size: 35,
                                  ),
                          ),
                        ),
                      ],
                      if (showIncomingButtons) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: _isEnding ? null : _declineCall,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: _isEnding ? Colors.grey : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.phoneSlash,
                                  color: Colors.white,
                                  size: 35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 100),
                            GestureDetector(
                              onTap: _isEnding ? null : _acceptCall,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: _isEnding ? Colors.grey : Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isVideo ? Icons.videocam : Icons.call,
                                  color: Colors.white,
                                  size: 35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;
  final bool isDisabled;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isDisabled ? null : onPressed,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDisabled ? Colors.grey : backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDisabled ? Colors.white38 : Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isDisabled ? Colors.white38 : Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
