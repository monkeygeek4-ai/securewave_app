package com.securewave.app

import android.app.ActivityManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * ⭐⭐⭐ Простой Service для запуска CallActivity
 * НЕ foreground service - просто bridge для обхода BAL (Background Activity Launch)
 */
class CallLauncherService : Service() {
    
    companion object {
        private const val TAG = "CallLauncher"
        
        fun launch(context: Context, callId: String, callerName: String, callType: String, callerAvatar: String? = null) {
            Log.d(TAG, "========================================")
            Log.d(TAG, "📞 CallLauncherService.launch вызван")
            Log.d(TAG, "Call ID: $callId")
            Log.d(TAG, "Caller: $callerName")
            Log.d(TAG, "Type: $callType")
            Log.d(TAG, "========================================")
            
            val intent = Intent(context, CallLauncherService::class.java)
            intent.putExtra("callId", callId)
            intent.putExtra("callerName", callerName)
            intent.putExtra("callType", callType)
            if (!callerAvatar.isNullOrEmpty()) {
                intent.putExtra("callerAvatar", callerAvatar)
            }
            
            try {
                // ⭐⭐⭐ КРИТИЧНО: Используем обычный startService, НЕ startForegroundService
                // CallLauncherService не является foreground service - он просто запускает Activity и останавливается
                // startForegroundService требует вызова startForeground() в течение 5 секунд, иначе будет исключение
                context.startService(intent)
                Log.d(TAG, "✅ startService вызван")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Ошибка запуска сервиса: ${e.message}")
                e.printStackTrace()
            }
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 CallLauncherService started")
        Log.d(TAG, "========================================")
        
        val callId = intent?.getStringExtra("callId")
        val callerName = intent?.getStringExtra("callerName") ?: "Unknown"
        val callType = intent?.getStringExtra("callType") ?: "audio"
        val callerAvatar = intent?.getStringExtra("callerAvatar")
        
        if (callId != null) {
            Log.d(TAG, "========================================")
            Log.d(TAG, "🚀 Запускаем CallActivity через CallLauncherService")
            Log.d(TAG, "Call ID: $callId")
            Log.d(TAG, "Caller: $callerName")
            Log.d(TAG, "Type: $callType")
            Log.d(TAG, "========================================")
            
            // Запускаем CallActivity
            val activityIntent = Intent(this, CallActivity::class.java).apply {
                putExtra("callId", callId)
                putExtra("callerName", callerName)
                putExtra("callType", callType)
                if (!callerAvatar.isNullOrEmpty()) {
                    putExtra("callerAvatar", callerAvatar)
                }
                // ⭐⭐⭐ КРИТИЧНО: Флаги для запуска Activity из Service
                // FLAG_ACTIVITY_NEW_TASK - создает новую задачу
                // FLAG_ACTIVITY_CLEAR_TOP - очищает стек до этой Activity
                // FLAG_ACTIVITY_SINGLE_TOP - не создает новый экземпляр если уже наверху
                // FLAG_ACTIVITY_BROUGHT_TO_FRONT - перемещает на передний план
                // FLAG_ACTIVITY_REORDER_TO_FRONT - перемещает на передний план если уже существует
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                }
            }
            
            try {
                Log.d(TAG, "📱 Вызываем startActivity()...")
                
                // ⭐⭐⭐ КРИТИЧНО: На Android 12+ (API 31+) есть ограничения на запуск Activity из фонового сервиса
                // Используем this.startActivity() вместо applicationContext.startActivity()
                // для использования контекста Service, который может иметь больше прав
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+: Используем ActivityManager для принудительного запуска
                    Log.d(TAG, "📱 Android 12+ - используем ActivityManager для принудительного запуска")
                    try {
                        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        // Пытаемся запустить через ActivityManager
                        startActivity(activityIntent)
                        Log.d(TAG, "✅✅✅ CallActivity ЗАПУЩЕНА через this.startActivity() (Android 12+)")
                    } catch (e: Exception) {
                        Log.w(TAG, "⚠️ this.startActivity() не удался, пробуем applicationContext.startActivity()")
                        applicationContext.startActivity(activityIntent)
                        Log.d(TAG, "✅✅✅ CallActivity ЗАПУЩЕНА через applicationContext.startActivity() (fallback)")
                    }
                } else {
                    // Android < 12: Используем обычный startActivity
                    startActivity(activityIntent)
                    Log.d(TAG, "✅✅✅ CallActivity ЗАПУЩЕНА через this.startActivity() (Android < 12)")
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "========================================")
                Log.e(TAG, "❌❌❌ SecurityException при запуске CallActivity!")
                Log.e(TAG, "Это может быть ограничение MIUI/Xiaomi или Android 12+ BAL")
                Log.e(TAG, "Error: ${e.message}")
                Log.e(TAG, "========================================")
                e.printStackTrace()
            } catch (e: Exception) {
                Log.e(TAG, "========================================")
                Log.e(TAG, "❌ Failed to launch CallActivity: ${e.message}")
                Log.e(TAG, "Stack trace:")
                e.printStackTrace()
                Log.e(TAG, "========================================")
            }
        } else {
            Log.e(TAG, "❌ callId is null!")
        }
        
        // Сразу останавливаем сервис
        stopSelf()
        
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}