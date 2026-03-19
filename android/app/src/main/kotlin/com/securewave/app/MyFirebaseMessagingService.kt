package com.securewave.app

import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
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
            "incoming_call", "call" -> {
                Log.d(TAG, "📞📞📞 ВХОДЯЩИЙ ЗВОНОК ОБНАРУЖЕН!")
                handleIncomingCall(data, remoteMessage)
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
                CallNotificationHelper.cancelNotification(this, callId)
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
     * ⭐⭐⭐ КЛЮЧЕВАЯ ФУНКЦИЯ: Обработка входящего звонка
     * Проверяет состояние приложения и выбирает стратегию
     */
    private fun handleIncomingCall(data: Map<String, String>, remoteMessage: RemoteMessage) {
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
        
        // ⭐⭐⭐ КРИТИЧНО: Проверяем состояние приложения
        val isAppInForeground = isAppInForeground()
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔍 App State Check:")
        Log.d(TAG, "Is app in FOREGROUND: $isAppInForeground")
        Log.d(TAG, "========================================")

        // ⭐⭐⭐ КРИТИЧНО: Проверяем, разблокирован ли экран
        val isScreenUnlocked = isScreenUnlocked()
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 Показываем входящий звонок")
        Log.d(TAG, "App State: ${if (isAppInForeground) "FOREGROUND" else "BACKGROUND/KILLED"}")
        Log.d(TAG, "Screen State: ${if (isScreenUnlocked) "UNLOCKED" else "LOCKED"}")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: На Android 12+ (API 31+) система блокирует запуск Activity из фонового сервиса (BAL)
        // Даже если startActivity() не выбрасывает исключение, Activity может быть заблокирована
        // Поэтому используем full-screen notification даже при разблокированном экране
        // Full-screen notification - это единственный надежный способ показать Activity из фонового сервиса
        
        if (isScreenUnlocked && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            // ⭐⭐⭐ ТОЛЬКО для Android < 12: Пытаемся запустить CallActivity напрямую
            // На Android 12+ это не работает из-за BAL ограничений
            Log.d(TAG, "========================================")
            Log.d(TAG, "📱📱📱 ЭКРАН РАЗБЛОКИРОВАН (Android < 12) - ЗАПУСКАЕМ CallActivity НАПРЯМУЮ")
            Log.d(TAG, "Call ID: $callId")
            Log.d(TAG, "Caller: $callerName")
            Log.d(TAG, "Type: $callType")
            Log.d(TAG, "========================================")
            
            try {
                val callerAvatar = data["callerAvatar"] ?: data["caller_avatar"]
                Log.d(TAG, "📦 Создаем Intent для CallActivity...")
                val callActivityIntent = Intent(this, CallActivity::class.java).apply {
                    putExtra("callId", callId)
                    putExtra("callerName", callerName)
                    putExtra("callType", callType)
                    if (!callerAvatar.isNullOrEmpty()) {
                        putExtra("callerAvatar", callerAvatar)
                        Log.d(TAG, "✅ Avatar добавлен: $callerAvatar")
                    }
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                    addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                    }
                }
                
                Log.d(TAG, "🚀 Запускаем CallActivity...")
                try {
                    val callerAvatarForService = data["callerAvatar"] ?: data["caller_avatar"]
                    CallLauncherService.launch(
                        applicationContext,
                        callId,
                        callerName,
                        callType,
                        callerAvatarForService
                    )
                    Log.d(TAG, "✅ CallLauncherService запущен")
                    Thread.sleep(200)
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Ошибка запуска через CallLauncherService: ${e.message}")
                    try {
                        applicationContext.startActivity(callActivityIntent)
                        Log.d(TAG, "✅ Прямой запуск успешен")
                    } catch (e2: Exception) {
                        Log.e(TAG, "❌ Прямой запуск тоже не удался: ${e2.message}")
                        // Fallback к full-screen notification
                        val callerAvatarFallback = data["callerAvatar"] ?: data["caller_avatar"]
                        CallNotificationHelper.showIncomingCallNotification(
                            this, callId, callerName, callType, callerAvatarFallback
                        )
                        return
                    }
                }
                Log.d(TAG, "✅✅✅ CallActivity ЗАПУЩЕНА НАПРЯМУЮ!")
                
                // Также показываем ConnectionService для системной интеграции
                try {
                    VoIPConnectionService.registerPhoneAccount(this)
                    VoIPConnectionService.showIncomingCall(
                        this,
                        callId,
                        callerName,
                        null,
                        callType == "video"
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "⚠️ Ошибка ConnectionService: ${e.message}")
                }
                
                Log.d(TAG, "✅✅✅ ВЫХОДИМ - CallActivity уже запущена")
                return
            } catch (e: Exception) {
                Log.e(TAG, "❌❌❌ ОШИБКА ЗАПУСКА CallActivity: ${e.message}")
                // Продолжаем с обычным flow (full-screen notification)
            }
        } else {
            // ⭐⭐⭐ Android 12+ или заблокированный экран: используем full-screen notification
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                Log.d(TAG, "========================================")
                Log.d(TAG, "📱 Android 12+ - используем full-screen notification (BAL ограничения)")
                Log.d(TAG, "Screen State: ${if (isScreenUnlocked) "UNLOCKED" else "LOCKED"}")
                Log.d(TAG, "========================================")
            } else {
                Log.d(TAG, "========================================")
                Log.d(TAG, "🔒 Экран ЗАБЛОКИРОВАН - используем full-screen intent")
                Log.d(TAG, "========================================")
            }
        }

        // ⭐⭐⭐ КРИТИЧНО: Регистрируем PhoneAccount перед показом звонка
        // Это необходимо, так как когда приложение убито, MainActivity не запущена
        // и PhoneAccount не зарегистрирован
        try {
            VoIPConnectionService.registerPhoneAccount(this)
            Log.d(TAG, "✅ PhoneAccount зарегистрирован (если еще не был)")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Ошибка регистрации PhoneAccount: ${e.message}")
            // Продолжаем попытку показать звонок
        }
        
        try {
            VoIPConnectionService.showIncomingCall(
                this,
                callId,
                callerName,
                null, // callerId
                callType == "video"
            )
            Log.d(TAG, "✅ ConnectionService показал входящий звонок!")
            
            // ⭐⭐⭐ КРИТИЧНО: Для self-managed звонков Android может не показать системный UI
            // Используем full-screen notification как fallback для гарантированного показа UI
            // Это работает даже когда приложение убито
            try {
                val callerAvatar = data["callerAvatar"] ?: data["caller_avatar"]
                CallNotificationHelper.showIncomingCallNotification(
                    this, callId, callerName, callType, callerAvatar
                )
                Log.d(TAG, "✅ Full-screen notification показан (fallback для self-managed)")
            } catch (e2: Exception) {
                Log.e(TAG, "❌ Ошибка fallback notification: ${e2.message}")
            }
            
            // Отменяем стандартное FCM уведомление, так как мы показали full-screen notification
            try {
                val notificationManager = getSystemService(NotificationManager::class.java)
                remoteMessage.messageId?.let { messageId ->
                    notificationManager.cancel(messageId.hashCode())
                    Log.d(TAG, "✅ Стандартное FCM уведомление отменено")
                }
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Не удалось отменить стандартное уведомление: ${e.message}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка ConnectionService, fallback к notification: ${e.message}")
            e.printStackTrace()
            
            // Fallback к старому способу
            try {
                val callerAvatar = data["callerAvatar"] ?: data["caller_avatar"]
                CallNotificationHelper.showIncomingCallNotification(
                    this, callId, callerName, callType, callerAvatar
                )
                Log.d(TAG, "✅ Fallback: Full-screen notification shown!")
            } catch (e2: Exception) {
                Log.e(TAG, "❌ Ошибка fallback notification: ${e2.message}")
            }
        }
    }

    /**
     * ⭐⭐⭐ НОВОЕ: Проверяет, разблокирован ли экран
     * Использует комбинацию KeyguardManager и PowerManager для более точного определения
     */
    private fun isScreenUnlocked(): Boolean {
        try {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            
            // ⭐⭐⭐ КРИТИЧНО: Проверяем, включен ли экран (интерактивен)
            val isScreenOn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                powerManager.isInteractive
            } else {
                @Suppress("DEPRECATION")
                powerManager.isScreenOn
            }
            
            Log.d(TAG, "🔋 Экран включен (интерактивен): $isScreenOn")
            
            // Если экран выключен, считаем что он заблокирован
            if (!isScreenOn) {
                Log.d(TAG, "🔓 Экран выключен - считаем заблокированным")
                return false
            }
            
            // ⭐⭐⭐ КРИТИЧНО: Проверяем Keyguard
            val isKeyguardLocked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                keyguardManager.isDeviceLocked
            } else {
                @Suppress("DEPRECATION")
                keyguardManager.isKeyguardLocked
            }
            
            Log.d(TAG, "🔓 Keyguard заблокирован: $isKeyguardLocked")
            
            // ⭐⭐⭐ КРИТИЧНО: Если экран включен И keyguard не заблокирован - экран разблокирован
            val isUnlocked = !isKeyguardLocked && isScreenOn
            
            Log.d(TAG, "🔓 ИТОГ: Экран разблокирован: $isUnlocked")
            return isUnlocked
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Ошибка проверки блокировки экрана: ${e.message}")
            e.printStackTrace()
            // ⭐⭐⭐ КРИТИЧНО: Если не можем определить, предполагаем что экран разблокирован
            // Это безопаснее, так как лучше показать CallActivity даже если экран заблокирован,
            // чем не показать когда экран разблокирован
            Log.d(TAG, "⚠️ Предполагаем что экран разблокирован (fallback)")
            return true
        }
    }
    
    /**
     * ⭐⭐⭐ КРИТИЧНО: Проверяет, находится ли приложение в foreground
     */
    private fun isAppInForeground(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runningProcesses = activityManager.runningAppProcesses ?: run {
            Log.d(TAG, "❌ runningAppProcesses is NULL - app is killed")
            return false
        }

        for (processInfo in runningProcesses) {
            if (processInfo.processName == applicationContext.packageName) {
                val importance = processInfo.importance
                
                Log.d(TAG, "🔍 Process found: ${processInfo.processName}")
                Log.d(TAG, "🔍 Importance: $importance")
                Log.d(TAG, "🔍 IMPORTANCE_FOREGROUND = ${ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND}")
                
                // Приложение в foreground если importance == FOREGROUND
                val isForeground = importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
                
                Log.d(TAG, "🔍 Result: isForeground = $isForeground")
                return isForeground
            }
        }

        Log.d(TAG, "❌ Process not found - app is killed")
        return false
    }

    /**
     * Показывает уведомление о новом сообщении
     */
    private fun showMessageNotification(chatId: String, senderName: String, messageText: String) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📱 Создание уведомления о сообщении...")
        Log.d(TAG, "========================================")
        
        val notificationManager = getSystemService(NotificationManager::class.java)
        
        val notification = androidx.core.app.NotificationCompat.Builder(this, CHANNEL_ID_MESSAGES)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(senderName)
            .setContentText(messageText)
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
            .setCategory(androidx.core.app.NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()

        notificationManager.notify(chatId.hashCode(), notification)
        
        Log.d(TAG, "✅ Уведомление показано успешно!")
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
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
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