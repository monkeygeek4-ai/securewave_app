import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import '../services/media_storage_service.dart';

class MultiImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? messageId;

  const MultiImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.messageId,
  });

  @override
  State<MultiImageViewer> createState() => _MultiImageViewerState();
}

class _MultiImageViewerState extends State<MultiImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      // Сбрасываем трансформацию при переключении фото
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _downloadImage(String imageUrl) async {
    try {
      // Проверяем, не скачано ли уже
      final mediaStorage = MediaStorageService.instance;
      final localPath = await mediaStorage.getLocalPath(imageUrl);
      
      if (localPath != null) {
        // Файл уже скачан, показываем сообщение
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Фото уже сохранено на устройстве'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Скачиваем изображение
      final response = await http.get(Uri.parse(imageUrl.startsWith('http')
          ? imageUrl
          : 'https://securewave.sbk-19.ru$imageUrl'));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // Сохраняем через MediaStorageService
        await mediaStorage.downloadImage(imageUrl);

        // Также сохраняем в галерею
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
      } else {
        throw Exception('Ошибка загрузки: ${response.statusCode}');
      }
    } catch (e) {
      // print('[MultiImageViewer] ❌ Ошибка сохранения фото: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения фото: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadImage(widget.imageUrls[_currentIndex]),
            tooltip: 'Скачать фото',
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final imageUrl = widget.imageUrls[index];
          final fullUrl = imageUrl.startsWith('http')
              ? imageUrl
              : 'https://securewave.sbk-19.ru$imageUrl';

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
        },
      ),
    );
  }
}

