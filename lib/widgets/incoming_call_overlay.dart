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

    print('[IncomingCallOverlay] ========================================');
    print('[IncomingCallOverlay] initState вызван');
    print('[IncomingCallOverlay] callId: ${widget.incomingCall.id}');
    print(
        '[IncomingCallOverlay] callerName: ${widget.incomingCall.callerName}');
    print('[IncomingCallOverlay] callType: ${widget.incomingCall.callType}');
    print('[IncomingCallOverlay] status: ${widget.incomingCall.status}');
    print('[IncomingCallOverlay] ========================================');

    _animationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _animationController.forward();

    // Автоматически отклоняем звонок через 45 секунд (увеличено для мобильных)
    _timeoutTimer = Timer(Duration(seconds: 45), () {
      if (mounted) {
        print('[IncomingCallOverlay] ⏰ Таймаут 45 секунд истек');
        _declineCall();
      }
    });

    print('[IncomingCallOverlay] ✅ Таймер установлен на 45 секунд');
  }

  @override
  void dispose() {
    print('[IncomingCallOverlay] ========================================');
    print('[IncomingCallOverlay] dispose вызван');
    print('[IncomingCallOverlay] ========================================');
    _timeoutTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _acceptCall() {
    print('[IncomingCallOverlay] ========================================');
    print('[IncomingCallOverlay] ✅ Принимаем звонок');
    print('[IncomingCallOverlay] callId: ${widget.incomingCall.id}');
    print('[IncomingCallOverlay] ========================================');

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
    print('[IncomingCallOverlay] ========================================');
    print('[IncomingCallOverlay] ❌ Отклоняем звонок');
    print('[IncomingCallOverlay] callId: ${widget.incomingCall.id}');
    print('[IncomingCallOverlay] ========================================');

    _timeoutTimer?.cancel();

    // Отклоняем звонок через WebRTC сервис
    WebRTCService.instance.declineCall(widget.incomingCall.id);

    // Закрываем оверлей
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isVideoCall = widget.incomingCall.callType == 'video';
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Адаптивные размеры для мобильных и планшетов
    final bool isMobile = screenWidth < 600;
    final double cardWidth = isMobile ? screenWidth * 0.9 : 400;
    final double avatarRadius = isMobile ? 35 : 40;
    final double buttonSize = isMobile ? 60 : 70;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            elevation: 24,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: cardWidth,
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.6,
              ),
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Иконка типа звонка
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isVideoCall ? Icons.videocam : Icons.phone,
                      color: Colors.white,
                      size: isMobile ? 36 : 44,
                    ),
                  ),

                  SizedBox(height: 20),

                  // Текст входящего звонка
                  Text(
                    'Входящий ${isVideoCall ? "видео" : ""}звонок',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 16),

                  // Информация о звонящем
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: widget.incomingCall.callerAvatar !=
                                null
                            ? NetworkImage(widget.incomingCall.callerAvatar!)
                            : null,
                        child: widget.incomingCall.callerAvatar == null
                            ? Icon(
                                Icons.person,
                                color: Colors.white,
                                size: avatarRadius * 0.8,
                              )
                            : null,
                      ),
                      SizedBox(width: 16),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.incomingCall.callerName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  isVideoCall ? Icons.videocam : Icons.call,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  isVideoCall
                                      ? 'Видеозвонок'
                                      : 'Голосовой звонок',
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

                  SizedBox(height: isMobile ? 32 : 40),

                  // Кнопки управления
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Кнопка отклонения
                      Column(
                        children: [
                          SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: FloatingActionButton(
                              onPressed: _declineCall,
                              backgroundColor: Colors.red.shade600,
                              elevation: 8,
                              heroTag: 'decline',
                              child: Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: isMobile ? 28 : 32,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Отклонить',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Кнопка принятия
                      Column(
                        children: [
                          SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: FloatingActionButton(
                              onPressed: _acceptCall,
                              backgroundColor: Colors.green.shade600,
                              elevation: 8,
                              heroTag: 'accept',
                              child: Icon(
                                Icons.call,
                                color: Colors.white,
                                size: isMobile ? 28 : 32,
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Принять',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
