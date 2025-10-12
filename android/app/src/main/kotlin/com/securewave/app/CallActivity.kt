package com.securewave.app

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.util.Log
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class CallActivity : AppCompatActivity() {
    private val TAG = "CallActivity"
    
    private lateinit var callerNameView: TextView
    private lateinit var callTypeView: TextView
    private lateinit var callerAvatarView: ImageView
    private lateinit var acceptButton: Button
    private lateinit var declineButton: Button
    
    private var callId: String? = null
    private var callerName: String? = null
    private var callType: String? = null
    
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 CallActivity onCreate")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: Настройка для показа ПОВЕРХ LOCKSCREEN
        setupLockscreenWindow()
        
        // Получаем данные из Intent
        callId = intent.getStringExtra("callId")
        callerName = intent.getStringExtra("callerName") ?: "Unknown"
        callType = intent.getStringExtra("callType") ?: "audio"
        
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "Caller Name: $callerName")
        Log.d(TAG, "Call Type: $callType")
        Log.d(TAG, "========================================")
        
        // Устанавливаем layout
        setContentView(R.layout.activity_call)
        
        // Включаем экран и держим включенным
        acquireWakeLock()
        
        // Инициализация UI элементов
        callerNameView = findViewById(R.id.callerName)
        callTypeView = findViewById(R.id.callType)
        callerAvatarView = findViewById(R.id.callerAvatar)
        acceptButton = findViewById(R.id.acceptButton)
        declineButton = findViewById(R.id.declineButton)
        
        // Устанавливаем данные
        callerNameView.text = callerName
        callTypeView.text = if (callType == "video") "📹 Видеозвонок" else "📞 Аудиозвонок"
        
        // Обработчики кнопок
        acceptButton.setOnClickListener {
            Log.d(TAG, "✅ Кнопка ACCEPT нажата")
            acceptCall()
        }
        
        declineButton.setOnClickListener {
            Log.d(TAG, "❌ Кнопка DECLINE нажата")
            declineCall()
        }
        
        Log.d(TAG, "✅ CallActivity полностью инициализирована")
    }
    
    /**
     * ⭐⭐⭐ НАСТРОЙКА ОКНА ДЛЯ ПОКАЗА ПОВЕРХ LOCKSCREEN (MIUI OPTIMIZED)
     */
    private fun setupLockscreenWindow() {
        // ⭐ Для всех версий Android
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Android 8.1+ (API 27+)
            Log.d(TAG, "Настройка для Android 8.1+")
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
            
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Android 8.0 (API 26)
            Log.d(TAG, "Настройка для Android 8.0")
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
        } else {
            // Android 7.1 и ниже (API 25-)
            Log.d(TAG, "Настройка для Android 7.1 и ниже")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        
        // ⭐⭐⭐ КРИТИЧНО ДЛЯ MIUI: Дополнительные флаги
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )
        
        // ⭐ Для MIUI: Устанавливаем максимальный приоритет
        window.attributes = window.attributes.apply {
            // Устанавливаем окно "важным"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            }
        }
        
        Log.d(TAG, "✅ Lockscreen window flags установлены (MIUI optimized)")
    }
    
    /**
     * Включаем экран используя WakeLock
     */
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "SecureWave:CallWakeLock"
            )
            wakeLock?.acquire(60 * 1000L) // 60 секунд
            Log.d(TAG, "✅ WakeLock получен")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка получения WakeLock: ${e.message}")
        }
    }
    
    /**
     * Освобождаем WakeLock
     */
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d(TAG, "✅ WakeLock освобожден")
                }
            }
            wakeLock = null
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка освобождения WakeLock: ${e.message}")
        }
    }
    
    /**
     * ⭐⭐⭐ ИСПРАВЛЕНО: Принять звонок
     */
    private fun acceptCall() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 Принимаем звонок: $callId")
        Log.d(TAG, "========================================")
        
        releaseWakeLock()
        CallService.resetCallActivityFlag()
        
        // ⭐⭐⭐ ИСПОЛЬЗУЕМ ACTION + DATA для гарантии нового Intent
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("securewave://call/$callId/accept")
            
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("action", "accept")
        }
        
        Log.d(TAG, "🚀 Запуск MainActivity:")
        Log.d(TAG, "  - action: ${intent.action}")
        Log.d(TAG, "  - data: ${intent.data}")
        Log.d(TAG, "========================================")
        
        startActivity(intent)
        finish()
        
        Log.d(TAG, "✅ MainActivity запущена с action=accept")
    }
    
    /**
     * ⭐⭐⭐ ИСПРАВЛЕНО: Отклонить звонок
     */
    private fun declineCall() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "❌ Отклоняем звонок: $callId")
        Log.d(TAG, "========================================")
        
        releaseWakeLock()
        CallService.resetCallActivityFlag()
        
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("securewave://call/$callId/decline")
            
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("action", "decline")
        }
        
        Log.d(TAG, "🚀 Запуск MainActivity")
        startActivity(intent)
        finish()
        
        Log.d(TAG, "✅ MainActivity запущена с action=decline")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "CallActivity onDestroy")
        CallService.resetCallActivityFlag()
        releaseWakeLock()
    }
    
    override fun onBackPressed() {
        // Блокируем кнопку назад во время звонка
        Log.d(TAG, "⚠️ Back pressed заблокирован")
    }
}