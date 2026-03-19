// lib/widgets/image_viewer.dart

import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/media_storage_service.dart';

class ImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? fileName;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.fileName,
  });

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final TransformationController _transformationController;
  bool _isDownloading = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  String? _localPath;
  bool _isCheckingLocal = true;

  @override
  void initState() {
    super.initState();
    // Инициализируем с явной матрицей идентичности, чтобы избежать ошибок
    _transformationController = TransformationController(Matrix4.identity());
    _checkLocalFile();
  }

  // Проверяем наличие локального файла
  Future<void> _checkLocalFile() async {
    try {
      final localPath = await MediaStorageService.instance.getLocalPath(widget.imageUrl);
      if (mounted) {
        setState(() {
          _localPath = localPath;
          _isCheckingLocal = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingLocal = false;
        });
      }
    }
  }

  // Формируем полный URL или используем локальный путь
  String get _imageSource {
    if (_localPath != null) {
      return _localPath!;
    }
    
    final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
    final imageUrl = widget.imageUrl;
    
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    return '$baseUrl$imageUrl';
  }
  
  bool get _isLocalFile => _localPath != null;

  // Скачивание изображения
  Future<void> _downloadImage() async {
    if (_isDownloading) return;

    try {
      setState(() {
        _isDownloading = true;
      });

      // Запрашиваем разрешение на сохранение (только для iOS, Android 10+ не требует)
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        final status = await Permission.photos.status;
        if (status.isDenied) {
          final result = await Permission.photos.request();
          if (result.isDenied || result.isPermanentlyDenied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result.isPermanentlyDenied
                        ? 'Разрешение отклонено. Пожалуйста, включите его в настройках приложения'
                        : 'Необходимо разрешение на сохранение файлов',
                  ),
                  backgroundColor: Colors.orange,
                  action: result.isPermanentlyDenied
                      ? SnackBarAction(
                          label: 'Настройки',
                          onPressed: () => openAppSettings(),
                        )
                      : null,
                ),
              );
            }
            return;
          }
        }
      }

      // print('[ImageViewer] 📥 Начинаем скачивание: ${widget.imageUrl}');

      // Формируем полный URL для скачивания
      String fullUrl = widget.imageUrl;
      if (!widget.imageUrl.startsWith('http://') && !widget.imageUrl.startsWith('https://')) {
        final baseUrl = ApiService.baseUrl.replaceAll('/backend/api', '');
        fullUrl = '$baseUrl${widget.imageUrl}';
      }
      
      // Скачиваем изображение
      final dio = Dio();
      final response = await dio.get(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final bytes = Uint8List.fromList(response.data as List<int>);
        // print('[ImageViewer] ✅ Изображение скачано: ${bytes.length} bytes');

        // Сохраняем в галерею используя gal
        await Gal.putImageBytes(
          bytes,
          name: widget.fileName ?? 'securewave_${DateTime.now().millisecondsSinceEpoch}',
        );

        // print('[ImageViewer] ✅ Изображение сохранено в галерею');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Изображение сохранено в галерею'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Ошибка скачивания: ${response.statusCode}');
      }
    } catch (e) {
      // print('[ImageViewer] ❌ Ошибка скачивания: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка скачивания: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }
  
  Widget _buildErrorWidget(dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.broken_image,
            color: Colors.white70,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Ошибка загрузки изображения',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download, color: Colors.white),
            onPressed: _isDownloading ? null : _downloadImage,
            tooltip: 'Скачать изображение',
          ),
        ],
      ),
      body: _isCheckingLocal
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: _isLocalFile
                          ? Image.file(
                              File(_localPath!),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Если локальный файл поврежден, загружаем с сервера
                                return CachedNetworkImage(
                                  imageUrl: _imageSource,
                                  fit: BoxFit.contain,
                                  httpHeaders: {
                                    'Accept': 'image/*',
                                  },
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => _buildErrorWidget(error),
                                );
                              },
                            )
                          : CachedNetworkImage(
                              imageUrl: _imageSource,
                              fit: BoxFit.contain,
                              httpHeaders: {
                                'Accept': 'image/*',
                              },
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => _buildErrorWidget(error),
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

