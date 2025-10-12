package com.securewave.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class CallService : Service() {
    companion object {
        private const val TAG = "CallService"
        private const val NOTIFICATION_ID = 12345
        private const val CHANNEL_ID = "call_service_channel"
        
        private var isCallActivityRunning = false
        
        fun startService(context: Context, callId: String, callerName: String, callType: String) {
            if (isCallActivityRunning) {
                Log.d(TAG, "⚠️ CallActivity уже запущена")
                return
            }
            
            val intent = Intent(context, CallService::class.java)
            intent.putExtra("callId", callId)
            intent.putExtra("callerName", callerName)
            intent.putExtra("callType", callType)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun resetCallActivityFlag() {
            isCallActivityRunning = false
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CallService onCreate")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 CallService onStartCommand")
        Log.d(TAG, "========================================")
        
        val callId = intent?.getStringExtra("callId") ?: "unknown"
        val callerName = intent?.getStringExtra("callerName") ?: "Unknown"
        val callType = intent?.getStringExtra("callType") ?: "audio"
        
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "Caller: $callerName")
        Log.d(TAG, "Type: $callType")
        
        // ⭐⭐⭐ КРИТИЧНО: Создаем Full-Screen Notification
        val notification = createFullScreenNotification(callId, callerName, callType)
        startForeground(NOTIFICATION_ID, notification)
        
        Log.d(TAG, "✅ Full-screen notification создано")
        Log.d(TAG, "========================================")
        
        // Останавливаем service через небольшую задержку
        android.os.Handler(mainLooper).postDelayed({
            stopForeground(STOP_FOREGROUND_DETACH) // Оставляем notification видимым
            stopSelf()
        }, 2000)
        
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Service",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Foreground service for incoming calls"
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    /**
     * ⭐⭐⭐ КРИТИЧНО: Full-Screen Notification для показа поверх lockscreen
     */
    private fun createFullScreenNotification(
        callId: String, 
        callerName: String, 
        callType: String
    ): Notification {
        
        // Intent для CallActivity
        val fullScreenIntent = Intent(this, CallActivity::class.java)
        fullScreenIntent.putExtra("callId", callId)
        fullScreenIntent.putExtra("callerName", callerName)
        fullScreenIntent.putExtra("callType", callType)
        fullScreenIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_NO_USER_ACTION
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            0,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Intent для кнопки "Отклонить"
        val declineIntent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = android.net.Uri.parse("securewave://call/$callId/decline")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("action", "decline")
        }
        
        val declinePendingIntent = PendingIntent.getActivity(
            this,
            1,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Intent для кнопки "Принять"
        val acceptIntent = Intent(this, CallActivity::class.java).apply {
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION
        }
        
        val acceptPendingIntent = PendingIntent.getActivity(
            this,
            2,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("📞 Входящий ${if (callType == "video") "видео" else "аудио"}звонок")
            .setContentText("От: $callerName")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(fullScreenPendingIntent, true) // ⭐ ЭТО КЛЮЧЕВОЕ!
            .setContentIntent(fullScreenPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(
                R.mipmap.ic_launcher, 
                "❌ Отклонить", 
                declinePendingIntent
            )
            .addAction(
                R.mipmap.ic_launcher, 
                "✅ Принять", 
                acceptPendingIntent
            )
            .setTimeoutAfter(30000) // Автоматически скрыть через 30 секунд
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}