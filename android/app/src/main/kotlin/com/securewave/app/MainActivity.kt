package com.securewave.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.securewave.app/notification"
    private val CALL_CHANNEL = "com.securewave.app/call"
    private val AUDIO_CHANNEL = "com.securewave.app/audio"
    
    private var notificationChannel: MethodChannel? = null
    private var callChannel: MethodChannel? = null
    private var audioChannel: MethodChannel? = null

    private var audioManagerHelper: AudioManagerHelper? = null

    // ⭐ Отслеживаем обработанные Intent чтобы не обрабатывать их повторно
    private var lastProcessedIntentData: String? = null

    companion object {
        private const val TAG = "MainActivity"
        private const val OVERLAY_PERMISSION_REQUEST_CODE = 1234
        private const val CHANNEL_ID_CALLS = "calls_channel"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚀 configureFlutterEngine вызван")
        Log.d(TAG, "========================================")
        
        createNotificationChannels()
        audioManagerHelper = AudioManagerHelper(this)
        
        // ⭐⭐⭐ КРИТИЧНО: Регистрируем ConnectionService (аналог CallKit)
        VoIPConnectionService.registerPhoneAccount(this)
        
        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL
        )
        
        callChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_CHANNEL
        )
        
        audioChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL
        )
        
        // ⭐⭐⭐ КРИТИЧНО: Устанавливаем method channel для ConnectionService
        VoIPConnectionService.flutterChannel = callChannel
        
        setupAudioChannel()
        setupCallChannel()
        
        Log.d(TAG, "✅ Channels созданы")
    }
    
    private fun setupAudioChannel() {
        audioChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "setAudioModeForVoiceCall" -> {
                    Log.d(TAG, "📞 setAudioModeForVoiceCall вызван")
                    audioManagerHelper?.setAudioModeForVoiceCall()
                    result.success(true)
                }
                
                "setAudioModeForVideoCall" -> {
                    Log.d(TAG, "📹 setAudioModeForVideoCall вызван")
                    audioManagerHelper?.setAudioModeForVideoCall()
                    result.success(true)
                }
                
                "toggleSpeaker" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    Log.d(TAG, "🔊 toggleSpeaker: $enable")
                    audioManagerHelper?.toggleSpeaker(enable)
                    result.success(true)
                }
                
                "isSpeakerphoneOn" -> {
                    val isOn = audioManagerHelper?.isSpeakerphoneOn() ?: false
                    Log.d(TAG, "🔊 isSpeakerphoneOn: $isOn")
                    result.success(isOn)
                }
                
                "restoreAudioSettings" -> {
                    Log.d(TAG, "🔄 restoreAudioSettings вызван")
                    audioManagerHelper?.restoreAudioSettings()
                    result.success(true)
                }
                
                "logAudioState" -> {
                    audioManagerHelper?.logAudioState()
                    result.success(true)
                }
                
                else -> result.notImplemented()
            }
        }
        
        Log.d(TAG, "✅ Audio Channel настроен")
    }
    
    private fun setupCallChannel() {
        callChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showIncomingCall" -> {
                    try {
                        val callId = call.argument<String>("callId") ?: "unknown"
                        val callerName = call.argument<String>("callerName") ?: "Unknown"
                        val callType = call.argument<String>("callType") ?: "audio"
                        val hasVideo = callType == "video"

                        Log.d(TAG, "========================================")
                        Log.d(TAG, "📞 showIncomingCall вызван из Flutter")
                        Log.d(TAG, "Call ID: $callId")
                        Log.d(TAG, "Caller: $callerName")
                        Log.d(TAG, "Type: $callType")
                        Log.d(TAG, "========================================")

                        // ⭐⭐⭐ КРИТИЧНО: Используем ConnectionService (аналог CallKit)
                        VoIPConnectionService.showIncomingCall(
                            this,
                            callId,
                            callerName,
                            null, // callerId
                            hasVideo
                        )

                        Log.d(TAG, "✅ ConnectionService показал входящий звонок")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Ошибка showIncomingCall: ${e.message}")
                        e.printStackTrace()
                        result.error("ERROR", e.message, null)
                    }
                }
                
                "showCallScreen" -> {
                    try {
                        val callId = call.argument<String>("callId") ?: "unknown"
                        val callerName = call.argument<String>("callerName") ?: "Unknown"
                        val callType = call.argument<String>("callType") ?: "audio"

                        Log.d(TAG, "🚀 Показываем full-screen notification")
                        val callerAvatar = call.argument<String>("callerAvatar")
                        CallNotificationHelper.showIncomingCallNotification(
                            this, callId, callerName, callType, callerAvatar
                        )

                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Ошибка: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                }

                "cancelNotification" -> {
                    try {
                        val callId = call.argument<String>("callId") ?: "unknown"

                        Log.d(TAG, "🚫 Отменяем уведомление для callId: $callId")
                        CallNotificationHelper.cancelNotification(this, callId)

                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Ошибка отмены уведомления: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                }
                
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivityForResult(intent, OVERLAY_PERMISSION_REQUEST_CODE)
                        }
                    }
                    result.success(true)
                }
                
                "checkLockscreenPermission" -> {
                    try {
                        Log.d(TAG, "🔓 Открываем настройки MIUI для lockscreen permission")
                        val intent = Intent("miui.intent.action.APP_PERM_EDITOR")
                        intent.setClassName("com.miui.securitycenter", 
                            "com.miui.permcenter.permissions.PermissionsEditorActivity")
                        intent.putExtra("extra_pkgname", packageName)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.w(TAG, "⚠️ Не MIUI или ошибка: ${e.message}")
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", "Cannot open settings", null)
                        }
                    }
                }

                "cancelCallNotification" -> {
                    try {
                        val callId = call.argument<String>("callId") ?: run {
                            result.error("MISSING_PARAM", "callId is required", null)
                            return@setMethodCallHandler
                        }

                        Log.d(TAG, "🚫 Отменяем уведомление: $callId")
                        CallNotificationHelper.cancelNotification(this, callId)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Ошибка отмены уведомления: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        Log.d(TAG, "✅ Call Channel настроен")
    }
    
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val callsChannel = NotificationChannel(
                CHANNEL_ID_CALLS,
                "Входящие звонки",
                NotificationManager.IMPORTANCE_HIGH
            )
            callsChannel.description = "Полноэкранные уведомления о входящих звонках"
            callsChannel.enableVibration(true)
            callsChannel.vibrationPattern = longArrayOf(0, 1000, 500, 1000)
            callsChannel.lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(callsChannel)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // ⭐ НЕ вызываем handleIntent() в onResume!
        // Intent уже обрабатывается в onCreate() и onNewIntent()
        // Повторная обработка в onResume() вызывает множественные срабатывания

        // Регистрируем MainActivity в CallActionReceiver
        CallActionReceiver.mainActivity = this
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        // ⭐ Создаем уникальный идентификатор Intent для предотвращения повторной обработки
        val intentIdentifier = "${intent.action}_${intent.data}_${intent.getStringExtra("callId")}_${intent.getStringExtra("action")}"

        Log.d(TAG, "========================================")
        Log.d(TAG, "📦 handleIntent вызван")
        Log.d(TAG, "Intent ID: $intentIdentifier")
        Log.d(TAG, "Last processed: $lastProcessedIntentData")

        // ⭐ Проверяем не обрабатывали ли мы уже этот Intent
        if (intentIdentifier == lastProcessedIntentData) {
            Log.d(TAG, "⚠️ Intent уже был обработан, пропускаем")
            Log.d(TAG, "========================================")
            return
        }

        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "Data: ${intent.data}")

        val type = intent.getStringExtra("type")
        Log.d(TAG, "Type (from extras): $type")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ НОВАЯ ЛОГИКА: Проверяем ACTION и DATA
        if (intent.action == Intent.ACTION_VIEW && intent.data != null) {
            val uri = intent.data
            Log.d(TAG, "📍 Обработка URI: $uri")
            
            // Парсим URI: securewave://call/{callId}/{action}
            if (uri?.scheme == "securewave" && uri.host == "call") {
                val pathSegments = uri.pathSegments
                if (pathSegments.size >= 2) {
                    val callId = pathSegments[0]
                    val action = pathSegments[1]
                    
                    Log.d(TAG, "========================================")
                    Log.d(TAG, "📞 ЗВОНОК из URI обнаружен!")
                    Log.d(TAG, "  - callId: $callId")
                    Log.d(TAG, "  - action: $action")
                    
                    val callerName = intent.getStringExtra("callerName")
                    val callType = intent.getStringExtra("callType")
                    
                    // ⭐⭐⭐ ИСПРАВЛЕНО: Обрабатываем оба действия правильно
                    val autoAccept = when (action) {
                        "accept" -> true
                        "decline" -> false
                        else -> null
                    }
                    
                    Log.d(TAG, "  - callerName: $callerName")
                    Log.d(TAG, "  - callType: $callType")
                    Log.d(TAG, "  - action: $action")
                    Log.d(TAG, "  - autoAccept: $autoAccept")
                    Log.d(TAG, "========================================")
                    
                    // ⭐⭐⭐ КРИТИЧНО: Всегда передаём action во Flutter
                    val data = mutableMapOf<String, Any?>(
                        "type" to "incoming_call",
                        "callId" to callId,
                        "callerName" to callerName,
                        "callType" to callType,
                        "action" to action // ⭐ ОБЯЗАТЕЛЬНО передаём action!
                    )
                    
                    // Добавляем флаги для разных действий
                    when (action) {
                        "accept" -> {
                            data["autoAccept"] = true
                            data["shouldDecline"] = false
                        }
                        "decline" -> {
                            data["autoAccept"] = false
                            data["shouldDecline"] = true
                        }
                        else -> {
                            data["autoAccept"] = null
                            data["shouldDecline"] = false
                        }
                    }
                    
                    Log.d(TAG, "📋 Final data map:")
                    data.forEach { (key, value) ->
                        Log.d(TAG, "    $key: $value")
                    }
                    
                    Log.d(TAG, "📤 Отправляем данные во Flutter (из URI)")
                    Log.d(TAG, "Data to send: $data")
                    sendToFlutter(data)

                    // ⭐ Сохраняем идентификатор обработанного Intent
                    lastProcessedIntentData = intentIdentifier
                    Log.d(TAG, "✅ Intent обработан и сохранен: $intentIdentifier")

                    // Очищаем Intent после обработки
                    intent.action = null
                    intent.data = null

                    return
                }
            }
        }
        
        // ⭐ СТАРАЯ ЛОГИКА: Для обратной совместимости
        if (type == null) {
            Log.d(TAG, "⚠️ Type is null и URI нет - игнорируем")
            return
        }
        
        when (type) {
            "incoming_call" -> {
                val callId = intent.getStringExtra("callId")
                val callerName = intent.getStringExtra("callerName")
                val callType = intent.getStringExtra("callType")
                val action = intent.getStringExtra("action")
                
                // ⭐⭐⭐ ИСПРАВЛЕНО: Обрабатываем оба действия правильно
                val autoAccept = when (action) {
                    "accept" -> true
                    "decline" -> false
                    else -> null
                }
                
                Log.d(TAG, "📞 INCOMING_CALL обнаружен (старая логика)!")
                Log.d(TAG, "  - callId: $callId")
                Log.d(TAG, "  - callerName: $callerName")
                Log.d(TAG, "  - callType: $callType")
                Log.d(TAG, "  - action: $action")
                Log.d(TAG, "  - autoAccept: $autoAccept")
                
                // ⭐⭐⭐ КРИТИЧНО: Всегда передаём action во Flutter
                val data = mutableMapOf<String, Any?>(
                    "type" to "incoming_call",
                    "callId" to callId,
                    "callerName" to callerName,
                    "callType" to callType,
                    "action" to action // ⭐ ОБЯЗАТЕЛЬНО передаём action!
                )
                
                // Добавляем флаги для разных действий
                when (action) {
                    "accept" -> {
                        data["autoAccept"] = true
                        data["shouldDecline"] = false
                    }
                    "decline" -> {
                        data["autoAccept"] = false
                        data["shouldDecline"] = true
                    }
                    else -> {
                        data["autoAccept"] = null
                        data["shouldDecline"] = false
                    }
                }
                
                Log.d(TAG, "📋 Final data map:")
                data.forEach { (key, value) ->
                    Log.d(TAG, "    $key: $value")
                }
                
                Log.d(TAG, "📤 Отправляем данные во Flutter...")
                Log.d(TAG, "Data to send: $data")
                sendToFlutter(data)
            }
        }
        
        // Очищаем extras
        intent.removeExtra("type")
        intent.removeExtra("callId")
        intent.removeExtra("callerName")
        intent.removeExtra("callType")
        intent.removeExtra("action")
        
        Log.d(TAG, "========================================")
    }
    
    private fun sendToFlutter(data: Map<String, Any?>) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📤 sendToFlutter вызван")
        Log.d(TAG, "notificationChannel != null: ${notificationChannel != null}")
        Log.d(TAG, "Data: $data")
        Log.d(TAG, "========================================")
        
        if (notificationChannel == null) {
            Log.e(TAG, "❌ notificationChannel is NULL!")
            android.os.Handler(mainLooper).postDelayed({
                if (notificationChannel != null) {
                    Log.d(TAG, "🔄 Повторная попытка отправки...")
                    try {
                        notificationChannel?.invokeMethod("onNotificationTap", data)
                        Log.d(TAG, "✅ Данные отправлены во Flutter (повторная попытка)")
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Ошибка отправки (повторная попытка): ${e.message}")
                    }
                } else {
                    Log.e(TAG, "❌ notificationChannel все еще NULL!")
                }
            }, 500)
            return
        }
        
        try {
            notificationChannel?.invokeMethod("onNotificationTap", data)
            Log.d(TAG, "✅ Данные успешно отправлены во Flutter")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка отправки: ${e.message}")
            e.printStackTrace()
        }
        
        Log.d(TAG, "========================================")
    }
    
    override fun onPause() {
        super.onPause()
        // Очищаем reference когда activity не активна
        CallActionReceiver.mainActivity = null
    }

    /**
     * Публичный метод для отклонения звонка из notification
     * Вызывается из CallActionReceiver
     */
    fun declineCallFromNotification(callId: String) {
        Log.d(TAG, "🚫 declineCallFromNotification: $callId")

        notificationChannel?.invokeMethod("declineCall", mapOf("callId" to callId))
    }

    override fun onDestroy() {
        super.onDestroy()
        audioManagerHelper = null
        CallActionReceiver.mainActivity = null
    }
}