package com.securewave.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FCM_Service"
        private const val CHANNEL_ID_CALLS = "calls_channel"
        private const val CHANNEL_ID_MESSAGES = "messages_channel"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔥 Firebase Service создан")
        Log.d(TAG, "========================================")
        createNotificationChannels()
    }

    /**
     * ⭐⭐⭐ КРИТИЧНО: Вызывается когда приходит FCM сообщение
     * Работает ВСЕГДА: foreground, background, terminated!
     */
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📩 📩 📩 FCM MESSAGE RECEIVED! 📩 📩 📩")
        Log.d(TAG, "========================================")
        Log.d(TAG, "От: ${remoteMessage.from}")
        Log.d(TAG, "Message ID: ${remoteMessage.messageId}")
        Log.d(TAG, "========================================")

        // Получаем данные
        val data = remoteMessage.data
        val type = data["type"]

        Log.d(TAG, "📦 Тип уведомления: $type")
        Log.d(TAG, "📦 Все данные:")
        data.forEach { (key, value) ->
            Log.d(TAG, "  - $key: $value")
        }
        Log.d(TAG, "========================================")

        when (type) {
            "incoming_call" -> {
                Log.d(TAG, "📞📞📞 ВХОДЯЩИЙ ЗВОНОК ОБНАРУЖЕН!")
                
                val callId = data["callId"] ?: data["call_id"] ?: run {
                    Log.e(TAG, "❌ ОШИБКА: callId отсутствует!")
                    return
                }
                
                val callerName = data["callerName"] ?: data["caller_name"] ?: "Unknown"
                val callType = data["callType"] ?: data["call_type"] ?: "audio"
                
                Log.d(TAG, "========================================")
                Log.d(TAG, "📋 Параметры звонка:")
                Log.d(TAG, "  - callId: $callId")
                Log.d(TAG, "  - callerName: $callerName")
                Log.d(TAG, "  - callType: $callType")
                Log.d(TAG, "========================================")
                
                // ⭐⭐⭐ ЗАПУСКАЕМ CallService НАПРЯМУЮ!
                Log.d(TAG, "🚀🚀🚀 ЗАПУСКАЕМ CallService...")
                try {
                    CallService.startService(this, callId, callerName, callType)
                    Log.d(TAG, "✅ CallService.startService() вызван успешно!")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Ошибка запуска CallService: ${e.message}")
                    e.printStackTrace()
                }
            }
            
            "new_message" -> {
                val chatId = data["chatId"] ?: return
                val senderName = data["senderName"] ?: "Unknown"
                val messageText = data["messageText"] ?: ""
                
                Log.d(TAG, "💬 Новое сообщение от $senderName")
                // Здесь можно показать обычное уведомление
            }
            
            "call_ended" -> {
                val callId = data["callId"] ?: return
                Log.d(TAG, "📵 Звонок завершен: $callId")
                // Отменяем уведомление если есть
            }
            
            else -> {
                Log.d(TAG, "❓ Неизвестный тип сообщения: $type")
            }
        }
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "✅ onMessageReceived завершен")
        Log.d(TAG, "========================================")
    }

    /**
     * Создание каналов уведомлений
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val callChannel = NotificationChannel(
                CHANNEL_ID_CALLS,
                "Входящие звонки",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Уведомления о входящих звонках"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            
            val messageChannel = NotificationChannel(
                CHANNEL_ID_MESSAGES,
                "Сообщения",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Уведомления о новых сообщениях"
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(callChannel)
            notificationManager.createNotificationChannel(messageChannel)
            
            Log.d(TAG, "📱 Каналы уведомлений созданы")
        }
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔄 Новый FCM токен получен!")
        Log.d(TAG, "Token: ${token.take(50)}...")
        Log.d(TAG, "========================================")
        // TODO: Отправить новый токен на сервер
    }
}