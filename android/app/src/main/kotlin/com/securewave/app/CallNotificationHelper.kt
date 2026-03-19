package com.securewave.app

import android.app.ActivityManager
import android.app.ActivityOptions
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * ⭐⭐⭐ КРИТИЧНО: Helper для показа incoming call notifications
 * Использует full-screen intent для обхода BAL (Background Activity Launch) на Android 10+
 */
object CallNotificationHelper {
    private const val TAG = "CallNotification"
    // ⭐⭐⭐ ВАЖНО: Изменили ID канала чтобы пересоздать с IMPORTANCE_MAX
    // Старый канал: "incoming_calls"
    private const val CHANNEL_ID = "incoming_calls_v2"
    private const val CHANNEL_NAME = "Входящие звонки"

    /**
     * Показать уведомление о входящем звонке с full-screen intent
     */
    fun showIncomingCallNotification(
        context: Context,
        callId: String,
        callerName: String,
        callType: String,
        callerAvatar: String? = null
    ) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📱 Показываем notification с full-screen intent")
        Log.d(TAG, "callId: $callId")
        Log.d(TAG, "callerName: $callerName")
        Log.d(TAG, "callType: $callType")
        Log.d(TAG, "callerAvatar: $callerAvatar")
        Log.d(TAG, "========================================")

        // Создаем notification channel (Android 8+)
        createNotificationChannel(context)

