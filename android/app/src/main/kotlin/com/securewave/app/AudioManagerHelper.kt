// android/app/src/main/kotlin/com/securewave/app/AudioManagerHelper.kt
package com.securewave.app

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.util.Log

/**
 * ⭐⭐⭐ Helper для управления аудио роутингом
 * Решает проблему с автоматическим включением громкой связи
 */
class AudioManagerHelper(private val context: Context) {
    
    companion object {
        private const val TAG = "AudioManagerHelper"
    }
    
    private val audioManager: AudioManager = 
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    
    private var savedAudioMode: Int = AudioManager.MODE_NORMAL
    private var savedSpeakerphoneOn: Boolean = false
    
    /**
     * ⭐ КРИТИЧНО: Устанавливает режим для ГОЛОСОВОГО звонка через earpiece
     * Вызывается при начале аудио-звонка
     */
    fun setAudioModeForVoiceCall() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🎧 Настройка аудио для ГОЛОСОВОГО звонка")
        Log.d(TAG, "========================================")

        try {
            // Сохраняем текущие настройки
            savedAudioMode = audioManager.mode
            savedSpeakerphoneOn = audioManager.isSpeakerphoneOn

            Log.d(TAG, "Сохранены настройки:")
            Log.d(TAG, "  - Mode: $savedAudioMode")
            Log.d(TAG, "  - Speakerphone: $savedSpeakerphoneOn")

            // ⭐⭐⭐ КРИТИЧНО: Множественные попытки установки режима
            // Это необходимо, так как WebRTC может переопределять настройки
            for (attempt in 1..3) {
                Log.d(TAG, "Попытка $attempt установки режима earpiece")

                // Останавливаем Bluetooth SCO если активен
                if (audioManager.isBluetoothScoOn) {
                    audioManager.stopBluetoothSco()
                    Log.d(TAG, "  - Bluetooth SCO остановлен")
                }

                // Устанавливаем режим IN_COMMUNICATION
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

                // КРИТИЧНО: Выключаем громкую связь
                audioManager.isSpeakerphoneOn = false

                // Задержка для применения настроек
                Thread.sleep(150)

                // Проверяем что установилось
                val actualSpeaker = audioManager.isSpeakerphoneOn
                val actualMode = audioManager.mode

                Log.d(TAG, "  - Mode: $actualMode")
                Log.d(TAG, "  - Speaker: $actualSpeaker")

                if (!actualSpeaker && actualMode == AudioManager.MODE_IN_COMMUNICATION) {
                    Log.d(TAG, "  ✅ Настройки применены успешно на попытке $attempt")
                    break
                } else {
                    Log.w(TAG, "  ⚠️ Попытка $attempt не удалась, повторяем...")
                }
            }

            Log.d(TAG, "========================================")
            Log.d(TAG, "📊 Финальное состояние:")
            Log.d(TAG, "  - Mode: ${audioManager.mode} (${getModeString(audioManager.mode)})")
            Log.d(TAG, "  - Speakerphone: ${audioManager.isSpeakerphoneOn}")
            Log.d(TAG, "  - Bluetooth SCO: ${audioManager.isBluetoothScoOn}")
            Log.d(TAG, "========================================")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка настройки аудио: ${e.message}")
            e.printStackTrace()
        }
    }
    
    /**
     * ⭐ КРИТИЧНО: Устанавливает режим для ВИДЕО звонка через speaker
     * Вызывается при начале видео-звонка
     */
    fun setAudioModeForVideoCall() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📹 Настройка аудио для ВИДЕО звонка")
        Log.d(TAG, "========================================")
        
        try {
            savedAudioMode = audioManager.mode
            savedSpeakerphoneOn = audioManager.isSpeakerphoneOn
            
            // Для видео - включаем громкую связь
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.isSpeakerphoneOn = true
            
            Log.d(TAG, "✅ Громкая связь включена для видео")
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка: ${e.message}")
        }
    }
    
    /**
     * Переключает громкую связь ON/OFF
     */
    fun toggleSpeaker(enable: Boolean) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔊 Toggle Speaker: $enable")
        Log.d(TAG, "========================================")
        
        try {
            // ⭐⭐⭐ ИСПРАВЛЕНО: Множественные попытки установки
            for (i in 1..3) {
                audioManager.isSpeakerphoneOn = enable
                Thread.sleep(50) // Небольшая задержка
                
                // Проверяем что установилось
                val actualState = audioManager.isSpeakerphoneOn
                Log.d(TAG, "Попытка $i: requested=$enable, actual=$actualState")
                
                if (actualState == enable) {
                    Log.d(TAG, "✅ Speakerphone установлен корректно")
                    break
                }
            }
            
            // Финальная проверка
            val finalState = audioManager.isSpeakerphoneOn
            Log.d(TAG, "========================================")
            Log.d(TAG, "📊 Финальное состояние:")
            Log.d(TAG, "  Requested: $enable")
            Log.d(TAG, "  Actual: $finalState")
            
            if (finalState != enable) {
                Log.e(TAG, "⚠️⚠️⚠️ НЕ УДАЛОСЬ УСТАНОВИТЬ SPEAKER!")
                Log.e(TAG, "Возможно WebRTC переопределяет настройки")
            }
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка переключения: ${e.message}")
        }
    }
    
    /**
     * Получить текущее состояние громкой связи
     */
    fun isSpeakerphoneOn(): Boolean {
        return audioManager.isSpeakerphoneOn
    }
    
    /**
     * ⭐ КРИТИЧНО: Восстанавливает оригинальные настройки аудио
     * Вызывается при завершении звонка
     */
    fun restoreAudioSettings() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔄 Восстановление аудио настроек")
        Log.d(TAG, "========================================")
        
        try {
            audioManager.mode = savedAudioMode
            audioManager.isSpeakerphoneOn = savedSpeakerphoneOn
            
            Log.d(TAG, "✅ Настройки восстановлены:")
            Log.d(TAG, "  - Mode: ${audioManager.mode}")
            Log.d(TAG, "  - Speakerphone: ${audioManager.isSpeakerphoneOn}")
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка восстановления: ${e.message}")
        }
    }
    
    /**
     * Логирование текущего состояния аудио
     */
    fun logAudioState() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "📊 СОСТОЯНИЕ АУДИО:")
        Log.d(TAG, "----------------------------------------")
        Log.d(TAG, "Mode: ${getModeString(audioManager.mode)}")
        Log.d(TAG, "Speakerphone ON: ${audioManager.isSpeakerphoneOn}")
        Log.d(TAG, "Bluetooth SCO ON: ${audioManager.isBluetoothScoOn}")
        Log.d(TAG, "Wired Headset ON: ${audioManager.isWiredHeadsetOn}")
        Log.d(TAG, "Music Active: ${audioManager.isMusicActive}")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            Log.d(TAG, "----------------------------------------")
            Log.d(TAG, "Доступные устройства вывода:")
            devices.forEach { device ->
                Log.d(TAG, "  - ${device.productName} (Type: ${device.type})")
            }
        }
        
        Log.d(TAG, "========================================")
    }
    
    private fun getModeString(mode: Int): String {
        return when (mode) {
            AudioManager.MODE_NORMAL -> "NORMAL"
            AudioManager.MODE_RINGTONE -> "RINGTONE"
            AudioManager.MODE_IN_CALL -> "IN_CALL"
            AudioManager.MODE_IN_COMMUNICATION -> "IN_COMMUNICATION"
            else -> "UNKNOWN ($mode)"
        }
    }
}