package com.securewave.app

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telecom.VideoProfile
import android.util.Log
import io.flutter.plugin.common.MethodChannel

/**
 * ⭐⭐⭐ ConnectionService для интеграции VoIP звонков с системным телефоном Android
 * Аналог CallKit на iOS
 * 
 * Преимущества:
 * - Интеграция с системным телефонным приложением
 * - Отображение в истории звонков
 * - Работа с заблокированным экраном
 * - Поддержка Bluetooth гарнитур
 * - Лучшая работа в режиме энергосбережения
 */
class VoIPConnectionService : ConnectionService() {
    
    companion object {
        private const val TAG = "VoIPConnectionService"
        
        // PhoneAccount ID
        const val PHONE_ACCOUNT_ID = "securewave_voip"
        
        // Храним активные соединения
        private val activeConnections = mutableMapOf<String, VoIPConnection>()
        
        // Method channel для связи с Flutter
        var flutterChannel: MethodChannel? = null
        
        /**
         * Регистрация PhoneAccount в TelecomManager
         */
        fun registerPhoneAccount(context: Context) {
            try {
                Log.d(TAG, "========================================")
                Log.d(TAG, "📞 Регистрация PhoneAccount")
                Log.d(TAG, "========================================")
                
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                val componentName = ComponentName(context, VoIPConnectionService::class.java)
                val phoneAccountHandle = PhoneAccountHandle(componentName, PHONE_ACCOUNT_ID)
                
                // ⭐⭐⭐ КРИТИЧНО: Просто регистрируем PhoneAccount без проверки существования
                // Проверка требует разрешения READ_PHONE_NUMBERS, которое может отсутствовать
                // Если PhoneAccount уже зарегистрирован, registerPhoneAccount просто обновит его
                try {
                    // ⭐⭐⭐ КРИТИЧНО: Для self-managed PhoneAccount НЕ используем CAPABILITY_CALL_PROVIDER
                    // Self-managed ConnectionServices не могут быть call capable одновременно
                    val phoneAccount = PhoneAccount.builder(phoneAccountHandle, "SecureWave")
                        .setCapabilities(
                            PhoneAccount.CAPABILITY_SELF_MANAGED or
                            PhoneAccount.CAPABILITY_VIDEO_CALLING or
                            PhoneAccount.CAPABILITY_SUPPORTS_VIDEO_CALLING
                        )
                        .setShortDescription("SecureWave VoIP")
                        .setSupportedUriSchemes(listOf(PhoneAccount.SCHEME_SIP, PhoneAccount.SCHEME_TEL))
                        .build()
                    
                    telecomManager.registerPhoneAccount(phoneAccount)
                    Log.d(TAG, "✅ PhoneAccount зарегистрирован/обновлен")
                } catch (e: Exception) {
                    // Если PhoneAccount уже зарегистрирован, это нормально
                    Log.d(TAG, "ℹ️ PhoneAccount уже зарегистрирован или ошибка регистрации: ${e.message}")
                }
                
                // ⭐⭐⭐ ПРИМЕЧАНИЕ: Для self-managed PhoneAccount (CAPABILITY_SELF_MANAGED)
                // не требуется явное включение - он активен автоматически после регистрации
                
                Log.d(TAG, "✅ PhoneAccount готов к использованию")
                Log.d(TAG, "========================================")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Ошибка регистрации PhoneAccount: ${e.message}")
                e.printStackTrace()
            }
        }
        
        /**
         * Показать входящий звонок через ConnectionService
         */
        fun showIncomingCall(
            context: Context,
            callId: String,
            callerName: String,
            callerId: String?,
            hasVideo: Boolean
        ) {
            try {
                Log.d(TAG, "========================================")
                Log.d(TAG, "📞 Показываем входящий звонок через ConnectionService")
                Log.d(TAG, "Call ID: $callId")
                Log.d(TAG, "Caller: $callerName")
                Log.d(TAG, "Has Video: $hasVideo")
                Log.d(TAG, "========================================")
                
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
                val componentName = ComponentName(context, VoIPConnectionService::class.java)
                val phoneAccountHandle = PhoneAccountHandle(componentName, PHONE_ACCOUNT_ID)
                
                // Создаем URI для звонка
                val callUri = Uri.fromParts(
                    PhoneAccount.SCHEME_SIP,
                    callerId ?: callerName,
                    null
                )
                
                val extras = android.os.Bundle().apply {
                    putString(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS, callUri.toString())
                    putString("callId", callId)
                    putString("callerName", callerName)
                    putBoolean(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, hasVideo)
                }
                
                // Показываем входящий звонок
                telecomManager.addNewIncomingCall(phoneAccountHandle, extras)
                
                Log.d(TAG, "✅ Входящий звонок добавлен в TelecomManager")
                Log.d(TAG, "========================================")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Ошибка показа входящего звонка: ${e.message}")
                e.printStackTrace()
            }
        }
        
        /**
         * Завершить звонок
         */
        fun endCall(callId: String) {
            Log.d(TAG, "========================================")
            Log.d(TAG, "🔴 Завершаем звонок: $callId")
            Log.d(TAG, "========================================")
            
            val connection = activeConnections[callId]
            if (connection != null) {
                connection.destroy()
                activeConnections.remove(callId)
                Log.d(TAG, "✅ Звонок завершен")
            } else {
                Log.w(TAG, "⚠️ Соединение не найдено для callId: $callId")
            }
        }
    }
    
