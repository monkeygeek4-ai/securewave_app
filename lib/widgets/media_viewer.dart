// lib/widgets/media_viewer.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import '../services/media_storage_service.dart';
import '../services/api_service.dart';

class MediaItem {
  final String url;
  final String type; // 'image' или 'video'
  final String? thumbnailUrl; // Для видео - превью

  MediaItem({
    required this.url,
    required this.type,
    this.thumbnailUrl,
  });
}

class MediaViewer extends StatefulWidget {
  final List<MediaItem> mediaItems;
  final int initialIndex;

  const MediaViewer({
    super.key,
    required this.mediaItems,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformationController =
      TransformationController();
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationController.value = Matrix4.identity();
    _initializeVideo();
  }

  void _initializeVideo() {
    final currentItem = widget.mediaItems[_currentIndex];
    if (currentItem.type == 'video') {
      _loadVideo(currentItem.url);
    } else {
      _disposeVideo();
    }
  }

  Future<void> _loadVideo(String videoUrl) async {
    _disposeVideo();
    
    setState(() {
      _isVideoInitialized = false;
      _isVideoPlaying = false;
    });

    try {
      String fullUrl = videoUrl;
      if (!videoUrl.startsWith('http://') && !videoUrl.startsWith('https://')) {
        final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
        fullUrl = '$baseUrl$videoUrl';
      }

      _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      await _videoController!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController!.play();
        _videoController!.addListener(_videoListener);
      }
    } catch (e) {
      // print('[MediaViewer] ❌ Ошибка загрузки видео: $e');
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_videoController != null) {
      final isPlaying = _videoController!.value.isPlaying;
      if (mounted && _isVideoPlaying != isPlaying) {
        setState(() {
          _isVideoPlaying = isPlaying;
        });
      }
    }
  }

  void _disposeVideo() {
    _videoController?.removeListener(_videoListener);
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _transformationController.value = Matrix4.identity();
      _isVideoInitialized = false;
      _isVideoPlaying = false;
    });
    _initializeVideo();
  }

  void _toggleVideoPlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;
    
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  Future<void> _downloadMedia(MediaItem item) async {
    try {
      String fullUrl = item.url;
      if (!item.url.startsWith('http://') && !item.url.startsWith('https://')) {
        final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
        fullUrl = '$baseUrl${item.url}';
      }

      final response = await http.get(Uri.parse(fullUrl));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        if (item.type == 'image') {
          await Gal.putImageBytes(
            bytes,
            name: 'securewave_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Фото сохранено в галерею'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else if (item.type == 'video') {
          // Для видео используем gal.putVideoBytes если доступно
          // Или сохраняем через MediaStorageService
          await MediaStorageService.instance.downloadImage(item.url);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Видео сохранено'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }
    } catch (e) {
      // print('[MediaViewer] ❌ Ошибка сохранения медиа: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildImageItem(String imageUrl) {
    String fullUrl = imageUrl;
    if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
      final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
      fullUrl = '$baseUrl$imageUrl';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: CachedNetworkImage(
              imageUrl: fullUrl,
              fit: BoxFit.contain,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoItem(MediaItem item) {
    // Если видео еще не загружено, показываем индикатор загрузки
    if (!_isVideoInitialized || _videoController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            const Text(
              'Загрузка видео...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            // Кнопка воспроизведения/паузы (показываем всегда для удобства)
            GestureDetector(
              onTap: _toggleVideoPlayPause,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: Icon(
                  _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = widget.mediaItems[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.mediaItems.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadMedia(currentItem),
            tooltip: currentItem.type == 'image' ? 'Скачать фото' : 'Скачать видео',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaItems.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final item = widget.mediaItems[index];
          
          if (item.type == 'image') {
            return _buildImageItem(item.url);
          } else if (item.type == 'video') {
            // Если это текущий элемент, показываем видео
            if (index == _currentIndex) {
              // Загружаем видео если еще не загружено
              if (!_isVideoInitialized && _videoController == null) {
                _loadVideo(item.url);
              }
              return _buildVideoItem(item);
            } else {
              // Для других видео показываем превью или плейсхолдер
              String? thumbnailUrl = item.thumbnailUrl;
              if (thumbnailUrl != null && !thumbnailUrl.startsWith('http')) {
                final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
                thumbnailUrl = '$baseUrl$thumbnailUrl';
              }
              
              return Center(
                child: thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 64,
                        ),
                      )
                    : const Icon(
                        Icons.videocam,
                        color: Colors.white,
                        size: 64,
                      ),
              );
            }
          }
          
          return const Center(
            child: Icon(Icons.error, color: Colors.white, size: 50),
          );
        },
      ),
    );
  }
}

