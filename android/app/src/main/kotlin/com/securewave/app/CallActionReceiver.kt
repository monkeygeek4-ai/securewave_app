package com.securewave.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.net.HttpURLConnection
import java.net.URL

/**
 * ⭐⭐⭐ BroadcastReceiver для обработки действий из уведомлений о звонках
 * Обрабатывает: DECLINE_CALL, ANSWER_CALL
 */
class CallActionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "CallActionReceiver"
        const val ACTION_DECLINE_CALL = "com.securewave.app.DECLINE_CALL"
        const val ACTION_ANSWER_CALL = "com.securewave.app.ANSWER_CALL"

        // Храним reference на MainActivity для вызова Flutter методов
        var mainActivity: MainActivity? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 CallActionReceiver.onReceive()")
        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "========================================")

        val callId = intent.getStringExtra("callId")

        if (callId == null) {
            Log.e(TAG, "❌ callId is NULL!")
            return
        }

        Log.d(TAG, "callId: $callId")

        when (intent.action) {
            ACTION_DECLINE_CALL -> {
                Log.d(TAG, "🚫 DECLINE_CALL action")
                handleDeclineCall(context, callId)
            }
            ACTION_ANSWER_CALL -> {
                Log.d(TAG, "✅ ANSWER_CALL action")
                handleAnswerCall(context, callId)
            }
            else -> {
                Log.w(TAG, "⚠️ Unknown action: ${intent.action}")
            }
        }
    }

    private fun handleDeclineCall(context: Context, callId: String) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚫 Отклоняем звонок: $callId")
        Log.d(TAG, "========================================")

        // Отменяем уведомление
        CallNotificationHelper.cancelNotification(context, callId)

        // ⭐⭐⭐ КРИТИЧНО: ВСЕГДА отправляем decline через HTTP
        // Причина: Это гарантирует что backend получит decline независимо от состояния app
        Log.d(TAG, "📤 Отправляем decline через HTTP на backend...")
        sendDeclineToBackend(context, callId)

        // ТАКЖЕ вызываем Flutter метод если MainActivity активна (для UI update)
        mainActivity?.let { activity ->
            try {
                Log.d(TAG, "📱 MainActivity активна - также вызываем Flutter метод")
                activity.declineCallFromNotification(callId)
                Log.d(TAG, "✅ Flutter метод вызван")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Ошибка вызова Flutter: ${e.message}")
                e.printStackTrace()
            }
        }

        Log.d(TAG, "========================================")
    }

    /**
     * Отправляет decline на backend через HTTP когда Flutter не доступен
     */
    private fun sendDeclineToBackend(context: Context, callId: String) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                Log.d(TAG, "📤 Отправка HTTP decline на backend...")

                // Получаем сохраненный auth token из SharedPreferences
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val token = prefs.getString("flutter.auth_token", null)

                if (token == null) {
                    Log.e(TAG, "❌ Auth token не найден в SharedPreferences!")
                    return@launch
                }

                val url = URL("https://securewave.sbk-19.ru/backend/api/calls/$callId/decline")
                val connection = url.openConnection() as HttpURLConnection

                connection.apply {
                    requestMethod = "POST"
                    setRequestProperty("Authorization", "Bearer $token")
                    setRequestProperty("Content-Type", "application/json")
                    connectTimeout = 5000
                    readTimeout = 5000
                }

                val responseCode = connection.responseCode
                Log.d(TAG, "📥 HTTP Response: $responseCode")

                if (responseCode == 200 || responseCode == 201) {
                    Log.d(TAG, "✅ Decline успешно отправлен на backend!")
                } else {
                    Log.w(TAG, "⚠️ Backend вернул код: $responseCode")
                }

                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "❌ Ошибка отправки decline: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    private fun handleAnswerCall(context: Context, callId: String) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "✅ Принимаем звонок: $callId")
        Log.d(TAG, "========================================")

        // Открываем CallActivity
        val activityIntent = Intent(context, CallActivity::class.java).apply {
            putExtra("callId", callId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        try {
            context.startActivity(activityIntent)
            Log.d(TAG, "✅ CallActivity запущен")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка запуска CallActivity: ${e.message}")
            e.printStackTrace()
        }

        Log.d(TAG, "========================================")
    }
}
