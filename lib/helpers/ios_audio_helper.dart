// lib/helpers/ios_audio_helper.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IOSAudioHelper {
  static const platform = MethodChannel('com.securewave.app/audio');

  /// Настраивает AVAudioSession для VoIP звонков
  /// Вызывается ПОСЛЕ создания PeerConnection (аналогично Android)
  static Future<void> configureAudioSession() async {
    if (kIsWeb || !Platform.isIOS) {
      // print('[iOS Audio Helper] ⏭️ Пропускаем (не iOS)');
      return;
    }

    try {
      // print('[iOS Audio Helper] 🔧 Настройка AVAudioSession...');
      await platform.invokeMethod('configureAudioSession');
      // print('[iOS Audio Helper] ✅ AVAudioSession настроен');
    } catch (e) {
      // print('[iOS Audio Helper] ❌ Ошибка настройки: $e');
    }
  }

  /// Включает/выключает громкую связь
  static Future<void> setSpeakerphone(bool enabled) async {
    if (kIsWeb || !Platform.isIOS) {
      // print('[iOS Audio Helper] ⏭️ Пропускаем (не iOS)');
      return;
    }

    try {
      // print('[iOS Audio Helper] 🔊 Устанавливаем speakerphone: $enabled');
      // ⭐⭐⭐ ИСПРАВЛЕНО: Используем правильное имя метода
      await platform.invokeMethod('setSpeakerEnabled', {'enabled': enabled});
      // print('[iOS Audio Helper] ✅ Speakerphone: $enabled');
    } catch (e) {
      // print('[iOS Audio Helper] ❌ Ошибка setSpeakerphone: $e');
    }
  }
}
