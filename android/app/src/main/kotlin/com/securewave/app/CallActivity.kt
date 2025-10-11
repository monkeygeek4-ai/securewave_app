package com.securewave.app

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 CallActivity onCreate")
        Log.d(TAG, "========================================")
        
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
        
        // ============================================
        // НАСТРОЙКА ОКНА ДЛЯ ПОКАЗА ПОВЕРХ LOCKSCREEN
        // ============================================
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Android 8.1+
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            // Android 8.0 и ниже
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        
        // Дополнительные флаги для полноэкранного режима
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
        
        Log.d(TAG, "✅ Window flags установлены")
        
        // Инициализация UI элементов
        callerNameView = findViewById(R.id.callerName)
        callTypeView = findViewById(R.id.callType)
        callerAvatarView = findViewById(R.id.callerAvatar)
        acceptButton = findViewById(R.id.acceptButton)
        declineButton = findViewById(R.id.declineButton)
        
        // Устанавливаем данные
        callerNameView.text = callerName
        callTypeView.text = if (callType == "video") "📹 Видеозвонок" else "📞 Аудиозвонок"
        
        // TODO: Загрузить аватар caller'а
        // callerAvatarView.setImageURI(...)
        
        // Обработчики кнопок
        acceptButton.setOnClickListener {
            Log.d(TAG, "========================================")
            Log.d(TAG, "✅ Кнопка ACCEPT нажата")
            Log.d(TAG, "========================================")
            acceptCall()
        }
        
        declineButton.setOnClickListener {
            Log.d(TAG, "========================================")
            Log.d(TAG, "❌ Кнопка DECLINE нажата")
            Log.d(TAG, "========================================")
            declineCall()
        }
        
        Log.d(TAG, "✅ CallActivity полностью инициализирована")
        Log.d(TAG, "========================================")
    }
    
    /**
     * Принять звонок
     */
    private fun acceptCall() {
        Log.d(TAG, "📞 Принимаем звонок: $callId")
        
        // Закрываем CallActivity
        finish()
        
        // Запускаем MainActivity с параметрами звонка
        // Flutter откроет CallScreen автоматически
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("action", "accept")
        }
        
        startActivity(intent)
        
        Log.d(TAG, "✅ MainActivity запущена с action=accept")
    }
    
    /**
     * Отклонить звонок
     */
    private fun declineCall() {
        Log.d(TAG, "❌ Отклоняем звонок: $callId")
        
        // Запускаем MainActivity с параметрами отклонения
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", "incoming_call")
            putExtra("callId", callId)
            putExtra("callerName", callerName)
            putExtra("callType", callType)
            putExtra("action", "decline")
        }
        
        startActivity(intent)
        
        // Закрываем CallActivity
        finish()
        
        Log.d(TAG, "✅ MainActivity запущена с action=decline")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "========================================")
        Log.d(TAG, "CallActivity onDestroy")
        Log.d(TAG, "========================================")
    }
}