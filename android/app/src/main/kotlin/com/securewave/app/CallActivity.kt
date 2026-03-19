package com.securewave.app

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.util.Log
import android.view.View
import android.view.WindowManager
import android.view.animation.AccelerateDecelerateInterpolator
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.cardview.widget.CardView
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.request.RequestOptions

class CallActivity : AppCompatActivity() {
    private val TAG = "CallActivity"
    
    private lateinit var callerNameView: TextView
    private lateinit var callTypeView: TextView
    private lateinit var callerAvatarView: ImageView
    private lateinit var acceptButton: LinearLayout
    private lateinit var declineButton: LinearLayout
    // ⭐ Убраны: callTypeIcon, pulseCircle1, pulseCircle2, ringingIcon
    
    private var callId: String? = null
    private var callerName: String? = null
    private var callType: String? = null
    private var callerAvatar: String? = null
    
    private var wakeLock: PowerManager.WakeLock? = null
    private val animators = mutableListOf<ValueAnimator>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 CallActivity onCreate")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: Настраиваем полноэкранный режим ДО setContentView
        setupLockscreenWindow()
        setupFullscreen()
        
        // Получаем данные из Intent
        callId = intent.getStringExtra("callId")
        callerName = intent.getStringExtra("callerName") ?: "Unknown"
        callType = intent.getStringExtra("callType") ?: "audio"
        callerAvatar = intent.getStringExtra("callerAvatar")
        
        Log.d(TAG, "Call ID: $callId")
        Log.d(TAG, "Caller Name: $callerName")
        Log.d(TAG, "Call Type: $callType")
        Log.d(TAG, "Caller Avatar: $callerAvatar")
        Log.d(TAG, "========================================")
        
        setContentView(R.layout.activity_call)
        
        // ⭐⭐⭐ КРИТИЧНО: Применяем полноэкранный режим после setContentView
        setupFullscreen()
        
        // ⭐⭐⭐ КРИТИЧНО: Принудительно применяем полноэкранный режим после отрисовки
        window.decorView.post {
            setupFullscreen()
            // Убеждаемся, что окно занимает весь экран
            window.setLayout(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT
            )
        }
        
        acquireWakeLock()
        initViews()
        setupUI()
        startAnimations()
        
