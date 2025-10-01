// lib/widgets/incoming_call_overlay.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../models/call.dart';
import '../services/webrtc_service.dart';
import '../screens/call_screen.dart';

class IncomingCallOverlay extends StatefulWidget {
  final Call incomingCall;
  final VoidCallback onDismiss;

  const IncomingCallOverlay({
    Key? key,
    required this.incomingCall,
    required this.onDismiss,
  }) : super(key: key);

  @override
  _IncomingCallOverlayState createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();

    print('[IncomingCallOverlay] ✅ initState вызван');
    print('[IncomingCallOverlay] callId: ${widget.incomingCall.id}');
    print(
        '[IncomingCallOverlay] callerName: ${widget.incomingCall.callerName}');
    print('[IncomingCallOverlay] callType: ${widget.incomingCall.callType}');
    print('[IncomingCallOverlay] status: ${widget.incomingCall.status}');

    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _animationController.forward();

    // Автоматически отклоняем звонок через 30 секунд
    _timeoutTimer = Timer(Duration(seconds: 30), () {
      print('[IncomingCallOverlay] ⏰ Таймаут 30 секунд истек');
      _declineCall();
    });

    print('[IncomingCallOverlay] ⏱️ Таймер установлен на 30 секунд');
  }

  @override
  void dispose() {
    print('[IncomingCallOverlay] dispose вызван');
    _timeoutTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _acceptCall() {
    print('[IncomingCallOverlay] ✅ Принимаем звонок');
    _timeoutTimer?.cancel();

    // Закрываем оверлей
    widget.onDismiss();

    // Переходим на экран звонка
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          initialCall: widget.incomingCall,
        ),
      ),
    );
  }

  void _declineCall() {
    print('[IncomingCallOverlay] ❌ _declineCall вызван');
    print(
        '[IncomingCallOverlay] callId для отклонения: ${widget.incomingCall.id}');

    _timeoutTimer?.cancel();

    // Отклоняем звонок через WebRTC сервис
    WebRTCService.instance.declineCall(widget.incomingCall.id);

    // Закрываем оверлей
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.incomingCall.callType == 'video';

    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Входящий звонок',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white24,
                      backgroundImage: widget.incomingCall.callerAvatar != null
                          ? NetworkImage(widget.incomingCall.callerAvatar!)
                          : null,
                      child: widget.incomingCall.callerAvatar == null
                          ? Icon(Icons.person, color: Colors.white, size: 30)
                          : null,
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.incomingCall.callerName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isVideoCall ? Icons.videocam : Icons.call,
                                color: Colors.white70,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                isVideoCall ? 'Видеозвонок' : 'Аудиозвонок',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Кнопка отклонить
                    InkWell(
                      onTap: _declineCall,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),

                    // Кнопка принять
                    InkWell(
                      onTap: _acceptCall,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isVideoCall ? Icons.videocam : Icons.call,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
