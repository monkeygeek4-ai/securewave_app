// lib/helpers/ios_callkit_helper.dart
import 'package:flutter/services.dart';
import 'dart:io';

/// ⭐⭐⭐ iOS CallKit Helper
/// Обертка для работы с CallKit на iOS
class IOSCallKitHelper {
  // ⭐ Правильный channel name - должен совпадать с AppDelegate.swift
  static const MethodChannel _callChannel =
      MethodChannel('com.securewave.app/call');

  static const MethodChannel _audioChannel =
      MethodChannel('com.securewave.app/audio');

  /// Получить VoIP токен (для отправки на backend)
  static Future<String?> getVoIPToken() async {
    if (!Platform.isIOS) return null;

    try {
      // print('[IOSCallKit] 📱 Запрашиваем VoIP Token...');
      // Токен уже запрашивается при старте приложения в AppDelegate
      // Здесь мы просто ждём его
      return null; // Токен придёт через callback voipTokenReceived
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка получения VoIP token: $e');
      return null;
    }
  }

  /// Показать нативный CallKit UI для входящего звонка
  static Future<bool> reportIncomingCall({
    required String callId,
    required String callerName,
    bool hasVideo = false,
  }) async {
    if (!Platform.isIOS) {
      // print('[IOSCallKit] ⚠️ Не iOS платформа, пропускаем');
      return false;
    }

    try {
      // print('[IOSCallKit] ========================================');
      // print('[IOSCallKit] 📞 Показываем CallKit UI');
      // print('[IOSCallKit] Call ID: $callId');
      // print('[IOSCallKit] Caller: $callerName');
      // print('[IOSCallKit] Video: $hasVideo');
      // print('[IOSCallKit] ========================================');

      final result = await _callChannel.invokeMethod('reportIncomingCall', {
        'callId': callId,
        'callerName': callerName,
        'hasVideo': hasVideo,
      });

      // print('[IOSCallKit] ✅ CallKit UI показан');
      return result == true;
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
      return false;
    }
  }

  /// Начать исходящий звонок через CallKit
  static Future<bool> startOutgoingCall({
    required String callId,
    required String handle,
    bool hasVideo = false,
  }) async {
    if (!Platform.isIOS) return false;

    try {
      // print('[IOSCallKit] ========================================');
      // print('[IOSCallKit] 📞 Начинаем исходящий звонок');
      // print('[IOSCallKit] Call ID: $callId');
      // print('[IOSCallKit] Handle: $handle');
      // print('[IOSCallKit] ========================================');

      final result = await _callChannel.invokeMethod('startOutgoingCall', {
        'callId': callId,
        'handle': handle,
        'hasVideo': hasVideo,
      });

      // print('[IOSCallKit] ✅ Исходящий звонок начат');
      return result == true;
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
      return false;
    }
  }

  /// Завершить звонок в CallKit
  static Future<void> endCall(String? callId) async {
    if (!Platform.isIOS) return;

    try {
      // print('[IOSCallKit] 🔴 Завершаем звонок: $callId');

      await _callChannel.invokeMethod('endCall', {
        'callId': callId,
      });

      // print('[IOSCallKit] ✅ Звонок завершён');
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
    }
  }

  /// Уведомить CallKit что звонок соединился
  static Future<void> reportCallConnected() async {
    if (!Platform.isIOS) return;

    try {
      // print('[IOSCallKit] ✅ Уведомляем CallKit: звонок соединён');
      await _callChannel.invokeMethod('reportCallConnected');
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
    }
  }

  /// Уведомить CallKit что звонок соединяется
  static Future<void> reportCallConnecting() async {
    if (!Platform.isIOS) return;

    try {
      // print('[IOSCallKit] ⏳ Уведомляем CallKit: звонок соединяется...');
      await _callChannel.invokeMethod('reportCallConnecting');
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
    }
  }

  /// Настроить audio session для VoIP звонка
  static Future<void> configureAudioSession() async {
    if (!Platform.isIOS) return;

    try {
      // print('[IOSCallKit] 🔊 Настраиваем Audio Session');
      await _audioChannel.invokeMethod('configureAudioSession');
      // print('[IOSCallKit] ✅ Audio Session настроена');
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
    }
  }

  /// Переключить на громкую связь (speaker)
  static Future<void> setSpeakerEnabled(bool enabled) async {
    if (!Platform.isIOS) return;

    try {
      // print('[IOSCallKit] 🔊 Переключение speaker: $enabled');
      await _audioChannel.invokeMethod('setSpeakerEnabled', {
        'enabled': enabled,
      });
      // print('[IOSCallKit] ✅ Speaker переключён');
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
    }
  }

  /// Проверить включён ли speaker
  static Future<bool> isSpeakerEnabled() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _audioChannel.invokeMethod('isSpeakerEnabled');
      return result == true;
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
      return false;
    }
  }

  /// Логировать состояние аудио
  static Future<void> logAudioState() async {
    if (!Platform.isIOS) return;

    try {
      await _audioChannel.invokeMethod('logAudioState');
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
    }
  }

  /// Деактивировать audio session
  static Future<void> deactivateAudioSession() async {
    if (!Platform.isIOS) return;

    try {
      // print('[IOSCallKit] 🔇 Деактивируем Audio Session');
      await _audioChannel.invokeMethod('deactivateAudioSession');
      // print('[IOSCallKit] ✅ Audio Session деактивирована');
    } catch (e) {
      // print('[IOSCallKit] ❌ Ошибка: $e');
    }
  }

  /// Слушать события от CallKit (принятие/отклонение звонка)
  static void setCallKitMethodCallHandler(
      Future<dynamic> Function(MethodCall call) handler) {
    _callChannel.setMethodCallHandler(handler);
  }
}
