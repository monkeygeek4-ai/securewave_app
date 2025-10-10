package com.securewave.app

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.securewave.app/notification"
    private var methodChannel: MethodChannel? = null
    
    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚀 configureFlutterEngine вызван")
        Log.d(TAG, "========================================")
        
        // Создаем MethodChannel для общения с Flutter
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        
        Log.d(TAG, "✅ MethodChannel создан: $CHANNEL")
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
     * Отправка данных во Flutter через MethodChannel
     */
    private fun sendToFlutter(data: Map<String, Any?>) {
        if (methodChannel == null) {
            Log.w(TAG, "⚠️ MethodChannel is null, сохраняем данные для последующей отправки")
            // Можно сохранить данные и отправить позже, когда channel будет готов
            return
        }
        
        Log.d(TAG, "📤 Отправка данных во Flutter через MethodChannel")
        Log.d(TAG, "Data: $data")
        
        try {
            methodChannel?.invokeMethod("onNotificationTap", data)
            Log.d(TAG, "✅ Данные успешно отправлены во Flutter")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка отправки данных во Flutter: ${e.message}")
            e.printStackTrace()
        }
    }
}