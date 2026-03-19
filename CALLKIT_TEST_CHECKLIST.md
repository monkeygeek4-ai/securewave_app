# CallKit Testing Checklist

## 📋 Чеклист для проверки CallKit интеграции

### ✅ Шаг 1: Проверка регистрации VoIP токена

**На iOS устройстве:**
1. Откройте приложение
2. Проверьте логи в Xcode Console:
   ```
   [FCM] 📱 iOS: Получение VoIP Push токена...
   [FCM] ✅ VoIP токен получен: ...
   [Init] 📱 VoIP токен получен в main.dart
   [Init] ✅ VoIP токен успешно зарегистрирован на backend
   ```

**На сервере (база данных):**
```sql
-- Проверьте что VoIP токен сохранен
SELECT id, user_id, platform, 
       LEFT(token, 30) as fcm_token_start,
       LEFT(voip_token, 30) as voip_token_start,
       created_at, updated_at
FROM fcm_tokens 
WHERE user_id = 1 AND platform = 'ios'
ORDER BY updated_at DESC;
```

**Ожидаемый результат:**
- ✅ `platform = 'ios'`
- ✅ `voip_token IS NOT NULL`
- ✅ `voip_token` содержит валидный токен (64 символа)

---

### ✅ Шаг 2: Проверка отправки VoIP Push при входящем звонке

**Инициируйте звонок с другого устройства**

**Проверьте логи на сервере:**
```
📞 PROCESSING CALL_OFFER
📱 Found X FCM token(s)
📤 Sending notification for platform: ios
   FCM token: ...
   VoIP token: ...
[VoIP] Sending push notification
[VoIP] ✅ Push sent successfully!
✅✅✅ Notification sent successfully for platform: ios
```

**Ожидаемый результат:**
- ✅ Backend определяет платформу как `ios`
- ✅ Backend находит VoIP токен
- ✅ VoIP Push отправляется через `VoIPPush.php`
- ✅ Статус ответа от APNs = 200

---

### ✅ Шаг 3: Проверка получения VoIP Push на iOS

**На iOS устройстве (Xcode Console):**
```
[VoIP] 📥 Входящий VoIP Push получен
[VoIP] Call ID: ...
[VoIP] Caller: ...
[CallKit] 📞 ВХОДЯЩИЙ ЗВОНОК
[CallKit] Показываем CallKit UI
```

**Ожидаемый результат:**
- ✅ VoIP Push получен в AppDelegate
- ✅ CallKit UI показывается (нативный экран звонка iOS)
- ✅ Отображается имя звонящего
- ✅ Есть кнопки Accept/Decline

---

### ✅ Шаг 4: Проверка обработки Accept через CallKit

**На iOS устройстве:**
1. Нажмите "Accept" в CallKit UI
2. Проверьте логи:

```
[IOSCallKitHandler] ✅ Пользователь ПРИНЯЛ звонок через CallKit
[IOSCallKitHandler] 🚩 Флаг установлен для callId
[CallHandler] ✅ CallKit Accept обнаружен!
[CallHandler] Открываем CallScreen с auto-accept
[CallHandler] 📞 Принимаем звонок через WebRTC (CallKit)
```

**Ожидаемый результат:**
- ✅ CallKit вызывает delegate метод
- ✅ Flutter получает событие `callAccepted`
- ✅ CallScreen открывается автоматически
- ✅ Звонок принимается через WebRTC

---

### ✅ Шаг 5: Проверка обработки Decline через CallKit

**На iOS устройстве:**
1. Нажмите "Decline" в CallKit UI
2. Проверьте логи:

```
[IOSCallKitHandler] ❌ Пользователь ОТКЛОНИЛ звонок через CallKit
[WebRTC] Отклоняем звонок: ...
```

**Ожидаемый результат:**
- ✅ CallKit вызывает delegate метод
- ✅ Flutter получает событие `callEnded`
- ✅ Звонок отклоняется через WebSocket
- ✅ Инициатор получает уведомление об отклонении

---

## 🔍 Диагностика проблем

### Проблема: VoIP токен не регистрируется

**Проверьте:**
1. ✅ Background Modes включены в Xcode:
   - Capabilities → Background Modes → Voice over IP
2. ✅ PushKit инициализирован в AppDelegate
3. ✅ Логи показывают получение VoIP токена

**Решение:**
```swift
// В AppDelegate.swift должен быть:
let voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
voipRegistry.delegate = self
voipRegistry.desiredPushTypes = [.voIP]
```

---

### Проблема: VoIP Push не отправляется

**Проверьте:**
1. ✅ VoIP токен есть в базе данных
2. ✅ Backend логи показывают попытку отправки
3. ✅ Сертификат VoIP Push настроен (`voip_push.p12`)

**Решение:**
```bash
# Проверьте наличие сертификата
ls -la backend/certificates/voip_push.p12

# Проверьте логи отправки
tail -f backend/logs/server.log | grep -i voip
```

---

### Проблема: CallKit UI не показывается

**Проверьте:**
1. ✅ Используется **реальный iPhone** (симулятор не поддерживает CallKit!)
2. ✅ VoIP Push получен (есть логи)
3. ✅ CallKitManager инициализирован

**Решение:**
- CallKit работает ТОЛЬКО на реальных устройствах
- Проверьте логи в Xcode Console
- Убедитесь что `reportIncomingCall()` вызывается

---

### Проблема: Звонок не принимается после Accept

**Проверьте:**
1. ✅ WebSocket подключен
2. ✅ Call_offer получен через WebSocket
3. ✅ Флаг `wasCallAcceptedViaCallKit()` установлен

**Решение:**
- Проверьте логи WebSocket соединения
- Убедитесь что `call_offer` приходит после VoIP Push
- Проверьте что CallHandler проверяет CallKit флаг

---

## 📊 SQL запросы для проверки

### Проверка токенов пользователя:
```sql
SELECT 
    id,
    user_id,
    platform,
    LEFT(token, 30) as fcm_token,
    LEFT(voip_token, 30) as voip_token,
    created_at,
    updated_at
FROM fcm_tokens
WHERE user_id = 1
ORDER BY updated_at DESC;
```

### Проверка активных звонков:
```sql
SELECT 
    id,
    call_uuid,
    caller_id,
    receiver_id,
    call_type,
    status,
    started_at,
    connected_at,
    ended_at
FROM calls
WHERE status IN ('pending', 'active')
ORDER BY started_at DESC;
```

### Проверка сигналов звонка:
```sql
SELECT 
    cs.id,
    cs.call_id,
    cs.signal_type,
    cs.from_user_id,
    cs.to_user_id,
    cs.created_at,
    LEFT(cs.signal_data::text, 100) as signal_preview
FROM call_signals cs
JOIN calls c ON cs.call_id = c.id
WHERE c.call_uuid = 'your-call-id'
ORDER BY cs.created_at;
```

---

## ✅ Критерии успешного теста

1. ✅ VoIP токен регистрируется при запуске приложения
2. ✅ VoIP токен сохраняется в базе данных
3. ✅ При входящем звонке отправляется VoIP Push
4. ✅ CallKit UI показывается на экране блокировки
5. ✅ Accept принимает звонок и открывает CallScreen
6. ✅ Decline отклоняет звонок
7. ✅ Аудио работает корректно (earpiece/speaker)

---

## 📝 Примечания

- **Важно:** CallKit работает ТОЛЬКО на реальных iPhone устройствах
- Симулятор iOS не поддерживает CallKit
- VoIP Push требует активного интернет соединения
- CallKit UI показывается даже когда приложение убито
- После Accept приложение должно быстро подключиться к WebSocket

