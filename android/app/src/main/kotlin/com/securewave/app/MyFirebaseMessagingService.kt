package com.securewave.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
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
        Log.d(TAG, "🔥 Firebase Service создан")
        createNotificationChannels()
    }

    /**
     * Вызывается когда приходит FCM сообщение
     * ТОЛЬКО когда приложение в background/terminated!
     */
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📩 Получено уведомление от: ${remoteMessage.from}")
        Log.d(TAG, "========================================")

        // Получаем данные
        val data = remoteMessage.data
        val type = data["type"]

        Log.d(TAG, "📦 Тип уведомления: $type")
        Log.d(TAG, "📦 Данные: $data")

        when (type) {
            "incoming_call" -> {
                val callId = data["callId"] ?: return
                val callerName = data["callerName"] ?: "Unknown"
                val callType = data["callType"] ?: "audio"
                
                Log.d(TAG, "📞 Входящий звонок от $callerName (тип: $callType)")
                showCallNotification(callId, callerName, callType)
            }
            
            "new_message" -> {
                val chatId = data["chatId"] ?: return
                val senderName = data["senderName"] ?: "Unknown"
                val messageText = data["messageText"] ?: ""
                
                Log.d(TAG, "💬 Новое сообщение от $senderName")
                showMessageNotification(chatId, senderName, messageText)
            }
            
            "call_ended" -> {
                val callId = data["callId"] ?: return
                Log.d(TAG, "📵 Звонок завершен: $callId")
                cancelNotification(callId.hashCode())
            }
        }
    }

    /**
     * Показать уведомление о входящем звонке
     */
    private fun showCallNotification(callId: String, callerName: String, callType: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Intent для открытия приложения
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            callId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Intent для принятия звонка
        val acceptIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("action", "accept")
        }
        
        val acceptPendingIntent = PendingIntent.getActivity(
            this,
            (callId.hashCode() + 1),
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Intent для отклонения звонка
        val declineIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("action", "decline")
        }
        
        val declinePendingIntent = PendingIntent.getActivity(
            this,
            (callId.hashCode() + 2),
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val isVideo = callType == "video"
        val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID_CALLS)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("📞 ${if (isVideo) "Видеозвонок" else "Звонок"} от $callerName")
            .setContentText("Входящий ${if (isVideo) "видео" else "аудио"}звонок")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 1000, 500, 1000))
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .addAction(R.mipmap.ic_launcher, "❌ Отклонить", declinePendingIntent)
            .addAction(R.mipmap.ic_launcher, "✅ Принять", acceptPendingIntent)
            .build()
        
        notificationManager.notify(callId.hashCode(), notification)
        Log.d(TAG, "✅ Уведомление о звонке показано")
    }

    /**
     * Показать уведомление о сообщении
     */
    private fun showMessageNotification(chatId: String, senderName: String, messageText: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", "new_message")
            putExtra("chatId", chatId)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            chatId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID_MESSAGES)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("💬 $senderName")
            .setContentText(messageText)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        
        notificationManager.notify(chatId.hashCode(), notification)
    }

    /**
     * Отменить уведомление
     */
    private fun cancelNotification(notificationId: Int) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(notificationId)
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
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE),
                    null
                )
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
        Log.d(TAG, "🔄 Новый FCM токен: $token")
        // TODO: Отправить новый токен на сервер
    }
}