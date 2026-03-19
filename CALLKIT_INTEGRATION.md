# CallKit Integration Summary

## Что было сделано

### ✅ Android (ГОТОВО)
1. **CallActivity.kt** - Full-screen incoming call UI
2. **CallService.kt** - Foreground service для звонков
3. **AudioManagerHelper.kt** - Управление аудио роутингом (earpiece/speaker)
4. **MainActivity.kt** - Интеграция с Flutter через MethodChannel
5. **FCM** - Push уведомления для входящих звонков

**Результат**: Входящие звонки работают с нативным Android UI, аудио идёт через earpiece ✅

### ✅ iOS (СОЗДАНО, ТРЕБУЕТ ТЕСТИРОВАНИЯ)
1. **CallKitManager.swift** - Управление CallKit (нативный UI звонков)
2. **AudioSessionManager.swift** - Управление аудио сессией iOS
3. **AppDelegate.swift** - Интеграция CallKit + VoIP Push + Flutter channels
4. **Info.plist** - Permissions и Background Modes

**Результат**: Код создан, требуется:
- Добавить файлы в Xcode проект (см. [IOS_SETUP.md](IOS_SETUP.md))
- Протестировать на реальном iPhone
- Настроить VoIP сертификаты в Apple Developer Portal (опционально)

---

## Архитектура

### Android Flow

```
FCM Push → MyFirebaseMessagingService
           ↓
       CallActivity (Full-screen UI)
           ↓
    User presses Accept/Decline
           ↓
       MainActivity (Flutter)
           ↓
       WebRTC Service
           ↓
       CallScreen (Flutter UI)
```

### iOS Flow

```
VoIP Push → AppDelegate (PKPushRegistry)
            ↓
        CallKit UI (Native)
            ↓
    User presses Accept/Decline
            ↓
        CallKitManager Delegate
            ↓
        Flutter via MethodChannel
            ↓
        WebRTC Service
            ↓
        CallScreen (Flutter UI)
```

---

## Flutter Channels

### Android

- `com.securewave.app/audio`
  - `setAudioModeForVoiceCall()` - Режим earpiece
  - `setAudioModeForVideoCall()` - Режим speaker
  - `toggleSpeaker(bool enabled)` - Переключение
  - `isSpeakerphoneOn()` - Проверка состояния
  - `logAudioState()` - Логирование

### iOS

- `com.securewave.app/callkit`
  - `reportIncomingCall(callId, callerName, hasVideo)` - Показать CallKit UI
  - `startOutgoingCall(callId, handle, hasVideo)` - Начать исходящий
  - `endCall(callId)` - Завершить звонок
  - `reportCallConnected()` - Уведомить о соединении
  - `reportCallConnecting()` - Уведомить о процессе соединения

- `com.securewave.app/audio`
  - `configureAudioSession()` - Настроить для VoIP
  - `setSpeakerEnabled(bool enabled)` - Переключение speaker/earpiece
  - `isSpeakerEnabled()` - Проверка состояния
  - `logAudioState()` - Логирование

---

## Следующие шаги

### iOS
1. ✅ Код создан
2. ⏳ Добавить файлы в Xcode (см. IOS_SETUP.md)
3. ⏳ Build и исправить ошибки компиляции
4. ⏳ Протестировать на iPhone
5. ⏳ Интегрировать с Flutter кодом (создать iOS wrapper для WebRTC)

### Опционально
- 📱 Настроить VoIP Push сертификаты (для production)
- 🎨 Кастомизация CallKit UI (иконка, рингтон)
- 🔔 PushKit интеграция на сервере

---

## Тестирование

### Android
```bash
# Build и установка
flutter run -d <android-device-id>

# Отправить входящий звонок через FCM
# Должен появиться CallActivity с кнопками Accept/Decline
```

### iOS
```bash
# Build и установка
flutter run -d <iphone-device-id>

# Отправить входящий звонок через VoIP Push
# Должен появиться нативный CallKit UI
```

---

## Troubleshooting

### Android: Аудио не слышно
- Проверить `AudioManagerHelper` логи
- Убедиться что `MODE_IN_COMMUNICATION` установлен
- Проверить что `speakerphoneOn = false`

### iOS: CallKit не показывается
- Должен быть **реальный iPhone** (симулятор не поддерживает CallKit)
- Проверить Background Modes в Xcode
- Проверить логи в Xcode Console

### iOS: Ошибки компиляции
- Убедиться что Swift files добавлены в Target Membership
- Clean Build Folder (⌘⇧K) и rebuild
- Проверить Swift version >= 5.0
