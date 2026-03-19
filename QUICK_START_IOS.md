# 🚀 Быстрый старт iOS VoIP уведомлений

## Что уже сделано ✅

**Приложение полностью настроено** для работы с VoIP push уведомлениями! Осталось только настроить backend.

### Что работает в приложении:
1. ✅ VoIP Push Registration (PushKit)
2. ✅ CallKit интеграция (нативный UI звонков)
3. ✅ Обработка входящих звонков когда приложение закрыто
4. ✅ Автоматическая регистрация VoIP токена на backend
5. ✅ Управление аудио сессией

## Что нужно сделать (3 шага)

### Шаг 1: Получить VoIP сертификат (5 минут)

1. Откройте [Apple Developer Portal](https://developer.apple.com/account/)
2. Certificates → ➕ → **VoIP Services Certificate**
3. Выберите App ID: `com.securewavenew.app`
4. Создайте CSR и загрузите
5. Скачайте сертификат (.cer)
6. Экспортируйте из Keychain как **.p12** (с паролем)

**Альтернатива (проще):** Используйте .p8 Auth Key:
- Keys → ➕ → Apple Push Notifications service (APNs)
- Скачайте .p8 файл и запомните Key ID

### Шаг 2: Настроить backend (10 минут)

#### A. Установите PHP библиотеку
```bash
cd /path/to/backend
composer require edamov/pushok
```

#### B. Создайте файл `/notifications/register-voip.php`
Скопируйте код из [IOS_VOIP_SETUP.md](./IOS_VOIP_SETUP.md#создайте-файл-notificationsregister-voipphp)

#### C. Создайте таблицу (если нет)
```sql
CREATE TABLE IF NOT EXISTS push_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL,
    type VARCHAR(20) DEFAULT 'fcm',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_token (user_id, platform, type)
);
```

#### D. Создайте `/utils/voip_push.php`
Скопируйте класс `VoIPPushSender` из [IOS_VOIP_SETUP.md](./IOS_VOIP_SETUP.md#обновите-отправку-voip-push-уведомлений)

**ВАЖНО:** Замените в коде:
- `YOUR_KEY_ID` → ваш Key ID
- `YOUR_TEAM_ID` → ваш Team ID
- `path/to/AuthKey_XXXXX.p8` → путь к .p8 файлу
- Или используйте .p12 вариант

#### E. Интегрируйте в WebSocket сервер
Когда приходит входящий звонок:
```php
<?php
require_once '../utils/voip_push.php';

// При входящем звонке
function onIncomingCall($userId, $callData) {
    // ... ваш код ...

    // Отправляем VoIP push на iOS
    $pdo = getDBConnection();
    $stmt = $pdo->prepare("
        SELECT token FROM push_tokens
        WHERE user_id = ? AND platform = 'ios' AND type = 'voip'
        LIMIT 1
    ");
    $stmt->execute([$userId]);
    $tokenData = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($tokenData) {
        $voipPush = new VoIPPushSender();
        $voipPush->sendIncomingCall(
            $tokenData['token'],
            $callData['callId'],
            $callData['callerName'],
            $callData['callType'] ?? 'audio'
        );
    }
}
```

### Шаг 3: Тестирование (5 минут)

#### A. Запустите на реальном iPhone
```bash
flutter run --release
```

**ВАЖНО:** VoIP работает ТОЛЬКО на реальных устройствах!

#### B. Проверьте логи в Xcode
Откройте Window → Devices and Simulators → выберите устройство → View Device Logs

Должны увидеть:
```
📱 VoIP Push Token получен!
Token: 1234567890abcdef...
✅ VoIP токен успешно зарегистрирован на backend
```

#### C. Проверьте в БД
```sql
SELECT * FROM push_tokens WHERE type = 'voip' AND platform = 'ios';
```

Должна быть запись с токеном!

#### D. Протестируйте звонок
1. Закройте приложение ПОЛНОСТЬЮ (смахните из App Switcher)
2. Отправьте звонок от другого пользователя
3. Должен появиться **нативный CallKit UI** 📞

## 🎉 Готово!

Теперь ваше приложение:
- ✅ Получает входящие звонки когда закрыто
- ✅ Показывает нативный iOS интерфейс звонка
- ✅ Работает в фоновом режиме
- ✅ Не потребляет батарею

## ❓ Проблемы?

### Токен не регистрируется
```bash
# Проверьте логи приложения
flutter run --verbose

# Проверьте что endpoint доступен
curl -X POST https://your-backend.com/notifications/register-voip.php \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"token":"test","platform":"ios","type":"voip"}'
```

### Push не приходит
1. Проверьте сертификат (должен быть VoIP, не обычный APNs)
2. Проверьте topic: `com.securewavenew.app.voip`
3. Проверьте environment: `production = false` для development

### CallKit не показывается
1. Проверьте payload VoIP push (должен содержать callId, callerName)
2. Проверьте логи в `AppDelegate.swift`
3. Убедитесь что приложение имеет разрешения

## 📚 Документация

Полная документация: [IOS_VOIP_SETUP.md](./IOS_VOIP_SETUP.md)

## 🆘 Нужна помощь?

Проверьте:
1. Entitlements настроены правильно
2. App ID в Developer Portal имеет VoIP capability
3. Bundle ID совпадает с сертификатом
4. Тестируете на реальном устройстве (не симулятор!)