    override fun onCreateIncomingConnection(
        connectionRequestPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 onCreateIncomingConnection")
        Log.d(TAG, "========================================")
        
        val callId = request?.extras?.getString("callId") ?: ""
        val callerName = request?.extras?.getString("callerName") ?: "Неизвестный"
        val hasVideo = request?.extras?.getBoolean(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, false) ?: false
        
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "Caller: $callerName")
        Log.d(TAG, "Has Video: $hasVideo")
        
        val connection = VoIPConnection(callId, callerName, hasVideo)
        activeConnections[callId] = connection
        
        Log.d(TAG, "✅ Connection создан")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: Для self-managed звонков нужно явно показать UI
        // Сначала устанавливаем статус RINGING (если еще не установлен)
        // Затем вызываем onShowIncomingCallUi() чтобы система показала UI входящего звонка
        try {
            // Убеждаемся, что статус установлен как RINGING
            connection.setRinging()
            Log.d(TAG, "✅ Статус установлен как RINGING")
            
            // Вызываем onShowIncomingCallUi() чтобы система показала UI входящего звонка
            // Это работает на заблокированном экране
            // При разблокированном экране CallActivity будет запущена напрямую из MyFirebaseMessagingService
            connection.onShowIncomingCallUi()
            Log.d(TAG, "✅ onShowIncomingCallUi вызван")
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Ошибка вызова onShowIncomingCallUi: ${e.message}")
            e.printStackTrace()
        }
        
        return connection
    }
    
    override fun onCreateOutgoingConnection(
        connectionRequestPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 onCreateOutgoingConnection")
        Log.d(TAG, "========================================")
        
        val callId = request?.extras?.getString("callId") ?: ""
        val callerName = request?.extras?.getString("callerName") ?: "Неизвестный"
        val hasVideo = request?.extras?.getBoolean(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, false) ?: false
        
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "Caller: $callerName")
        Log.d(TAG, "Has Video: $hasVideo")
        
        val connection = VoIPConnection(callId, callerName, hasVideo)
        activeConnections[callId] = connection
        
        Log.d(TAG, "✅ Connection создан")
        Log.d(TAG, "========================================")
        
        return connection
    }
}

/**
 * ⭐⭐⭐ VoIP Connection - представляет один звонок
 */
class VoIPConnection(
    private val callId: String,
    private val callerName: String,
    private val hasVideo: Boolean
) : Connection() {
    
    companion object {
        private const val TAG = "VoIPConnection"
    }
    
    init {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔧 VoIPConnection создан")
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "Caller: $callerName")
        Log.d(TAG, "Has Video: $hasVideo")
        Log.d(TAG, "========================================")
        
        // Устанавливаем адрес звонка
        val address = Uri.fromParts(PhoneAccount.SCHEME_SIP, callerName, null)
        setAddress(address, TelecomManager.PRESENTATION_ALLOWED)
        
        // Устанавливаем capabilities (Connection не имеет констант для видео, используем числовые значения)
        // CAPABILITY_SUPPORTS_VIDEO_CALLING = 0x00000001
        // CAPABILITY_VIDEO_CALLING = 0x00000004
        val capabilities = if (hasVideo) {
            0x00000001 or 0x00000004
        } else {
            0
        }
        setConnectionCapabilities(capabilities)
        
        // Устанавливаем video state
        val videoState = if (hasVideo) {
            VideoProfile.STATE_BIDIRECTIONAL
        } else {
            VideoProfile.STATE_AUDIO_ONLY
        }
        setVideoState(videoState)
        
        // Для входящих звонков устанавливаем статус RINGING
        setRinging()
    }
    
    override fun onAnswer() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "✅ Пользователь ПРИНЯЛ звонок")
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "========================================")
        
        setActive()
        
        // Отправляем событие в Flutter
        VoIPConnectionService.flutterChannel?.invokeMethod("callAccepted", mapOf(
            "callId" to callId,
            "callerName" to callerName
        ))
    }
    
    override fun onReject() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🚫 Пользователь ОТКЛОНИЛ звонок")
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "========================================")
        
        setDisconnected(DisconnectCause(DisconnectCause.REJECTED, null, null, null))
        destroy()
        
        // Отправляем событие в Flutter
        VoIPConnectionService.flutterChannel?.invokeMethod("callDeclined", mapOf(
            "callId" to callId
        ))
    }
    
    override fun onDisconnect() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔴 Пользователь ЗАВЕРШИЛ звонок")
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "========================================")
        
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL, null, null, null))
        destroy()
        
        // Отправляем событие в Flutter
        VoIPConnectionService.flutterChannel?.invokeMethod("callEnded", mapOf(
            "callId" to callId
        ))
    }
    
    override fun onHold() {
        Log.d(TAG, "⏸️ Звонок поставлен на удержание")
        setOnHold()
    }
    
    override fun onUnhold() {
        Log.d(TAG, "▶️ Звонок снят с удержания")
        setActive()
    }
    
    override fun onShowIncomingCallUi() {
        Log.d(TAG, "📱 Показываем UI входящего звонка")
        // UI показывается автоматически системой
    }
    
    // Методы setActive, setDialing, setRinging являются final в Connection
    // Используем их напрямую без переопределения
}

