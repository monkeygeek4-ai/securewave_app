// lib/screens/call_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'dart:js_util' as js_util;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../models/call.dart';
import '../models/message.dart';
import '../services/webrtc_service.dart';
import '../providers/chat_provider.dart';

class CallScreen extends StatefulWidget {
  final Call? initialCall;
  final String? chatId;
  final String? receiverId;
  final String? receiverName;
  final String? receiverAvatar;
  final String? callType;

  const CallScreen({
    Key? key,
    this.initialCall,
    this.chatId,
    this.receiverId,
    this.receiverName,
    this.receiverAvatar,
    this.callType,
  }) : super(key: key);

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCService _webrtcService = WebRTCService.instance;

  Call? _currentCall;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  bool _isDisposing = false;
  StreamSubscription? _callStateSubscription;
  StreamSubscription? _localStreamSubscription;
  StreamSubscription? _remoteStreamSubscription;

  html.AudioElement? _remoteAudio;
  html.VideoElement? _localVideo;
  html.VideoElement? _remoteVideo;
  String _localVideoViewId =
      'local-video-${DateTime.now().millisecondsSinceEpoch}';
  String _remoteVideoViewId =
      'remote-video-${DateTime.now().millisecondsSinceEpoch}';

  String? _attachedRemoteStreamId;
  String? _attachedLocalStreamId;

  @override
  void initState() {
    super.initState();

    if (widget.initialCall == null &&
        (widget.chatId == null || widget.receiverId == null)) {
      print('[CallScreen] Недостаточно параметров для инициализации звонка');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка инициализации звонка'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return;
    }

    // ВАЖНО: Подписываемся на stream ПЕРЕД инициализацией звонка
    _listenToStreams();
    _setupMediaElements();
    _initializeCall();
  }

  void _initializeCall() {
    print('[CallScreen] ═══════════════════════════════════');
    print('[CallScreen] 🔧 Инициализация звонка');

    if (widget.initialCall != null) {
      print('[CallScreen] 📞 Использую initialCall из виджета');
      print('[CallScreen] Status: ${widget.initialCall!.status}');
      _currentCall = widget.initialCall;
    } else {
      print('[CallScreen] 📞 Создаю новый исходящий звонок');
      final callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
      print('[CallScreen] CallId: $callId');
      print('[CallScreen] ChatId: ${widget.chatId}');
      print('[CallScreen] ReceiverId: ${widget.receiverId}');

      _webrtcService.startCall(
        callId: callId,
        chatId: widget.chatId!,
        receiverId: widget.receiverId!,
        receiverName: widget.receiverName ?? 'Неизвестный',
        callType: widget.callType ?? 'audio',
      );

      print('[CallScreen] ✅ startCall вызван, ожидаем обновление через stream');
    }

    print('[CallScreen] ═══════════════════════════════════');
  }

  void _setupMediaElements() {
    final isVideo =
        _currentCall?.callType == 'video' || widget.callType == 'video';

    print(
        '[CallScreen] Настройка медиа элементов (тип: ${isVideo ? 'video' : 'audio'})');

    if (isVideo) {
      _localVideo = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      ui.platformViewRegistry.registerViewFactory(
        _localVideoViewId,
        (int viewId) => _localVideo!,
      );

      _remoteVideo = html.VideoElement()
        ..autoplay = true
        ..muted = false
        ..volume = 1.0
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';

      ui.platformViewRegistry.registerViewFactory(
        _remoteVideoViewId,
        (int viewId) => _remoteVideo!,
      );
    } else {
      _remoteAudio = html.AudioElement()
        ..autoplay = true
        ..volume = 1.0;
    }

    print('[CallScreen] Медиа элементы созданы');
  }

  dynamic _getNativeStream(rtc.MediaStream stream) {
    try {
      final dynamic streamDynamic = stream;

      if (streamDynamic.jsStream != null) {
        print('[CallScreen] ✅ Получен jsStream');
        return streamDynamic.jsStream;
      }

      print(
          '[CallScreen] ⚠️ jsStream не найден, пробуем альтернативные методы');

      try {
        final jsStream = js_util.getProperty(streamDynamic, 'jsStream');
        if (jsStream != null) {
          print('[CallScreen] ✅ Получен jsStream через js_util');
          return jsStream;
        }
      } catch (e) {
        print('[CallScreen] Ошибка js_util.getProperty: $e');
      }

      try {
        final jsStream = js_util.getProperty(streamDynamic, '_jsStream');
        if (jsStream != null) {
          print('[CallScreen] ✅ Получен _jsStream');
          return jsStream;
        }
      } catch (e) {
        print('[CallScreen] Ошибка получения _jsStream: $e');
      }
    } catch (e) {
      print('[CallScreen] ❌ Критическая ошибка получения stream: $e');
    }

    print('[CallScreen] ❌ Не удалось получить нативный stream');
    return null;
  }

