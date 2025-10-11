// lib/screens/call_screen.dart
// Кроссплатформенная версия (работает на Web и Mobile)

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
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

  // Рендереры для мобильных платформ
  final rtc.RTCVideoRenderer _localRenderer = rtc.RTCVideoRenderer();
  final rtc.RTCVideoRenderer _remoteRenderer = rtc.RTCVideoRenderer();

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

    _initRenderers();
    _listenToStreams();
    _initializeCall();
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      print('[CallScreen] Рендереры инициализированы');
    } catch (e) {
      print('[CallScreen] Ошибка инициализации рендереров: $e');
    }
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
      if (_isDisposing || !mounted || stream == null) return;

      print('[CallScreen] 📹 Получен локальный stream');
      setState(() {
        _localRenderer.srcObject = stream;
      });
    });

    _remoteStreamSubscription = _webrtcService.remoteStream.listen((stream) {
      if (_isDisposing || !mounted || stream == null) return;

      print('[CallScreen] 🔊 Получен удаленный stream');
      print('[CallScreen] Stream ID: ${stream.id}');
      print('[CallScreen] Аудио треков: ${stream.getAudioTracks().length}');
      print('[CallScreen] Видео треков: ${stream.getVideoTracks().length}');

      setState(() {
        _remoteRenderer.srcObject = stream;
      });

      // Проверяем треки
      _checkAudioTracks(stream);
    });
  }

  void _checkAudioTracks(rtc.MediaStream stream) {
    try {
      final audioTracks = stream.getAudioTracks();
      print('[CallScreen] 🔍 Проверка аудио треков:');
      print('[CallScreen] Количество аудио треков: ${audioTracks.length}');

      for (var i = 0; i < audioTracks.length; i++) {
        final track = audioTracks[i];
        print('[CallScreen] Трек $i:');
        print('[CallScreen]   - ID: ${track.id}');
        print('[CallScreen]   - Label: ${track.label}');
        print('[CallScreen]   - Enabled: ${track.enabled}');
        print('[CallScreen]   - Muted: ${track.muted}');
      }
    } catch (e) {
      print('[CallScreen] Ошибка проверки треков: $e');
    }
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

    final duration = _callDuration.inSeconds;
    final isVideo =
        _currentCall?.callType == 'video' || widget.callType == 'video';
    final chatId = widget.chatId ?? _currentCall?.chatId;

    final isInitiator = _currentCall?.status != CallStatus.incoming;
    final wasAccepted = _currentCall?.status == CallStatus.active;

    _webrtcService.endCall();

    if (mounted && chatId != null) {
      try {
        final chatProvider = context.read<ChatProvider>();
        String callStatus;

        if (wasAccepted && duration > 0) {
          callStatus = isInitiator ? 'outgoing' : 'incoming';
        } else if (isInitiator) {
          if (_currentCall?.status == CallStatus.declined) {
            callStatus = 'rejected';
          } else {
            callStatus = 'cancelled';
          }
        } else {
          callStatus = 'missed';
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

    _localRenderer.dispose();
    _remoteRenderer.dispose();

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
              if (isVideo && (isActive || isConnecting))
                Positioned.fill(
                  child: rtc.RTCVideoView(_remoteRenderer, mirror: false),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: rtc.RTCVideoView(_localRenderer, mirror: true),
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
