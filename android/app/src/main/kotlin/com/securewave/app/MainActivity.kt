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
    
    private var notificationChannel: MethodChannel? = null
    private var callChannel: MethodChannel? = null
    
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
        
        // Создаем notification channel
        createNotificationChannels()
        
        // Notification Channel
        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL
        )
        
        // Call Channel
        callChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_CHANNEL
        )
        
        callChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showCallScreen" -> {
                    try {
                        val callId = call.argument<String>("callId") ?: "unknown"
                        val callerName = call.argument<String>("callerName") ?: "Unknown"
                        val callType = call.argument<String>("callType") ?: "audio"
                        
                        Log.d(TAG, "🚀 Запуск CallService")
                        
                        // ⭐⭐⭐ ИСПОЛЬЗУЕМ FOREGROUND SERVICE
                        CallService.startService(this, callId, callerName, callType)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Ошибка: ${e.message}")
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
                    // ⭐ Для MIUI: Открываем настройки разрешений приложения
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
                        // Fallback: открываем обычные настройки приложения
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
                
                else -> result.notImplemented()
            }
        }
        
        Log.d(TAG, "✅ Channels созданы")
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
        handleIntent(intent)
    }

    /**
     * ⭐⭐⭐ ИСПРАВЛЕНО: Обработка Intent с поддержкой URI
     */
    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "📦 handleIntent вызван")
        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "Data: ${intent.data}")
        
        // Получаем type из extras
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
                    
                    // Получаем остальные данные из extras
                    val callerName = intent.getStringExtra("callerName")
                    val callType = intent.getStringExtra("callType")
                    
                    Log.d(TAG, "  - callerName: $callerName")
                    Log.d(TAG, "  - callType: $callType")
                    Log.d(TAG, "========================================")
                    
                    val data = mapOf(
                        "type" to "incoming_call",
                        "callId" to callId,
                        "callerName" to callerName,
                        "callType" to callType,
                        "action" to action
                    )
                    
                    Log.d(TAG, "📤 Отправляем данные во Flutter (из URI)")
                    sendToFlutter(data)
                    
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
                
                Log.d(TAG, "📞 INCOMING_CALL обнаружен (старая логика)!")
                Log.d(TAG, "  - callId: $callId")
                Log.d(TAG, "  - callerName: $callerName")
                Log.d(TAG, "  - callType: $callType")
                Log.d(TAG, "  - action: $action")
                
                val data = mapOf(
                    "type" to "incoming_call",
                    "callId" to callId,
                    "callerName" to callerName,
                    "callType" to callType,
                    "action" to action
                )
                
                Log.d(TAG, "📤 Отправляем данные во Flutter...")
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
            // Повторная попытка через небольшую задержку
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
}