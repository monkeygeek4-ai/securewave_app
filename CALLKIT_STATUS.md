# CallKit Integration Status

**Дата:** 2025-01-XX  
**Статус:** ✅ Готово к тестированию

## 📋 Что реализовано

### iOS Native (Swift)
- ✅ **CallKitManager.swift** - Управление CallKit UI
- ✅ **AudioSessionManager.swift** - Управление аудио сессией
- ✅ **AppDelegate.swift** - Интеграция VoIP Push + CallKit + Flutter channels
- ✅ **Info.plist** - Background Modes (voip, audio, remote-notification)

### Flutter Integration
- ✅ **IOSCallKitHandler** - Обработка событий CallKit
- ✅ **IOSCallKitHelper** - Обертка для вызовов CallKit методов
- ✅ **CallHandler в main.dart** - Автоматическое принятие звонков через CallKit
- ✅ **WebRTC Service** - Интеграция с CallKit для автоматического accept

### Backend Integration
- ✅ **VoIP Push** - Отправка VoIP уведомлений для iOS
- ✅ **Database** - Хранение VoIP токенов (platform, voip_token)
- ✅ **WebSocket** - Отправка call_offer после VoIP push

## 🔄 Flow входящего звонка на iOS

```
1. Backend отправляет VoIP Push
   ↓
2. AppDelegate получает VoIP Push (didReceiveIncomingPushWith)
   ↓
3. CallKitManager.reportIncomingCallSync() - показывает нативный UI
   ↓
4. Пользователь нажимает "Accept" в CallKit UI
   ↓
5. CallKit вызывает provider(perform: CXAnswerCallAction)
   ↓
6. AppDelegate отправляет событие "callAccepted" в Flutter
   ↓
7. IOSCallKitHandler устанавливает флаг _callAcceptedViaCallKit
   ↓
8. Backend отправляет call_offer через WebSocket
   ↓
9. WebRTCService получает call_offer и создает Call(incoming)
   ↓
10. CallHandler проверяет флаг wasCallAcceptedViaCallKit()
   ↓
11. CallScreen открывается с autoAccept=true
   ↓
12. WebRTC автоматически принимает звонок (acceptCall)
```

## 🔧 Исправления

### 1. Несоответствие имен методов для speaker
**Проблема:** AppDelegate использовал `setSpeakerphone`, но Flutter вызывал `setSpeakerEnabled`

**Решение:** Исправлено в AppDelegate.swift:
```swift
case "setSpeakerEnabled":  // ✅ Теперь соответствует Flutter
case "isSpeakerEnabled":    // ✅ Теперь соответствует Flutter
```

## 📱 Методы Flutter Channels

### `com.securewave.app/call`
- `reportIncomingCall(callId, callerName, hasVideo)` - Показать CallKit UI
- `startOutgoingCall(callId, handle, hasVideo)` - Начать исходящий
- `endCall(callId)` - Завершить звонок
- `reportCallConnected()` - Уведомить о соединении
- `reportCallConnecting()` - Уведомить о процессе соединения
- `callAccepted` (event) - Пользователь принял звонок
- `callEnded` (event) - Пользователь завершил звонок
- `voipTokenReceived` (event) - Получен VoIP токен
- `incomingVoIPCall` (event) - Получен VoIP push

### `com.securewave.app/audio`
- `configureAudioSession()` - Настроить для VoIP
- `setSpeakerEnabled(bool enabled)` - Переключение speaker/earpiece
- `isSpeakerEnabled()` - Проверка состояния
- `logAudioState()` - Логирование
- `deactivateAudioSession()` - Деактивировать сессию

## ✅ Критерии успешного теста

1. ✅ VoIP токен регистрируется при запуске приложения
2. ✅ VoIP токен сохраняется в базе данных
3. ✅ При входящем звонке отправляется VoIP Push
4. ✅ CallKit UI показывается на экране блокировки
5. ✅ Accept принимает звонок и открывает CallScreen
6. ✅ Decline отклоняет звонок
7. ✅ Аудио работает корректно (earpiece/speaker)

