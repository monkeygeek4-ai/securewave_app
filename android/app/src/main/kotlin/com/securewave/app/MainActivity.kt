package com.securewave.app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    // ⭐ ДВА КАНАЛА: один для уведомлений, другой для звонков
    private val NOTIFICATION_CHANNEL = "com.securewave.app/notification"
    private val CALL_CHANNEL = "com.securewave.app/call"
    
    private var notificationChannel: MethodChannel? = null
    private var callChannel: MethodChannel? = null
    
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚀 configureFlutterEngine вызван")
        Log.d(TAG, "========================================")
        
        // ============================================
        // 1️⃣ КАНАЛ ДЛЯ УВЕДОМЛЕНИЙ (существующий)
        // ============================================
        notificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL
        )
        Log.d(TAG, "✅ Notification MethodChannel создан: $NOTIFICATION_CHANNEL")
        
        // ============================================
        // 2️⃣ КАНАЛ ДЛЯ ЗВОНКОВ (новый)
        // ============================================
        callChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_CHANNEL
        )
        
        callChannel?.setMethodCallHandler { call, result ->
            Log.d(TAG, "========================================")
            Log.d(TAG, "📞 Получен вызов метода: ${call.method}")
            Log.d(TAG, "Аргументы: ${call.arguments}")
            Log.d(TAG, "========================================")
            
            when (call.method) {
                "showCallScreen" -> {
                    try {
                        val callId = call.argument<String>("callId")
                        val callerName = call.argument<String>("callerName")
                        val callType = call.argument<String>("callType")
                        
                        Log.d(TAG, "Параметры звонка:")
                        Log.d(TAG, "  - callId: $callId")
                        Log.d(TAG, "  - callerName: $callerName")
                        Log.d(TAG, "  - callType: $callType")
                        
                        if (callId == null || callerName == null) {
                            Log.e(TAG, "❌ Отсутствуют обязательные параметры")
                            result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                            return@setMethodCallHandler
                        }
                        
                        Log.d(TAG, "🚀 Запуск CallActivity...")
                        
                        val intent = Intent(this, CallActivity::class.java).apply {
                            putExtra("callId", callId)
                            putExtra("callerName", callerName)
                            putExtra("callType", callType ?: "audio")
                            
                            // Флаги для запуска поверх всего (даже lockscreen)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        
                        startActivity(intent)
                        
                        Log.d(TAG, "✅ CallActivity запущена успешно")
                        result.success(true)
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Ошибка запуска CallActivity: ${e.message}")
                        Log.e(TAG, "Stack trace:", e)
                        result.error("START_ACTIVITY_ERROR", e.message, null)
                    }
                }
                else -> {
                    Log.w(TAG, "⚠️ Неизвестный метод: ${call.method}")
                    result.notImplemented()
                }
            }
            
            Log.d(TAG, "========================================")
        }
        
        Log.d(TAG, "✅ Call MethodChannel создан: $CALL_CHANNEL")
        Log.d(TAG, "========================================")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚀 MainActivity onCreate")
        Log.d(TAG, "========================================")
        
        // Обрабатываем Intent при запуске
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d(TAG, "========================================")
        Log.d(TAG, "📬 onNewIntent вызван")
        Log.d(TAG, "========================================")
        
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "========================================")
        Log.d(TAG, "▶️ onResume вызван")
        Log.d(TAG, "========================================")
        
        // Повторно обрабатываем Intent при возврате в приложение
        handleIntent(intent)
    }

    /**
     * Обработка Intent из уведомлений
     */
    private fun handleIntent(intent: Intent?) {
        if (intent == null) {
            Log.d(TAG, "⚠️ Intent is null")
            return
        }
        
        val type = intent.getStringExtra("type")
        Log.d(TAG, "========================================")
        Log.d(TAG, "📦 Обработка Intent")
        Log.d(TAG, "========================================")
        Log.d(TAG, "Type: $type")
        
        if (type == null) {
            Log.d(TAG, "ℹ️ Type is null - это обычный запуск приложения")
            return
        }
        
        when (type) {
            "new_message" -> {
                val chatId = intent.getStringExtra("chatId")
                Log.d(TAG, "========================================")
                Log.d(TAG, "💬 Новое сообщение")
                Log.d(TAG, "ChatId: $chatId")
                Log.d(TAG, "========================================")
                
                // Отправляем событие во Flutter
                sendToFlutter(mapOf(
                    "type" to "new_message",
                    "chatId" to chatId
                ))
            }
            
            "incoming_call" -> {
                val callId = intent.getStringExtra("callId")
                val callerName = intent.getStringExtra("callerName")
                val callType = intent.getStringExtra("callType")
                val action = intent.getStringExtra("action")
                
                Log.d(TAG, "========================================")
                Log.d(TAG, "📞📞📞 ВХОДЯЩИЙ ЗВОНОК!")
                Log.d(TAG, "========================================")
                Log.d(TAG, "CallId: $callId")
                Log.d(TAG, "CallerName: $callerName")
                Log.d(TAG, "CallType: $callType")
                Log.d(TAG, "Action: $action")
                Log.d(TAG, "========================================")
                
                // Отправляем событие во Flutter
                sendToFlutter(mapOf(
                    "type" to "incoming_call",
                    "callId" to callId,
                    "callerName" to callerName,
                    "callType" to callType,
                    "action" to action
                ))
            }
        }
        
        // Очищаем extras чтобы не обрабатывать повторно
        intent.removeExtra("type")
        intent.removeExtra("chatId")
        intent.removeExtra("callId")
        intent.removeExtra("callerName")
        intent.removeExtra("callType")
        intent.removeExtra("action")
    }
    
    /**
     * Отправка данных во Flutter через MethodChannel (для уведомлений)
     */
    private fun sendToFlutter(data: Map<String, Any?>) {
        if (notificationChannel == null) {
            Log.w(TAG, "⚠️ Notification MethodChannel is null, сохраняем данные для последующей отправки")
            return
        }
        
        Log.d(TAG, "📤 Отправка данных во Flutter через Notification MethodChannel")
        Log.d(TAG, "Data: $data")
        
        try {
            notificationChannel?.invokeMethod("onNotificationTap", data)
            Log.d(TAG, "✅ Данные успешно отправлены во Flutter")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка отправки данных во Flutter: ${e.message}")
            e.printStackTrace()
        }
    }
}