// lib/widgets/voice_message_bubble.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/message.dart';
import '../utils/app_colors.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VoiceMessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
        });
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.loading) {
            _isLoading = true;
          } else {
            _isLoading = false;
          }
        });
      }
    });
  }

  Future<String?> _downloadAudio() async {
    if (_localFilePath != null) {
      final file = File(_localFilePath!);
      if (await file.exists()) {
        return _localFilePath;
      }
    }

    try {
      final fileUrl = widget.message.mediaUrl ?? widget.message.metadata?['fileUrl'];
      if (fileUrl == null) return null;

      // Формируем полный URL
      String fullUrl = fileUrl;
      if (!fileUrl.startsWith('http://') && !fileUrl.startsWith('https://')) {
        final baseUrl = 'https://securewave.sbk-19.ru';
        fullUrl = '$baseUrl$fileUrl';
      }

      // Скачиваем файл
      final directory = await getApplicationDocumentsDirectory();
      final fileName = path.basename(Uri.parse(fullUrl).path);
      if (fileName.isEmpty || !fileName.contains('.')) {
        final messageId = widget.message.id;
        final fileExtension = fileUrl.contains('.m4a') ? '.m4a' : '.mp3';
        final file = File(path.join(directory.path, 'voice_$messageId$fileExtension'));
        _localFilePath = file.path;
      } else {
        final file = File(path.join(directory.path, 'voice_$fileName'));
        _localFilePath = file.path;
      }

      if (await File(_localFilePath!).exists()) {
        return _localFilePath;
      }

      final dio = Dio();
      final response = await dio.get(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        await File(_localFilePath!).writeAsBytes(response.data);
        return _localFilePath;
      }
    } catch (e) {
      // print('[VoiceMessageBubble] ❌ Ошибка загрузки аудио: $e');
    }
    return null;
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_audioPlayer.processingState == ProcessingState.idle) {
          setState(() {
            _isLoading = true;
          });
          final filePath = await _downloadAudio();
          if (filePath != null) {
            await _audioPlayer.setFilePath(filePath);
          } else {
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Не удалось загрузить аудио'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
        await _audioPlayer.play();
      }
    } catch (e) {
      // print('[VoiceMessageBubble] ❌ Ошибка воспроизведения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка воспроизведения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _getDurationInSeconds() {
    final metadata = widget.message.metadata;
    if (metadata != null && metadata['duration'] != null) {
      return metadata['duration'] as int;
    }
    return _duration.inSeconds;
  }

  double _getProgress() {
    if (_duration.inMilliseconds == 0) return 0.0;
    return _position.inMilliseconds / _duration.inMilliseconds;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final durationSeconds = _getDurationInSeconds();
    final progress = _getProgress();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: widget.isMe
                  ? AppColors.primaryGradient
                  : null,
              color: widget.isMe
                  ? null
                  : (isDarkMode ? const Color(0xFF2D2D2D) : Colors.grey[200]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кнопка воспроизведения
                GestureDetector(
                  onTap: _isLoading ? null : _togglePlay,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? Colors.white.withOpacity(0.2)
                          : AppColors.primaryPurple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: widget.isMe ? Colors.white : AppColors.primaryPurple,
                            size: 24,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Прогресс бар и длительность
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Визуализация волны (кружки)
                      Row(
                        children: List.generate(20, (index) {
                          final isActive = _isPlaying && 
                              (index < (progress * 20).round() || 
                               (index % 3 == 0 && _isPlaying));
                          return Container(
                            width: 3,
                            height: isActive ? 20 : 8,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: widget.isMe
                                  ? Colors.white.withOpacity(isActive ? 1.0 : 0.5)
                                  : AppColors.primaryPurple.withOpacity(isActive ? 1.0 : 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      // Длительность
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(Duration(seconds: durationSeconds)),
                            style: TextStyle(
                              color: widget.isMe
                                  ? Colors.white.withOpacity(0.8)
                                  : (isDarkMode ? Colors.white70 : Colors.black87),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_isPlaying)
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(
                                color: widget.isMe
                                    ? Colors.white.withOpacity(0.6)
                                    : (isDarkMode ? Colors.white60 : Colors.black54),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

