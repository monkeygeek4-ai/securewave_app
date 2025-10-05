// lib/helpers/call_helper.dart

import 'package:flutter/material.dart';

class CallHelper {
  /// Определяет текст статуса звонка
  static String getCallStatusText({
    required String direction, // 'incoming' или 'outgoing'
    required String status, // 'ended', 'declined', 'missed', 'cancelled'
    String? endReason,
  }) {
    if (direction == 'outgoing') {
      // Исходящие звонки
      switch (status) {
        case 'ended':
          return 'Исходящий звонок';
        case 'declined':
          return 'Отклонен';
        case 'cancelled':
          return 'Отменен';
        case 'missed':
          return 'Не ответили';
        default:
          return 'Исходящий звонок';
      }
    } else {
      // Входящие звонки
      switch (status) {
        case 'ended':
          return 'Входящий звонок';
        case 'declined':
          return 'Отклонен';
        case 'missed':
          return 'Пропущенный';
        default:
          return 'Входящий звонок';
      }
    }
  }

  /// Определяет иконку для статуса звонка
  static IconData getCallStatusIcon({
    required String direction,
    required String status,
    required String callType, // 'audio' или 'video'
  }) {
    // Базовая иконка в зависимости от типа звонка
    final bool isVideo = callType == 'video';

    if (direction == 'outgoing') {
      // Исходящие звонки
      switch (status) {
        case 'ended':
          return isVideo ? Icons.video_call : Icons.call_made;
        case 'declined':
          return Icons.call_missed_outgoing;
        case 'cancelled':
          return Icons.call_missed_outgoing;
        default:
          return isVideo ? Icons.video_call : Icons.call_made;
      }
    } else {
      // Входящие звонки
      switch (status) {
        case 'ended':
          return isVideo ? Icons.video_call : Icons.call_received;
        case 'declined':
          return Icons.call_missed;
        case 'missed':
          return Icons.call_missed;
        default:
          return isVideo ? Icons.video_call : Icons.call_received;
      }
    }
  }

  /// Определяет цвет для статуса звонка
  static Color getCallStatusColor({
    required String direction,
    required String status,
  }) {
    if (direction == 'outgoing') {
      switch (status) {
        case 'ended':
          return Colors.green;
        case 'declined':
          return Colors.red;
        case 'cancelled':
          return Colors.orange;
        default:
          return Colors.blue;
      }
    } else {
      switch (status) {
        case 'ended':
          return Colors.green;
        case 'declined':
          return Colors.red;
        case 'missed':
          return Colors.red;
        default:
          return Colors.blue;
      }
    }
  }

  /// Форматирует длительность звонка
  static String formatDuration(int? seconds) {
    if (seconds == null || seconds == 0) {
      return '';
    }

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '${minutes}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${secs}с';
    }
  }

  /// Определяет, был ли звонок успешным (состоялся разговор)
  static bool isSuccessfulCall(String status) {
    return status == 'ended';
  }

  /// Определяет статус на основе данных из БД
  static String determineCallStatus({
    required String direction,
    required String
        dbStatus, // статус из БД: 'pending', 'active', 'ended', 'declined'
    String? endReason,
    int? duration,
  }) {
    // Если звонок был отклонен
    if (dbStatus == 'declined') {
      return 'declined';
    }

    // Если звонок завершился
    if (dbStatus == 'ended') {
      // Проверяем причину завершения
      if (endReason == 'timeout' || endReason == 'no_answer') {
        return 'missed'; // Пропущенный
      }

      if (endReason == 'cancelled' || endReason == 'caller_cancelled') {
        return 'cancelled'; // Отменен инициатором
      }

      // Если была длительность - значит разговор состоялся
      if (duration != null && duration > 0) {
        return 'ended'; // Успешный звонок
      }

      // Если нет длительности и входящий - пропущенный
      if (direction == 'incoming') {
        return 'missed';
      }

      // Если исходящий без длительности - не ответили
      return 'cancelled';
    }

    // По умолчанию
    return dbStatus;
  }
}