  void _listenToStreams() {
    _callStateSubscription = _webrtcService.callState.listen((call) {
      if (_isDisposing || !mounted) return;

      print('[CallScreen] 🔔 Получено обновление callState: ${call?.status}');

      setState(() {
        _currentCall = call;
      });

      if (call?.status == CallStatus.active) {
        _startCallTimer();
      } else if (call?.status == CallStatus.ended ||
          call?.status == CallStatus.declined ||
          call?.status == CallStatus.failed) {
        _endCall();
      }
    });

    _localStreamSubscription = _webrtcService.localStream.listen((stream) {
      if (_isDisposing || !mounted) return;

      if (stream != null && _localVideo != null) {
        if (_attachedLocalStreamId == stream.id) {
          print('[CallScreen] Локальный stream уже подключен, пропускаем');
          return;
        }

        print('[CallScreen] Получен локальный stream');
        _attachStreamToElement(stream, _localVideo!, isLocal: true);
        _attachedLocalStreamId = stream.id;
      }
    });

    _remoteStreamSubscription = _webrtcService.remoteStream.listen((stream) {
      if (_isDisposing || !mounted) return;

      if (stream != null) {
        if (_attachedRemoteStreamId == stream.id) {
          print('[CallScreen] Удаленный stream уже подключен, пропускаем');
          return;
        }

        print('[CallScreen] Получен удаленный stream');
        print('[CallScreen] Stream ID: ${stream.id}');
        print('[CallScreen] Аудио треков: ${stream.getAudioTracks().length}');
        print('[CallScreen] Видео треков: ${stream.getVideoTracks().length}');

        final isVideo =
            _currentCall?.callType == 'video' || widget.callType == 'video';

        if (isVideo && _remoteVideo != null) {
          _attachStreamToElement(stream, _remoteVideo!, isLocal: false);
          _attachedRemoteStreamId = stream.id;
        } else if (!isVideo && _remoteAudio != null) {
          _attachStreamToAudio(stream, _remoteAudio!);
          _attachedRemoteStreamId = stream.id;
        }
      }
    });
  }

  void _attachStreamToElement(rtc.MediaStream stream, html.MediaElement element,
      {required bool isLocal}) {
    if (_isDisposing) return;

    try {
      final nativeStream = _getNativeStream(stream);

      if (nativeStream == null) {
        print(
            '[CallScreen] ❌ Не удалось получить нативный stream для ${isLocal ? 'локального' : 'удаленного'} видео');
        return;
      }

      print(
          '[CallScreen] Подключение ${isLocal ? 'локального' : 'удаленного'} stream');

      element.srcObject = nativeStream;
      print(
          '[CallScreen] srcObject установлен для ${isLocal ? 'локального' : 'удаленного'} stream');

      if (!isLocal) {
        element.volume = 1.0;
        element.muted = false;

        print('[CallScreen] Вызываем play() для удаленного stream');

        element.play().then((_) {
          if (_isDisposing) return;
          print('[CallScreen] 🔊 Удаленный stream воспроизводится ✅');
          _checkAudioTracks(nativeStream);
        }).catchError((e) {
          if (_isDisposing) return;
          print('[CallScreen] ❌ Ошибка воспроизведения: $e');
          _retryPlayback(element, nativeStream, attempt: 1);
        });
      } else {
        print('[CallScreen] Локальный stream подключен ✅');
      }
    } catch (e) {
      print('[CallScreen] ❌ Ошибка подключения stream: $e');
    }
  }

  void _attachStreamToAudio(rtc.MediaStream stream, html.AudioElement audio) {
    if (_isDisposing) return;

    try {
      final nativeStream = _getNativeStream(stream);

      if (nativeStream == null) {
        print('[CallScreen] ❌ Не удалось получить нативный stream для аудио');
        return;
      }

      print('[CallScreen] Подключение аудио stream');
      print('[CallScreen] Native stream type: ${nativeStream.runtimeType}');

      audio.srcObject = nativeStream;
      audio.volume = 1.0;
      audio.autoplay = true;

      audio.play().then((_) {
        if (_isDisposing) return;
        print('[CallScreen] 🔊 Аудио stream воспроизводится ✅');
        print('[CallScreen] Audio Volume: ${audio.volume}');
        print('[CallScreen] Audio Muted: ${audio.muted}');
        _checkAudioTracks(nativeStream);
      }).catchError((e) {
        if (_isDisposing) return;
        print('[CallScreen] ❌ Ошибка воспроизведения аудио: $e');
        _retryPlayback(audio, nativeStream, attempt: 1);
      });
    } catch (e) {
      print('[CallScreen] ❌ Ошибка подключения аудио stream: $e');
    }
  }