        Log.d(TAG, "✅ CallActivity полностью инициализирована")
    }
    
    private fun initViews() {
        callerNameView = findViewById(R.id.callerName)
        callTypeView = findViewById(R.id.callType)
        callerAvatarView = findViewById(R.id.callerAvatar)
        acceptButton = findViewById(R.id.acceptButton)
        declineButton = findViewById(R.id.declineButton)
        // ⭐ Убраны: callTypeIcon, pulseCircle1, pulseCircle2, ringingIcon
    }
    
    private fun setupUI() {
        // Устанавливаем имя
        callerNameView.text = callerName
        
        // Устанавливаем тип звонка
        val isVideo = callType == "video"
        callTypeView.text = if (isVideo) "Видеозвонок" else "Входящий звонок..."
        
        // ⭐ Загружаем аватар с помощью Glide (теперь на весь экран)
        loadAvatar()
        
        // Обработчики кнопок
        acceptButton.setOnClickListener {
            Log.d(TAG, "✅ Кнопка ACCEPT нажата")
            stopAnimations()
            acceptCall()
        }
        
        declineButton.setOnClickListener {
            Log.d(TAG, "❌ Кнопка DECLINE нажата")
            stopAnimations()
            declineCall()
        }
    }
    
    /**
     * ⭐ Загружаем аватар с помощью Glide
     */
    private fun loadAvatar() {
        val avatar = callerAvatar
        if (!avatar.isNullOrEmpty()) {
            Log.d(TAG, "📸 Загружаем аватар: $avatar")
            
            // ⭐⭐⭐ КРИТИЧНО: Если путь начинается с /, добавляем базовый URL
            val baseServerUrl = "https://securewave.sbk-19.ru"
            val avatarUrl = if (avatar.startsWith("/")) {
                // Относительный путь от корня сервера
                "$baseServerUrl$avatar"
            } else if (!avatar.startsWith("http://") && !avatar.startsWith("https://")) {
                // Если это не полный URL и не начинается с /, добавляем базовый URL
                "$baseServerUrl/$avatar"
            } else {
                // Уже полный URL
                avatar
            }
            
            Log.d(TAG, "📸 Полный URL аватара: $avatarUrl")
            
            Glide.with(this)
                .load(avatarUrl)
                .apply(
                    RequestOptions()
                        .centerCrop() // ⭐ Изменено с circleCrop на centerCrop для полноэкранного отображения
                        .placeholder(R.drawable.default_avatar)
                        .error(R.drawable.default_avatar)
                        .diskCacheStrategy(DiskCacheStrategy.ALL)
                        .timeout(10000) // 10 секунд таймаут
                )
                .into(callerAvatarView)
        } else {
            Log.d(TAG, "⚠️ Аватар отсутствует, используем default")
            callerAvatarView.setImageResource(R.drawable.default_avatar)
        }
    }
    
    /**
     * ⭐⭐⭐ АНИМАЦИИ для красивого эффекта
     */
    private fun startAnimations() {
        // ⭐ Анимации убраны (ringingIcon удален)
        Log.d(TAG, "✅ Анимации запущены (нет активных анимаций)")
    }
    
    private fun stopAnimations() {
        animators.forEach { it.cancel() }
        animators.clear()
    }
    
    private fun setupLockscreenWindow() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔧 Настройка окна для показа поверх заблокированного экрана")
        Log.d(TAG, "Android version: ${Build.VERSION.SDK_INT}")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: Для Android 8.1+ используем новые методы
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            Log.d(TAG, "📱 Android 8.1+ - используем setShowWhenLocked/setTurnScreenOn")
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
            // ⭐⭐⭐ КРИТИЧНО: Пытаемся разблокировать экран с callback
            try {
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    val callback = object : KeyguardManager.KeyguardDismissCallback() {
                        override fun onDismissError() {
                            Log.e(TAG, "❌ Ошибка разблокировки экрана")
                        }
                        override fun onDismissSucceeded() {
                            Log.d(TAG, "✅ Экран успешно разблокирован")
                        }
                        override fun onDismissCancelled() {
                            Log.w(TAG, "⚠️ Разблокировка отменена")
                        }
                    }
                    keyguardManager.requestDismissKeyguard(this, callback)
                    Log.d(TAG, "✅ requestDismissKeyguard вызван с callback")
                } else {
                    @Suppress("DEPRECATION")
                    keyguardManager.requestDismissKeyguard(this, null)
                    Log.d(TAG, "✅ requestDismissKeyguard вызван (deprecated)")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Ошибка requestDismissKeyguard: ${e.message}")
                e.printStackTrace()
            }
            
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Log.d(TAG, "📱 Android 8.0 - используем setShowWhenLocked/setTurnScreenOn")
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            
        } else {
            Log.d(TAG, "📱 Android 7.1 и ниже - используем window flags")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        
        // ⭐⭐⭐ КРИТИЧНО: Добавляем все необходимые флаги для показа поверх заблокированного экрана
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )
        
        // ⭐⭐⭐ КРИТИЧНО: Делаем окно полноэкранным
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }
        
        // Скрываем системные UI элементы (status bar, navigation bar)
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        )
        
        // ⭐⭐⭐ КРИТИЧНО: НЕ используем TYPE_APPLICATION_OVERLAY без разрешения
        // Для показа поверх заблокированного экрана достаточно стандартного типа окна
        // с правильными флагами
        
        Log.d(TAG, "✅ Lockscreen window flags установлены")
        Log.d(TAG, "   - FLAG_SHOW_WHEN_LOCKED: установлен")
        Log.d(TAG, "   - FLAG_DISMISS_KEYGUARD: установлен")
        Log.d(TAG, "   - FLAG_TURN_SCREEN_ON: установлен")
        Log.d(TAG, "========================================")
    }
    
    private fun setupFullscreen() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔧 Настройка полноэкранного режима")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: Убеждаемся, что окно занимает весь экран
        // НЕ меняем тип окна - используем стандартный TYPE_APPLICATION для Activity
        // Это работает лучше с full-screen intent
        
        // ⭐⭐⭐ КРИТИЧНО: Для Android 11+ используем WindowInsetsController
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(android.view.WindowInsets.Type.statusBars() or android.view.WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            // Для старых версий используем systemUiVisibility
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )
        }
        
        // ⭐⭐⭐ КРИТИЧНО: Убираем отступы для системных UI элементов
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }
        
        // ⭐⭐⭐ КРИТИЧНО: Принудительно устанавливаем размер окна
        window.setLayout(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT
        )
        
        Log.d(TAG, "✅ Полноэкранный режим настроен")
        Log.d(TAG, "   - Размер окна: MATCH_PARENT x MATCH_PARENT")
        Log.d(TAG, "   - Системные UI элементы скрыты")
        Log.d(TAG, "========================================")
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "SecureWave:CallWakeLock"
            )
            wakeLock?.acquire(60 * 1000L)
            Log.d(TAG, "✅ WakeLock получен")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка получения WakeLock: ${e.message}")
        }
    }
    
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
    
    private fun acceptCall() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📞 Принимаем звонок: $callId")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: Отменяем уведомление и останавливаем вибрацию
        callId?.let { id ->
            try {
                CallNotificationHelper.cancelNotification(this, id)
                Log.d(TAG, "✅ Уведомление отменено, вибрация остановлена")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Ошибка отмены уведомления: ${e.message}")
            }
        }
        
        releaseWakeLock()
        // ⭐ УДАЛЕНО: CallService.resetCallActivityFlag()
        
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
        
        Log.d(TAG, "🚀 Запуск MainActivity")
        startActivity(intent)
        finish()
        
        Log.d(TAG, "✅ MainActivity запущена с action=accept")
    }
    
    private fun declineCall() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "❌ Отклоняем звонок: $callId")
        Log.d(TAG, "========================================")
        
        // ⭐⭐⭐ КРИТИЧНО: Отменяем уведомление и останавливаем вибрацию
        callId?.let { id ->
            try {
                CallNotificationHelper.cancelNotification(this, id)
                Log.d(TAG, "✅ Уведомление отменено, вибрация остановлена")
            } catch (e: Exception) {
                Log.w(TAG, "⚠️ Ошибка отмены уведомления: ${e.message}")
            }
        }
        
        releaseWakeLock()
        // ⭐ УДАЛЕНО: CallService.resetCallActivityFlag()
        
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
        stopAnimations()
        // ⭐ УДАЛЕНО: CallService.resetCallActivityFlag()
        releaseWakeLock()
    }
    
    override fun onBackPressed() {
        Log.d(TAG, "⚠️ Back pressed заблокирован")
    }
}