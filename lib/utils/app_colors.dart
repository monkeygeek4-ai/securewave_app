// lib/utils/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Основной фиолетовый градиент
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color gradientStart = Color(0xFF667EEA);
  static const Color gradientEnd = Color(0xFF764BA2);

  // Градиент для кнопок и элементов
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Градиент для вертикальных элементов
  static const LinearGradient verticalGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Розовый градиент для непрочитанных сообщений
  static const Color unreadPink = Color(0xFFE91E63);
  static const Color unreadPinkDark = Color(0xFFF50057);

  static const LinearGradient unreadGradient = LinearGradient(
    colors: [unreadPink, unreadPinkDark],
  );

  // Онлайн статус
  static const Color online = Color(0xFF00E676);

  // Темная тема
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkInput = Color(0xFF3D3D3D);

  // Светлая тема
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightBackgroundAlt = Color(0xFFE9ECEF);
  static const Color lightSurface = Color(0xFFFFFFFF);

  // Тени
  static BoxShadow primaryShadow = BoxShadow(
    color: primaryPurple.withOpacity(0.3),
    blurRadius: 8,
    offset: Offset(0, 4),
  );

  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static BoxShadow messageShadow = BoxShadow(
    color: primaryPurple.withOpacity(0.4),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  // Вспомогательные методы
  static Color getTextColor(BuildContext context, {bool inverse = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (inverse) {
      return isDark ? Colors.black87 : Colors.white;
    }
    return isDark ? Colors.white : Colors.black87;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white70 : Colors.black54;
  }

  static Color getCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkCard : lightSurface;
  }

  static Color getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBackground : lightBackground;
  }

  static Color getSurfaceColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkSurface : lightSurface;
  }

  static Color getInputColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkInput : Colors.grey[100]!;
  }

  // Градиенты для фона
  static LinearGradient getBackgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkSurface, darkBackground],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lightBackground, lightBackgroundAlt],
          );
  }
}
