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
        private const val CHANNEL_MESSAGES = "messages_channel"
        private const val CHANNEL_CALLS = "calls_channel"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🔥 Firebase Service создан")
        createNotificationChannels()
    }

    /**
     * Вызывается при получении нового FCM токена
     */
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "🔑 Новый FCM токен: $token")
        
        // Отправляем токен во Flutter
        sendTokenToFlutter(token)
        
        // Можно также отправить токен на бэкенд сразу здесь
        // sendTokenToBackend(token)
    }

    /**
     * Вызывается при получении уведомления
     */
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        Log.d(TAG, "📩 Получено уведомление от: ${remoteMessage.from}")
        
        // Получаем данные
        val data = remoteMessage.data
        val type = data["type"] ?: "unknown"
        
        Log.d(TAG, "📦 Тип уведомления: $type")
        Log.d(TAG, "📦 Данные: $data")
        
        // Обрабатываем в зависимости от типа
        when (type) {
            "new_message" -> handleNewMessage(remoteMessage)
            "incoming_call" -> handleIncomingCall(remoteMessage)
            "call_ended" -> handleCallEnded(remoteMessage)
            else -> {
                Log.w(TAG, "⚠️ Неизвестный тип уведомления: $type")
                // Показываем обычное уведомление
                showDefaultNotification(remoteMessage)
            }
        }
    }

    /**
     * Обработка нового сообщения
     */
    private fun handleNewMessage(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val chatId = data["chatId"] ?: return
        val senderName = data["senderName"] ?: "Новое сообщение"
        val messageText = data["messageText"] ?: ""
        
        Log.d(TAG, "💬 Новое сообщение от $senderName: $messageText")
        
        val notification = remoteMessage.notification
        val title = notification?.title ?: senderName
        val body = notification?.body ?: messageText
        
        showMessageNotification(
            title = title,
            message = body,
            chatId = chatId
        )
    }

    /**
     * Обработка входящего звонка
     */
    private fun handleIncomingCall(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val callId = data["callId"] ?: return
        val callerName = data["callerName"] ?: "Неизвестный"
        val callType = data["callType"] ?: "audio"
        
        Log.d(TAG, "📞 Входящий звонок от $callerName (тип: $callType)")
        
        val notification = remoteMessage.notification
        val title = notification?.title ?: "Входящий звонок"
        val body = notification?.body ?: "Звонок от $callerName"
        
        showCallNotification(
            title = title,
            message = body,
            callId = callId,
            callerName = callerName,
            callType = callType
        )
    }

    /**
     * Обработка завершения звонка
     */
    private fun handleCallEnded(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val callId = data["callId"] ?: return
        
        Log.d(TAG, "📵 Звонок завершен: $callId")
        
        // Отменяем уведомление о звонке
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(callId.hashCode())
    }

    /**
     * Показать уведомление о новом сообщении
     */
    private fun showMessageNotification(title: String, message: String, chatId: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("type", "new_message")
            putExtra("chatId", chatId)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            chatId.hashCode(),
            intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_MESSAGES)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(message)
            .setAutoCancel(true)
            .setSound(defaultSoundUri)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(chatId.hashCode(), notificationBuilder.build())
        
        Log.d(TAG, "✅ Уведомление о сообщении показано")
    }

    /**
     * Показать уведомление о входящем звонке
     */
    private fun showCallNotification(
        title: String,
        message: String,
        callId: String,
        callerName: String,
        callType: String
    ) {
        // Intent для принятия звонка
        val acceptIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("action", "accept")
        }
        
        val acceptPendingIntent = PendingIntent.getActivity(
            this,
            (callId + "_accept").hashCode(),
            acceptIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Intent для отклонения звонка
        val declineIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("action", "decline")
        }
        
        val declinePendingIntent = PendingIntent.getActivity(
            this,
            (callId + "_decline").hashCode(),
            declineIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val callSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_CALLS)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(message)
            .setAutoCancel(false)
            .setOngoing(true)
            .setSound(callSoundUri)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(acceptPendingIntent, true)
            .addAction(R.drawable.ic_call_accept, "Принять", acceptPendingIntent)
            .addAction(R.drawable.ic_call_decline, "Отклонить", declinePendingIntent)
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(callId.hashCode(), notificationBuilder.build())
        
        Log.d(TAG, "✅ Уведомление о звонке показано")
    }

    /**
     * Показать стандартное уведомление
     */
    private fun showDefaultNotification(remoteMessage: RemoteMessage) {
        val notification = remoteMessage.notification ?: return
        val title = notification.title ?: "SecureWave"
        val body = notification.body ?: ""
        
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_MESSAGES)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(0, notificationBuilder.build())
    }

    /**
     * Создание каналов уведомлений для Android 8.0+
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Канал для сообщений
            val messagesChannel = NotificationChannel(
                CHANNEL_MESSAGES,
                "Сообщения",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Уведомления о новых сообщениях"
                enableVibration(true)
                enableLights(true)
            }
            
            // Канал для звонков
            val callsChannel = NotificationChannel(
                CHANNEL_CALLS,
                "Звонки",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Уведомления о входящих звонках"
                enableVibration(true)
                enableLights(true)
                setBypassDnd(true)
            }
            
            notificationManager.createNotificationChannel(messagesChannel)
            notificationManager.createNotificationChannel(callsChannel)
            
            Log.d(TAG, "📱 Каналы уведомлений созданы")
        }
    }

    /**
     * Отправка токена во Flutter
     */
    private fun sendTokenToFlutter(token: String) {
        // Здесь можно использовать MethodChannel для передачи токена во Flutter
        // Или сохранить в SharedPreferences для последующего получения из Flutter
        val sharedPreferences = getSharedPreferences("FCM_PREFS", Context.MODE_PRIVATE)
        sharedPreferences.edit().putString("fcm_token", token).apply()
        Log.d(TAG, "💾 Токен сохранен в SharedPreferences")
    }
}