  void _checkAudioTracks(dynamic nativeStream) {
    if (_isDisposing) return;

    try {
      final audioTracks =
          js_util.callMethod(nativeStream, 'getAudioTracks', []);
      final trackCount = js_util.getProperty(audioTracks, 'length');
      print('[CallScreen] 🎵 Аудио треков: $trackCount');

      if (trackCount > 0) {
        final firstTrack = audioTracks[0];
        final enabled = js_util.getProperty(firstTrack, 'enabled');
        final readyState = js_util.getProperty(firstTrack, 'readyState');
        final muted = js_util.getProperty(firstTrack, 'muted');

        print('[CallScreen] 🎵 Трек enabled: $enabled');
        print('[CallScreen] 🎵 Трек readyState: $readyState');
        print('[CallScreen] 🎵 Трек muted: $muted');
      }
    } catch (e) {
      print('[CallScreen] Ошибка проверки аудио треков: $e');
    }
  }

  void _retryPlayback(html.MediaElement element, dynamic nativeStream,
      {required int attempt}) {
    if (_isDisposing || attempt > 3) {
      if (attempt > 3) {
        print('[CallScreen] ❌ Превышено количество попыток воспроизведения');
      }
      return;
    }

    final delay = Duration(milliseconds: 300 * attempt);

    Future.delayed(delay, () {
      if (_isDisposing) return;

      print('[CallScreen] 🔄 Попытка $attempt: повторное воспроизведение...');

      element.play().then((_) {
        if (_isDisposing) return;
        print('[CallScreen] 🔊 Попытка $attempt успешна ✅');
      }).catchError((e) {
        if (_isDisposing) return;
        print('[CallScreen] ❌ Попытка $attempt не удалась: $e');
        _retryPlayback(element, nativeStream, attempt: attempt + 1);
      });
    });
  }

