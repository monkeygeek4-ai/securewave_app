// lib/widgets/delete_particles_animation.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Виджет для показа анимации частиц при удалении сообщения
/// Оптимизирован с использованием CustomPainter для лучшей производительности
class DeleteParticlesOverlay extends StatefulWidget {
  final GlobalKey messageKey;
  final VoidCallback onComplete;

  const DeleteParticlesOverlay({
    super.key,
    required this.messageKey,
    required this.onComplete,
  });

  @override
  State<DeleteParticlesOverlay> createState() => _DeleteParticlesOverlayState();
}

class _DeleteParticlesOverlayState extends State<DeleteParticlesOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  Offset? _messagePosition;
  Size? _messageSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Уменьшено для плавности
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    // Получаем позицию и размер сообщения
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getMessagePosition();
      // Создаем частицы после получения размера
      if (_messageSize != null) {
        _createParticles();
        _controller.forward();
      }
    });
  }

  void _getMessagePosition() {
    final RenderBox? renderBox =
        widget.messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.attached) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      setState(() {
        _messagePosition = position;
        _messageSize = size;
      });
    }
  }

  void _createParticles() {
    if (_messageSize == null) return;
    
    final random = math.Random();
    _particles.clear();
    
    // Оптимизировано: 300-500 частиц вместо 2000-3000 для лучшей производительности
    // Этого достаточно для визуального эффекта "песка"
    final particleCount = 300 + random.nextInt(200); // 300-500 частиц
    
    for (int i = 0; i < particleCount; i++) {
      // Частицы вылетают из разных точек сообщения
      final startX = random.nextDouble() * _messageSize!.width;
      final startY = random.nextDouble() * _messageSize!.height;
      
      // Угол разлета
      final angle = random.nextDouble() * 2 * math.pi;
      // Скорость разлета
      final speed = 100 + random.nextDouble() * 300;
      // Размер частиц
      final size = 2.0 + random.nextDouble() * 3.0; // 2-5 пикселей
      
      _particles.add(Particle(
        angle: angle,
        speed: speed,
        size: size,
        color: _getRandomColor(random),
        startX: startX,
        startY: startY,
      ));
    }
  }

  Color _getRandomColor(math.Random random) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.pink,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.red,
      Colors.cyan,
      Colors.indigo,
      Colors.teal,
    ];
    return colors[random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_messagePosition == null || _messageSize == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Stack(
        children: [
          // Анимация исчезновения сообщения
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _controller.value;
              final messageOpacity = math.max(0.0, 1.0 - progress * 2.0);
              
              if (messageOpacity <= 0) return const SizedBox.shrink();
              
              return Positioned(
                left: _messagePosition!.dx,
                top: _messagePosition!.dy,
                child: Opacity(
                  opacity: messageOpacity,
                  child: Container(
                    width: _messageSize!.width,
                    height: _messageSize!.height,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              );
            },
          ),
          // Частицы рисуются через CustomPainter (оптимизировано)
          Positioned.fill(
            child: CustomPaint(
              painter: ParticlesPainter(
                particles: _particles,
                messagePosition: _messagePosition!,
                progress: _controller.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter для эффективного рендеринга частиц
class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final Offset messagePosition;
  final double progress;

  ParticlesPainter({
    required this.particles,
    required this.messagePosition,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Частицы появляются быстро и медленно исчезают
    final particleOpacity = progress < 0.05 
        ? progress * 20 // Быстро появляются
        : (1.0 - (progress - 0.05) / 0.95); // Медленно исчезают
    
    if (particleOpacity <= 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      // Начальная позиция частицы
      final startX = messagePosition.dx + particle.startX;
      final startY = messagePosition.dy + particle.startY;
      
      // Расстояние полета
      final distance = particle.speed * progress;
      
      // Конечная позиция
      final x = startX + math.cos(particle.angle) * distance;
      final y = startY + math.sin(particle.angle) * distance;
      
      // Масштаб уменьшается при полете
      final scale = 0.7 + (1.0 - progress) * 0.3;
      final finalSize = particle.size * scale;
      
      // Рисуем частицу (без boxShadow для производительности)
      paint.color = particle.color.withOpacity(
        math.max(0.0, particleOpacity * 0.8),
      );
      
      canvas.drawCircle(
        Offset(x, y),
        finalSize / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) {
    // Перерисовываем только если изменился прогресс
    return oldDelegate.progress != progress;
  }
}

class Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double startX; // Начальная позиция X на сообщении
  final double startY; // Начальная позиция Y на сообщении

  Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.startX,
    required this.startY,
  });
}

/// Виджет-обертка для сообщения с поддержкой анимации удаления
class AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  final GlobalKey messageKey;
  final bool isDeleting;

  const AnimatedMessageBubble({
    super.key,
    required this.child,
    required this.messageKey,
    required this.isDeleting,
  });

  @override
  State<AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    if (widget.isDeleting) {
      _fadeController.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDeleting && !oldWidget.isDeleting) {
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.8).animate(
          CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
        ),
        child: widget.child,
      ),
    );
  }
}

