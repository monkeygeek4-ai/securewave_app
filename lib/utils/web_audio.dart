// lib/utils/web_audio.dart
// Условный импорт для кроссплатформенности

// ⭐⭐⭐ КРИТИЧНО: Условный импорт
// Для Web использует dart:html, для Mobile - заглушку
export 'web_audio_stub.dart' if (dart.library.html) 'web_audio_real.dart';