## 🧪 Тестирование

### Шаг 1: Проверка регистрации VoIP токена
```bash
# В Xcode Console должны быть логи:
[FCM] 📱 iOS: Получение VoIP Push токена...
[FCM] ✅ VoIP токен получен: ...
[Init] 📱 VoIP токен получен в main.dart
[Init] ✅ VoIP токен успешно зарегистрирован на backend
```

### Шаг 2: Проверка VoIP Push при входящем звонке
```bash
# Backend логи:
📤 Sending notification for platform: ios
VoIP token: ...
[VoIP] ✅ Push sent successfully!
```

### Шаг 3: Проверка CallKit UI
```bash
# Xcode Console:
[VoIP] 📥 Входящий VoIP Push получен
[CallKit] 📞 ВХОДЯЩИЙ ЗВОНОК
[CallKit] Показываем CallKit UI
```

### Шаг 4: Проверка Accept через CallKit
```bash
# Xcode Console:
[IOSCallKitHandler] ✅ Пользователь ПРИНЯЛ звонок через CallKit
[CallHandler] ✅ CallKit Accept обнаружен!
[CallHandler] Открываем CallScreen с auto-accept
[WebRTC] 📞 Принимаем звонок через WebRTC (CallKit)
```

## ⚠️ Важные замечания

1. **CallKit работает ТОЛЬКО на реальных iPhone устройствах**
   - Симулятор iOS не поддерживает CallKit
   - Тестирование должно проводиться на физическом устройстве

2. **VoIP Push требует активного интернет соединения**
   - Убедитесь что устройство подключено к интернету
   - Проверьте что VoIP токен зарегистрирован на backend

3. **CallKit UI показывается даже когда приложение убито**
   - Это основное преимущество CallKit
   - После Accept приложение автоматически запускается

4. **После Accept приложение должно быстро подключиться к WebSocket**
   - Убедитесь что WebSocketManager автоматически подключается при запуске
   - Проверьте что call_offer приходит в течение нескольких секунд

## 🐛 Troubleshooting

### Проблема: VoIP токен не регистрируется
**Решение:**
- Проверьте Background Modes в Xcode (voip должен быть включен)
- Проверьте что PushKit инициализирован в AppDelegate
- Проверьте логи в Xcode Console

### Проблема: CallKit UI не показывается
**Решение:**
- Используйте реальный iPhone (не симулятор!)
- Проверьте что VoIP Push получен (есть логи)
- Проверьте что CallKitManager инициализирован
- Проверьте что reportIncomingCallSync вызывается синхронно

### Проблема: Звонок не принимается после Accept
**Решение:**
- Проверьте что WebSocket подключен
- Проверьте что call_offer приходит через WebSocket
- Проверьте что флаг wasCallAcceptedViaCallKit() установлен
- Проверьте логи CallHandler в main.dart

## 📝 Следующие шаги

1. ✅ Код готов
2. ⏳ Тестирование на реальном iPhone
3. ⏳ Проверка всех сценариев (приложение открыто/закрыто/в фоне)
4. ⏳ Проверка аудио (earpiece/speaker)
5. ⏳ Проверка интеграции с WebRTC

## 📚 Связанные файлы

- `ios/Runner/AppDelegate.swift` - Главная интеграция
- `ios/Runner/CallKitManager.swift` - CallKit логика
- `ios/Runner/AudioSessionManager.swift` - Аудио управление
- `lib/helpers/ios_callkit_handler.dart` - Flutter обработчик
- `lib/helpers/ios_callkit_helper.dart` - Flutter обертка
- `lib/main.dart` - CallHandler интеграция
- `lib/services/webrtc_service.dart` - WebRTC интеграция
- `backend/lib/VoIPPush.php` - Backend VoIP Push
- `backend/websocket/call_handlers.php` - WebSocket обработка звонков

