// lib/widgets/voice_message_recorder.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/app_colors.dart';

class VoiceMessageRecorder extends StatefulWidget {
  final Function(String filePath, int duration) onRecordingComplete;
  final VoidCallback? onCancel;

  const VoiceMessageRecorder({
    super.key,
    required this.onRecordingComplete,
    this.onCancel,
  });

  @override
  State<VoiceMessageRecorder> createState() => _VoiceMessageRecorderState();
}

class _VoiceMessageRecorderState extends State<VoiceMessageRecorder>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _timer;
  int _duration = 0;
  late AnimationController _animationController;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isDenied) {
      final requestedStatus = await Permission.microphone.request();
      setState(() {
        _hasPermission = requestedStatus.isGranted;
      });
      
      if (!_hasPermission && requestedStatus.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Разрешение на микрофон'),
              content: const Text(
                'Для записи голосовых сообщений необходимо разрешение на использование микрофона. Пожалуйста, включите его в настройках приложения.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Настройки'),
                ),
              ],
            ),
          );
        }
      } else if (!_hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Разрешение на микрофон отклонено'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      setState(() {
        _hasPermission = status.isGranted;
      });
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      await _checkPermission();
      if (!_hasPermission) return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = path.join(directory.path, fileName);

      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        await WakelockPlus.enable();

        setState(() {
          _isRecording = true;
          _duration = 0;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _duration = timer.tick;
            });
          }
        });
      }
    } catch (e) {
      // print('[VoiceRecorder] ❌ Ошибка начала записи: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка записи: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    try {
      if (_isRecording) {
        final path = await _recorder.stop();
        await WakelockPlus.disable();
        
        _timer?.cancel();
        _timer = null;

        if (mounted) {
          setState(() {
            _isRecording = false;
          });

          if (send && path != null && _duration > 0) {
            widget.onRecordingComplete(path, _duration);
          } else if (path != null) {
            // Удаляем файл если не отправляем
            try {
              final file = File(path);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (e) {
              // print('[VoiceRecorder] ⚠️ Ошибка удаления файла: $e');
            }
          }
        }
      }
    } catch (e) {
      // print('[VoiceRecorder] ❌ Ошибка остановки записи: $e');
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _animationController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Кнопка отмены
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                _stopRecording(send: false);
                widget.onCancel?.call();
              },
            ),
            const SizedBox(width: 8),
            // Индикатор записи
            if (_isRecording)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(
                        0.5 + (_animationController.value * 0.5),
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            const SizedBox(width: 12),
            // Длительность
            Expanded(
              child: Text(
                _isRecording ? _formatDuration(_duration) : 'Нажмите для записи',
                style: TextStyle(
                  color: AppColors.getTextColor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Кнопка записи/отправки
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressEnd: (details) => _stopRecording(send: true),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: _isRecording
                      ? const LinearGradient(
                          colors: [Colors.red, Colors.redAccent],
                        )
                      : AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isRecording ? Colors.red : AppColors.primaryPurple)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

