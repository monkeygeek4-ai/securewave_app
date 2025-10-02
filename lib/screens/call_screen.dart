// lib/screens/call_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import '../models/call.dart';
import '../services/webrtc_service.dart';

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

  html.VideoElement? _localVideo;
  html.VideoElement? _remoteVideo;
  String _localVideoViewId =
      'local-video-${DateTime.now().millisecondsSinceEpoch}';
  String _remoteVideoViewId =
      'remote-video-${DateTime.now().millisecondsSinceEpoch}';

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

    _initializeCall();
    _setupVideoElements();
    _listenToStreams();
  }

  void _initializeCall() {
    if (widget.initialCall != null) {
      _currentCall = widget.initialCall;
    } else {
      final callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
      _webrtcService.startCall(
        callId: callId,
        chatId: widget.chatId!,
        receiverId: widget.receiverId!,
        receiverName: widget.receiverName ?? 'Неизвестный',
        callType: widget.callType ?? 'audio',
      );
    }
  }

  void _setupVideoElements() {
    // ИСПРАВЛЕНО: Создаем элементы для всех типов звонков
    final isVideo =
        _currentCall?.callType == 'video' || widget.callType == 'video';

    print(
        '[CallScreen] Настройка медиа элементов (тип: ${isVideo ? 'video' : 'audio'})');

    // Локальный элемент
    _localVideo = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    if (isVideo) {
      ui.platformViewRegistry.registerViewFactory(
        _localVideoViewId,
        (int viewId) => _localVideo!,
      );
    }

    // Удаленный элемент - КРИТИЧНО: muted = false!
    _remoteVideo = html.VideoElement()
      ..autoplay = true
      ..muted = false // ВАЖНО для звука!
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    if (isVideo) {
      ui.platformViewRegistry.registerViewFactory(
        _remoteVideoViewId,
        (int viewId) => _remoteVideo!,
      );
    }

    print('[CallScreen] Медиа элементы созданы');
  }

  void _listenToStreams() {
    _webrtcService.callState.listen((call) {
      if (mounted) {
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
      }
    });

    _webrtcService.localStream.listen((stream) {
      if (stream != null && _localVideo != null) {
        print('[CallScreen] Получен локальный stream');
        try {
          _localVideo!.srcObject = stream as html.MediaStream;
          print('[CallScreen] Локальный stream подключен');
        } catch (e) {
          print('[CallScreen] Ошибка локального stream: $e');
        }
      }
    });

    _webrtcService.remoteStream.listen((stream) {
      if (stream != null && _remoteVideo != null) {
        print('[CallScreen] Получен удаленный stream');
        try {
          _remoteVideo!.srcObject = stream as html.MediaStream;

          // КРИТИЧНО: явно запускаем воспроизведение
          _remoteVideo!.play().then((_) {
            print('[CallScreen] Удаленный stream воспроизводится');
          }).catchError((e) {
            print('[CallScreen] Ошибка воспроизведения: $e');
            // Повторная попытка через задержку
            Future.delayed(Duration(milliseconds: 500), () {
              _remoteVideo!.play();
            });
          });

          print('[CallScreen] Удаленный stream подключен');
        } catch (e) {
          print('[CallScreen] Ошибка удаленного stream: $e');
        }
      }
    });
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      }
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
    _webrtcService.toggleSpeaker();
  }

  void _acceptCall() {
    if (_currentCall != null) {
      _webrtcService.acceptCall(_currentCall!.id);
    }
  }

  void _declineCall() {
    if (_currentCall != null) {
      _webrtcService.declineCall(_currentCall!.id);
    }
    Navigator.pop(context);
  }

  void _endCall() {
    _callTimer?.cancel();
    _webrtcService.endCall();
    Navigator.pop(context);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo =
        _currentCall?.callType == 'video' || widget.callType == 'video';
    final isIncoming = _currentCall?.status == CallStatus.incoming;
    final isActive = _currentCall?.status == CallStatus.active;
    final isCalling = _currentCall?.status == CallStatus.calling;

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
              // Удаленное видео (фон)
              if (isVideo && isActive && _remoteVideo != null)
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

              // Локальное видео (картинка в картинке)
              if (isVideo && isActive && _localVideo != null)
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
                      // Кнопки для активного звонка
                      if (isActive || isCalling) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallButton(
                              icon: _isMuted ? Icons.mic_off : Icons.mic,
                              label: _isMuted ? 'Вкл. микр.' : 'Выкл. микр.',
                              backgroundColor:
                                  _isMuted ? Colors.white24 : Colors.white12,
                              onPressed: _toggleMute,
                            ),
                            if (isVideo)
                              _CallButton(
                                icon: _isVideoOff
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                label:
                                    _isVideoOff ? 'Вкл. видео' : 'Выкл. видео',
                                backgroundColor: _isVideoOff
                                    ? Colors.white24
                                    : Colors.white12,
                                onPressed: _toggleVideo,
                              ),
                            _CallButton(
                              icon: _isSpeakerOn
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              label: _isSpeakerOn ? 'Динамик' : 'Наушники',
                              backgroundColor: _isSpeakerOn
                                  ? Colors.white24
                                  : Colors.white12,
                              onPressed: _toggleSpeaker,
                            ),
                          ],
                        ),
                        SizedBox(height: 40),
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.call_end,
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
                            GestureDetector(
                              onTap: _declineCall,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.call_end,
                                  color: Colors.white,
                                  size: 35,
                                ),
                              ),
                            ),
                            SizedBox(width: 100),
                            GestureDetector(
                              onTap: _acceptCall,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.green,
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