        // ⭐⭐⭐ КРИТИЧНО: Full-screen Intent для запуска CallActivity
        // Это единственный способ запустить Activity из фона на Android 10+
        val fullScreenIntent = Intent(context, CallActivity::class.java).apply {
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            // ⭐⭐⭐ КРИТИЧНО: Передаем аватар
            if (!callerAvatar.isNullOrEmpty()) {
                putExtra("callerAvatar", callerAvatar)
            }
            // ⭐⭐⭐ КРИТИЧНО: Флаги для показа поверх заблокированного экрана
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION)
            addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
            addFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            // ⭐⭐⭐ КРИТИЧНО: Для Android 10+ нужно использовать FLAG_ACTIVITY_CLEAR_TASK
            // чтобы гарантировать, что Activity откроется даже если приложение уже запущено
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
            // ⭐⭐⭐ КРИТИЧНО: Для Android 12+ добавляем дополнительные флаги
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT)
            }
        }

        // ⭐⭐⭐ КРИТИЧНО: НЕ используем FLAG_ONE_SHOT для full-screen intent
        // FLAG_ONE_SHOT может помешать системе открыть Activity автоматически
        // Используем FLAG_UPDATE_CURRENT и FLAG_IMMUTABLE для Android 12+
        // На Android 12+ нужно использовать FLAG_MUTABLE для full-screen intent, чтобы система могла его выполнить
        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            callId.hashCode(),
            fullScreenIntent,
            pendingIntentFlags
        )
        
        Log.d(TAG, "✅ Full-screen PendingIntent создан")
        Log.d(TAG, "   - Flags: UPDATE_CURRENT | IMMUTABLE")
        Log.d(TAG, "   - Request Code: ${callId.hashCode()}")

        // Content intent - открывает CallActivity при клике на notification
        val contentIntent = Intent(context, CallActivity::class.java).apply {
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            if (!callerAvatar.isNullOrEmpty()) {
                putExtra("callerAvatar", callerAvatar)
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        val contentPendingIntent = PendingIntent.getActivity(
            context,
            callId.hashCode() + 1,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline intent - отклонить звонок через BroadcastReceiver
        val declineIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_DECLINE_CALL
            putExtra("callId", callId)
        }

        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            callId.hashCode() + 2,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Звук звонка
        val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        // ⭐⭐⭐ КРИТИЧНО: На Android 12+ при разблокированном экране не добавляем action buttons
        // так как CallActivity запускается напрямую и notification не должен показываться
        val shouldAddActions = Build.VERSION.SDK_INT < Build.VERSION_CODES.S
        
        // Строим notification
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_call_24) // Используем иконку звонка
            .setContentTitle("Входящий ${if (callType == "video") "видео" else "аудио"} звонок")
            .setContentText(callerName)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true) // Нельзя смахнуть
            .setAutoCancel(false)
            .setSound(ringtoneUri)
            .setVibrate(longArrayOf(0, 1000, 500, 1000)) // Вибрация
            .setLights(Color.GREEN, 1000, 1000)
            .setContentIntent(contentPendingIntent)

            // ⭐⭐⭐ КРИТИЧНО: Full-screen intent
            // На Android 10+ это единственный способ показать Activity из фона
            // ⭐⭐⭐ ИСПРАВЛЕНО: Устанавливаем highPriority = true для принудительного показа
            .setFullScreenIntent(fullScreenPendingIntent, true)
            // ⭐⭐⭐ КРИТИЧНО: Content intent используется когда full-screen intent не сработал
            // (например, если экран уже разблокирован)
            .setContentIntent(contentPendingIntent)

        // ⭐⭐⭐ КРИТИЧНО: Action buttons только для Android < 12
        // На Android 12+ при разблокированном экране CallActivity запускается напрямую,
        // поэтому action buttons не нужны и могут мешать полноэкранному отображению
        if (shouldAddActions) {
            builder.addAction(
                R.drawable.ic_call_end_24,
                "Отклонить",
                declinePendingIntent
            )
            Log.d(TAG, "✅ Action buttons добавлены (Android < 12)")
        } else {
            Log.d(TAG, "ℹ️ Action buttons НЕ добавлены (Android 12+ - CallActivity запускается напрямую)")
        }

        // Для Android 12+ (API 31+) требуется Notification.FLAG_INSISTENT для повторного звука
        // ⭐⭐⭐ КРИТИЧНО: Для Honor (EMUI) и других кастомных оболочек
        // Добавляем дополнительные флаги для гарантированного показа
        val notification = builder.build().apply {
            flags = flags or Notification.FLAG_INSISTENT
            // ⭐⭐⭐ КРИТИЧНО: FLAG_HIGH_PRIORITY для принудительного показа даже на кастомных оболочках
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                flags = flags or Notification.FLAG_HIGH_PRIORITY
            }
            // ⭐⭐⭐ КРИТИЧНО: FLAG_NO_CLEAR для предотвращения случайного закрытия
            flags = flags or Notification.FLAG_NO_CLEAR
        }

        // Показываем notification
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Проверяем permission для full-screen intent (Android 14+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val canUseFullScreen = notificationManager.canUseFullScreenIntent()
            Log.d(TAG, "========================================")
            Log.d(TAG, "📱 Android 14+ detected - checking full-screen intent permission")
            Log.d(TAG, "canUseFullScreenIntent: $canUseFullScreen")
            Log.d(TAG, "========================================")

            if (!canUseFullScreen) {
                Log.e(TAG, "========================================")
                Log.e(TAG, "❌❌❌ КРИТИЧНО: Full-screen intent permission НЕ ПРЕДОСТАВЛЕНО!")
                Log.e(TAG, "❌ Notification НЕ СМОЖЕТ автоматически запустить Activity!")
                Log.e(TAG, "❌ Пользователь должен дать разрешение в:")
                Log.e(TAG, "   Settings > Apps > SecureWave > Notifications > Allow full-screen notifications")
                Log.e(TAG, "========================================")
            } else {
                Log.d(TAG, "✅ Full-screen intent permission ЕСТЬ")
            }
        } else {
            Log.d(TAG, "📱 Android < 14 - full-screen intent работает без дополнительных разрешений")
        }

        // ⭐⭐⭐ КРИТИЧНО: Проверяем, что notification channel имеет IMPORTANCE_MAX
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (channel != null) {
                Log.d(TAG, "========================================")
                Log.d(TAG, "📺 Notification Channel Info:")
                Log.d(TAG, "   - ID: ${channel.id}")
                Log.d(TAG, "   - Name: ${channel.name}")
                Log.d(TAG, "   - Importance: ${channel.importance}")
                Log.d(TAG, "   - Can Show Badge: ${channel.canShowBadge()}")
                Log.d(TAG, "   - Can Bypass DND: ${channel.canBypassDnd()}")
                Log.d(TAG, "========================================")
                
                if (channel.importance != NotificationManager.IMPORTANCE_MAX) {
                    Log.e(TAG, "❌❌❌ КРИТИЧНО: Notification channel НЕ имеет IMPORTANCE_MAX!")
                    Log.e(TAG, "❌ Full-screen intent может не работать!")
                    Log.e(TAG, "   Текущий importance: ${channel.importance}")
                    Log.e(TAG, "   Требуется: ${NotificationManager.IMPORTANCE_MAX}")
                } else {
                    Log.d(TAG, "✅ Notification channel имеет IMPORTANCE_MAX")
                }
            } else {
                Log.e(TAG, "❌ Notification channel не найден: $CHANNEL_ID")
            }
        }

        Log.d(TAG, "========================================")
        Log.d(TAG, "📤 Показываем notification с full-screen intent")
        Log.d(TAG, "   - Notification ID: ${callId.hashCode()}")
        Log.d(TAG, "   - Has Full-Screen Intent: true")
        Log.d(TAG, "   - High Priority: true")
        Log.d(TAG, "   - Flags: INSISTENT | NO_CLEAR")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: На Android 12+ система строго блокирует запуск Activity из фонового сервиса (BAL)
        // Единственный надежный способ - использовать full-screen notification
        // Full-screen intent должен автоматически открыть CallActivity даже при разблокированном экране
        // если notification channel имеет IMPORTANCE_MAX и full-screen intent permission предоставлено
        
        // ⭐⭐⭐ КРИТИЧНО: Для Honor (EMUI) и других кастомных оболочек
        // Убеждаемся, что notification channel имеет правильные настройки перед показом
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (channel != null) {
                Log.d(TAG, "========================================")
                Log.d(TAG, "🔍 Финальная проверка notification channel:")
                Log.d(TAG, "   - ID: ${channel.id}")
                Log.d(TAG, "   - Importance: ${channel.importance}")
                Log.d(TAG, "   - IMPORTANCE_MAX: ${NotificationManager.IMPORTANCE_MAX}")
                Log.d(TAG, "   - Can Bypass DND: ${channel.canBypassDnd()}")
                Log.d(TAG, "   - Lockscreen Visibility: ${channel.lockscreenVisibility}")
                Log.d(TAG, "========================================")
                
                if (channel.importance != NotificationManager.IMPORTANCE_MAX) {
                    Log.e(TAG, "❌❌❌ КРИТИЧНО: Channel importance НЕ MAX перед показом!")
                    Log.e(TAG, "   Пересоздаем channel...")
                    try {
                        notificationManager.deleteNotificationChannel(CHANNEL_ID)
                        createNotificationChannel(context)
                        Log.d(TAG, "✅ Channel пересоздан")
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Ошибка пересоздания channel: ${e.message}")
                    }
                }
            }
        }
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "📤 Показываем full-screen notification")
        Log.d(TAG, "   Full-screen intent должен автоматически открыть CallActivity")
        Log.d(TAG, "   Даже при заблокированном экране (Honor/EMUI)")
        Log.d(TAG, "========================================")
        
        notificationManager.notify(callId.hashCode(), notification)
        Log.d(TAG, "✅ Notification показано с ID: ${callId.hashCode()}")
        
        // ⭐⭐⭐ КРИТИЧНО: Для Honor (EMUI) может потребоваться дополнительная проверка
        // Проверяем, что notification действительно показано с full-screen intent
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val activeNotifications = notificationManager.activeNotifications
            val ourNotification = activeNotifications.find { it.id == callId.hashCode() }
            if (ourNotification != null) {
                Log.d(TAG, "========================================")
                Log.d(TAG, "✅ Notification активно показано")
                Log.d(TAG, "   - ID: ${ourNotification.id}")
                Log.d(TAG, "   - Tag: ${ourNotification.tag}")
                Log.d(TAG, "   - Has Full-Screen Intent: ${ourNotification.notification.fullScreenIntent != null}")
                Log.d(TAG, "========================================")
            } else {
                Log.e(TAG, "❌❌❌ КРИТИЧНО: Notification НЕ найдено в activeNotifications!")
                Log.e(TAG, "   Это может означать, что система заблокировала notification")
            }
        }
        
        Log.d(TAG, "========================================")
    }

    /**
     * Отменить уведомление о звонке и остановить вибрацию
     */
    fun cancelNotification(context: Context, callId: String) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚫 Отменяем notification: $callId (ID: ${callId.hashCode()})")
        Log.d(TAG, "========================================")

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // ⭐⭐⭐ КРИТИЧНО: Отменяем уведомление - это остановит вибрацию и звук
        notificationManager.cancel(callId.hashCode())
        
        // ⭐⭐⭐ КРИТИЧНО: Также отменяем уведомления с похожими ID (на случай разных вариантов)
        notificationManager.cancel(callId.hashCode() + 1)
        notificationManager.cancel(callId.hashCode() + 2)
        
        // ⭐⭐⭐ КРИТИЧНО: Явно останавливаем вибрацию
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vibratorManager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            
            vibrator.cancel()
            Log.d(TAG, "✅ Вибрация явно остановлена")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Ошибка остановки вибрации: ${e.message}")
        }
        
        Log.d(TAG, "✅ Notification отменено, вибрация остановлена")
        Log.d(TAG, "========================================")
    }

    /**
     * Создать notification channel (Android 8+)
     */
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // ⭐⭐⭐ КРИТИЧНО: На Honor (EMUI) система может изменять importance channel
            // Всегда удаляем существующий channel перед созданием нового
            // чтобы гарантировать правильные настройки
            try {
                val existingChannel = notificationManager.getNotificationChannel(CHANNEL_ID)
                if (existingChannel != null) {
                    Log.d(TAG, "⚠️ Существующий channel найден, удаляем для пересоздания...")
                    Log.d(TAG, "   Текущий importance: ${existingChannel.importance}")
                    notificationManager.deleteNotificationChannel(CHANNEL_ID)
                    Log.d(TAG, "✅ Существующий channel удален")
                }
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Ошибка при удалении существующего channel: ${e.message}")
            }

            Log.d(TAG, "📺 Создаем notification channel: $CHANNEL_ID")

            // Звуковые атрибуты
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()

            // ⭐⭐⭐ КРИТИЧНО: IMPORTANCE_MAX для full-screen intent
            // IMPORTANCE_HIGH недостаточно для автоматического запуска Activity
            // На Honor (EMUI) и других кастомных оболочках может потребоваться пересоздание channel
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Уведомления о входящих звонках"
                enableLights(true)
                lightColor = Color.GREEN
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE), audioAttributes)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true) // Показывать даже в режиме "Не беспокоить"
                // ⭐⭐⭐ КРИТИЧНО: Для Honor (EMUI) и других кастомных оболочек
                // Устанавливаем максимальный приоритет для гарантированного показа
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setAllowBubbles(false) // Не показывать как bubble
                }
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel создан")
            
            // ⭐⭐⭐ КРИТИЧНО: Проверяем, что channel действительно создан с правильными настройками
            val createdChannel = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (createdChannel != null) {
                Log.d(TAG, "========================================")
                Log.d(TAG, "🔍 Проверка созданного channel:")
                Log.d(TAG, "   - ID: ${createdChannel.id}")
                Log.d(TAG, "   - Importance: ${createdChannel.importance}")
                Log.d(TAG, "   - IMPORTANCE_MAX: ${NotificationManager.IMPORTANCE_MAX}")
                Log.d(TAG, "   - Can Bypass DND: ${createdChannel.canBypassDnd()}")
                Log.d(TAG, "   - Lockscreen Visibility: ${createdChannel.lockscreenVisibility}")
                Log.d(TAG, "========================================")
                
                if (createdChannel.importance != NotificationManager.IMPORTANCE_MAX) {
                    Log.e(TAG, "❌❌❌ КРИТИЧНО: Созданный channel НЕ имеет IMPORTANCE_MAX!")
                    Log.e(TAG, "   Система (Honor/EMUI) переопределила настройки!")
                    Log.e(TAG, "   Текущий importance: ${createdChannel.importance}")
                    Log.e(TAG, "   Требуется: ${NotificationManager.IMPORTANCE_MAX}")
                } else {
                    Log.d(TAG, "✅ Channel создан с правильным IMPORTANCE_MAX")
                }
            } else {
                Log.e(TAG, "❌❌❌ КРИТИЧНО: Channel НЕ найден после создания!")
            }
        }
    }
}