  void _startCallTimer() {
    if (_isDisposing) return;

    _callTimer?.cancel();
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
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
    setState(() {
      _isMuted = !_isMuted;
    });
    _webrtcService.toggleMute();
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    _webrtcService.toggleVideo();
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });

    if (_remoteVideo != null) {
      _remoteVideo!.volume = _isSpeakerOn ? 1.0 : 0.5;
    }
    if (_remoteAudio != null) {
      _remoteAudio!.volume = _isSpeakerOn ? 1.0 : 0.5;
    }

    _webrtcService.toggleSpeaker();
  }

  void _acceptCall() {
    if (_currentCall != null) {
      _webrtcService.acceptCall(_currentCall!.id);
    }
  }

  void _declineCall() {
    if (_isDisposing) return;

    if (_currentCall != null) {
      _webrtcService.declineCall(_currentCall!.id);
    }
    _cleanupAndClose();
  }

  void _endCall() {
    if (_isDisposing) return;

    print('[CallScreen] Завершение звонка');

    // Вычисляем длительность
    final duration = _callDuration.inSeconds;
    final isVideo =
        _currentCall?.callType == 'video' || widget.callType == 'video';
    final chatId = widget.chatId ?? _currentCall?.chatId;

    // ВАЖНО: Определяем кто инициатор звонка
    final isInitiator = _currentCall?.status != CallStatus.incoming;
    final wasAccepted = _currentCall?.status == CallStatus.active;

    _webrtcService.endCall();

    // Создаем сообщение о звонке
    if (mounted && chatId != null) {
      try {
        final chatProvider = context.read<ChatProvider>();
        String callStatus;

        // Определяем статус звонка
        if (wasAccepted && duration > 0) {
          // Звонок состоялся
          callStatus = isInitiator ? 'outgoing' : 'incoming';
        } else if (isInitiator) {
          // Инициатор звонка, но звонок не состоялся
          if (_currentCall?.status == CallStatus.declined) {
            callStatus = 'rejected'; // Отклонен
          } else {
            callStatus = 'cancelled'; // Отменен
          }
        } else {
          // Получатель звонка, но не ответил
          callStatus = 'missed'; // Пропущенный
        }

        final callMessage = Message.createCallMessage(
          chatId: chatId,
          senderId: chatProvider.currentUserId ?? '',
          callType: isVideo ? 'video' : 'audio',
          callStatus: callStatus,
          callDuration: wasAccepted ? duration : null,
        );

        chatProvider.sendCallMessage(callMessage);
        print(
            '[CallScreen] Сообщение о звонке создано: статус=$callStatus, длительность=$duration секунд');
      } catch (e) {
        print('[CallScreen] Ошибка создания сообщения о звонке: $e');
      }
    }

    _cleanupAndClose();
  }

  void _cleanupAndClose() {
    if (_isDisposing) return;

    _isDisposing = true;
    print('[CallScreen] Очистка ресурсов экрана звонка');

    _callTimer?.cancel();
    _callTimer = null;

    _callStateSubscription?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();

    _remoteAudio?.srcObject = null;
    _remoteVideo?.srcObject = null;
    _localVideo?.srcObject = null;

    _attachedRemoteStreamId = null;
    _attachedLocalStreamId = null;

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    print('[CallScreen] dispose() вызван');
    _isDisposing = true;

    _callTimer?.cancel();
    _callStateSubscription?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();

    _remoteAudio?.srcObject = null;
    _remoteVideo?.srcObject = null;
    _localVideo?.srcObject = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo =
        _currentCall?.callType == 'video' || widget.callType == 'video';
    final isIncoming = _currentCall?.status == CallStatus.incoming;
    final isActive = _currentCall?.status == CallStatus.active;
    final isCalling = _currentCall?.status == CallStatus.calling;
    final isConnecting = _currentCall?.status == CallStatus.connecting;

    // УСИЛЕННАЯ ОТЛАДКА
    print('═══════════════════════════════════════════════');
    print('[CallScreen] 🎨 BUILD вызван');
    print('[CallScreen] _currentCall != null: ${_currentCall != null}');
    if (_currentCall != null) {
      print('[CallScreen] _currentCall.id: ${_currentCall!.id}');
      print('[CallScreen] _currentCall.status: ${_currentCall!.status}');
      print('[CallScreen] _currentCall.callType: ${_currentCall!.callType}');
    }
    print('[CallScreen] isIncoming: $isIncoming');
    print('[CallScreen] isActive: $isActive');
    print('[CallScreen] isCalling: $isCalling');
    print('[CallScreen] isConnecting: $isConnecting');
    print(
        '[CallScreen] Показать кнопки (isActive || isCalling || isConnecting): ${isActive || isCalling || isConnecting}');
    print('[CallScreen] Показать входящие (isIncoming): $isIncoming');
    print('═══════════════════════════════════════════════');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Удаленное видео на весь экран
              if (isVideo && (isActive || isConnecting) && _remoteVideo != null)
                Positioned.fill(
                  child: HtmlElementView(viewType: _remoteVideoViewId),
                ),
              // Информация о звонке
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white24,
                        backgroundImage: (widget.receiverAvatar != null ||
                                _currentCall?.receiverAvatar != null)
                            ? NetworkImage(widget.receiverAvatar ??
                                _currentCall!.receiverAvatar!)
                            : null,
                        child: (widget.receiverAvatar == null &&
                                _currentCall?.receiverAvatar == null)
                            ? Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                      ),
                      SizedBox(height: 16),
                      Text(
                        widget.receiverName ??
                            _currentCall?.receiverName ??
                            'Неизвестный',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        isActive
                            ? _formatDuration(_callDuration)
                            : isCalling
                                ? 'Вызов...'
                                : isIncoming
                                    ? 'Входящий звонок'
                                    : 'Соединение...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Локальное видео (маленькое окно)
              if (isVideo &&
                  (isActive || isConnecting || isCalling) &&
                  _localVideo != null)
                Positioned(
                  top: 50,
                  right: 20,
                  width: 120,
                  height: 160,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: HtmlElementView(viewType: _localVideoViewId),
                    ),
                  ),
                ),
              // Кнопки управления
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
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
                      // Кнопки для активного звонка или во время вызова
                      if (isActive || isCalling || isConnecting) ...[
                        // Показываем кнопки управления только для активного звонка
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
                                ),
                              _CallButton(
                                icon: _isSpeakerOn
                                    ? FontAwesomeIcons.volumeHigh
                                    : FontAwesomeIcons.volumeOff,
                                label: _isSpeakerOn ? 'Динамик' : 'Наушники',
                                backgroundColor: _isSpeakerOn
                                    ? Colors.white24
                                    : Colors.white12,
                                onPressed: _toggleSpeaker,
                              ),
                            ],
                          ),
                          SizedBox(height: 40),
                        ],
                        // Кнопка завершения звонка (всегда видна)
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              FontAwesomeIcons.phoneSlash,
                              color: Colors.white,
                              size: 35,
                            ),
                          ),
                        ),
                      ],
                      // Кнопки для входящего звонка
                      if (isIncoming) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Кнопка отклонить
                            GestureDetector(
                              onTap: _declineCall,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  FontAwesomeIcons.phoneSlash,
                                  color: Colors.white,
                                  size: 35,
                                ),
                              ),
                            ),
                            SizedBox(width: 100),
                            // Кнопка принять
                            GestureDetector(
                              onTap: _acceptCall,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
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

  const _CallButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
