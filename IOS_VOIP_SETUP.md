# iOS VoIP Push Notifications Setup Guide

## ✅ Что уже настроено в приложении

### 1. iOS Native код
- ✅ `AppDelegate.swift` - настроен PushKit для VoIP push
- ✅ `CallKitManager.swift` - управление CallKit UI
- ✅ `AudioSessionManager.swift` - управление аудио сессией
- ✅ `Runner.entitlements` - добавлены разрешения VoIP

### 2. Flutter код
- ✅ `IOSCallKitHelper` - обертка для работы с CallKit
- ✅ `IOSCallKitHandler` - обработчик событий CallKit
- ✅ `ApiService.registerVoIPToken()` - регистрация VoIP токена на backend
- ✅ Автоматическая инициализация в `main.dart`

### 3. Разрешения (Entitlements)
```xml
<key>com.apple.developer.pushkit.unrestricted-voip</key>
<true/>
<key>aps-environment</key>
<string>development</string>
```

## 🔧 Что нужно настроить

### 1. Apple Developer Portal

#### a) Создать VoIP Push Certificate
1. Перейдите в [Apple Developer Portal](https://developer.apple.com/account/)
2. Certificates, Identifiers & Profiles → Certificates → ➕
3. Выберите **"VoIP Services Certificate"**
4. Выберите ваш App ID (`com.securewavenew.app`)
5. Загрузите Certificate Signing Request (CSR)
6. Скачайте сертификат (.cer файл)

#### b) Конвертировать сертификат в .p12
```bash
# 1. Импортируйте .cer в Keychain Access
# 2. Экспортируйте как .p12 с паролем
# 3. Или через командную строку:

# Конвертировать .cer в .pem
openssl x509 -in voip_cert.cer -inform DER -out voip_cert.pem

# Получить приватный ключ из keychain
# Экспортируйте из Keychain Access → My Certificates → Export

# Объединить в .p12
openssl pkcs12 -export -out voip_push.p12 -inkey private_key.pem -in voip_cert.pem
```

### 2. Backend Integration

#### Установите PHP библиотеку для APNs
```bash
composer require edamov/pushok
```

#### Создайте файл `/notifications/register-voip.php`
```php
<?php
require_once '../config/database.php';
require_once '../middleware/auth_middleware.php';

header('Content-Type: application/json');

// Аутентификация
$user = authenticate();
if (!$user) {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

$data = json_decode(file_get_contents('php://input'), true);
$voipToken = $data['token'] ?? null;
$platform = $data['platform'] ?? 'ios';

if (!$voipToken) {
    echo json_encode(['success' => false, 'error' => 'Token required']);
    exit;
}

try {
    $pdo = getDBConnection();

    // Удаляем старые токены этого пользователя
    $stmt = $pdo->prepare("
        DELETE FROM push_tokens
        WHERE user_id = ? AND platform = ? AND type = 'voip'
    ");
    $stmt->execute([$user['id'], $platform]);

    // Добавляем новый токен
    $stmt = $pdo->prepare("
        INSERT INTO push_tokens (user_id, token, platform, type, created_at)
        VALUES (?, ?, ?, 'voip', NOW())
    ");
    $stmt->execute([$user['id'], $voipToken, $platform]);

    $tokenId = $pdo->lastInsertId();

    echo json_encode([
        'success' => true,
        'tokenId' => $tokenId
    ]);
} catch (Exception $e) {
    error_log("VoIP token registration error: " . $e->getMessage());
    echo json_encode(['success' => false, 'error' => 'Database error']);
}
```

#### Создайте таблицу для токенов (если еще нет)
```sql
CREATE TABLE IF NOT EXISTS push_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL,
    type VARCHAR(20) DEFAULT 'fcm',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_token (user_id, platform, type),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

#### Обновите отправку VoIP push уведомлений

Создайте файл `/utils/voip_push.php`:
```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

use Pushok\AuthProvider;
use Pushok\Client;
use Pushok\Notification;
use Pushok\Payload;
use Pushok\Payload\Alert;

class VoIPPushSender {
    private $client;

    public function __construct() {
        // Используйте .p8 файл (рекомендуется) или .p12

        // Вариант 1: .p8 файл (Token-based)
        $authProvider = AuthProvider\Token::create([
            'key_id' => 'YOUR_KEY_ID',
            'team_id' => 'YOUR_TEAM_ID',
            'app_bundle_id' => 'com.securewavenew.app.voip',
            'private_key_path' => __DIR__ . '/../certificates/AuthKey_XXXXX.p8'
        ]);

        // Вариант 2: .p12 файл (Certificate-based)
        // $authProvider = AuthProvider\Certificate::create([
        //     'certificate_path' => __DIR__ . '/../certificates/voip_push.p12',
        //     'certificate_secret' => 'YOUR_P12_PASSWORD'
        // ]);

        $this->client = new Client($authProvider, $production = false);
    }

    public function sendIncomingCall($voipToken, $callId, $callerName, $callType = 'audio') {
        // VoIP payload должен содержать данные о звонке
        $payload = Payload::create()
            ->setCustomValue('callId', $callId)
            ->setCustomValue('callerName', $callerName)
            ->setCustomValue('callType', $callType)
            ->setCustomValue('timestamp', time());

        $notification = new Notification($payload, $voipToken);

        // ВАЖНО: для VoIP используется специальный тип
        $notification->setTopic('com.securewavenew.app.voip');

        try {
            $responses = $this->client->push([$notification]);

            foreach ($responses as $response) {
                if ($response->getStatusCode() === 200) {
                    error_log("VoIP Push sent successfully: $callId");
                    return true;
                } else {
                    error_log("VoIP Push failed: " . $response->getReasonPhrase());
                    return false;
                }
            }
        } catch (Exception $e) {
            error_log("VoIP Push error: " . $e->getMessage());
            return false;
        }

        return false;
    }
}
```

#### Интегрируйте в ваш WebSocket сервер

В вашем файле обработки звонков:
```php
<?php
require_once '../utils/voip_push.php';

function notifyIncomingCall($userId, $callId, $callerName, $callType) {
    $pdo = getDBConnection();

    // Получаем VoIP токен пользователя
    $stmt = $pdo->prepare("
        SELECT token FROM push_tokens
        WHERE user_id = ? AND platform = 'ios' AND type = 'voip'
        ORDER BY created_at DESC LIMIT 1
    ");
    $stmt->execute([$userId]);
    $tokenData = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($tokenData) {
        $voipPush = new VoIPPushSender();
        $result = $voipPush->sendIncomingCall(
            $tokenData['token'],
            $callId,
            $callerName,
            $callType
        );

        if ($result) {
            error_log("VoIP push sent to user: $userId");
        } else {
            error_log("Failed to send VoIP push to user: $userId");
        }
    }
}
```

### 3. Тестирование

#### Шаг 1: Запустите приложение на реальном iOS устройстве
```bash
flutter run --release
```

**ВАЖНО**: VoIP push работает **только на реальных устройствах**, НЕ на симуляторе!

#### Шаг 2: Проверьте регистрацию токена
Смотрите логи в Xcode Console:
```
📱 VoIP Push Token получен!
Token: [64-символьный hex токен]
✅ VoIP token отправлен в Flutter
✅ VoIP токен успешно зарегистрирован на backend
```

#### Шаг 3: Отправьте тестовый VoIP push
Используйте PHP скрипт или curl:
```bash
# Через PHP
php test_voip_push.php [voip_token] [callId] [callerName]

# Или используйте утилиту командной строки
```

#### Шаг 4: Проверьте работу
1. Закройте приложение полностью (смахните из App Switcher)
2. Отправьте VoIP push с сервера
3. Должен появиться нативный CallKit UI

## 📋 Checklist

- [ ] VoIP Certificate создан в Apple Developer Portal
- [ ] Сертификат конвертирован в .p12 или .p8
- [ ] Backend endpoint `/notifications/register-voip.php` создан
- [ ] Таблица `push_tokens` создана в БД
- [ ] `VoIPPushSender` класс настроен с сертификатами
- [ ] Приложение запущено на реальном устройстве
- [ ] VoIP токен успешно зарегистрирован
- [ ] Тестовый push отправлен и получен

## 🐛 Troubleshooting

### Токен не приходит
- Проверьте что приложение запущено на реальном устройстве
- Проверьте entitlements в Xcode (Runner → Signing & Capabilities)
- Проверьте что Bundle ID совпадает с App ID в Developer Portal

### Push не приходит
- Проверьте что используется правильный сертификат (VoIP, не обычный APNs)
- Проверьте topic: должен быть `com.securewavenew.app.voip`
- Проверьте что токен актуальный в БД
- Проверьте логи backend

### CallKit UI не появляется
- Проверьте что payload содержит `callId`, `callerName`, `callType`
- Проверьте логи в AppDelegate.swift → `didReceiveIncomingPushWith`
- Проверьте что `CallKitManager.reportIncomingCall()` вызывается

## 📚 Полезные ссылки

- [Apple PushKit Documentation](https://developer.apple.com/documentation/pushkit)
- [CallKit Documentation](https://developer.apple.com/documentation/callkit)
- [VoIP Best Practices](https://developer.apple.com/documentation/pushkit/responding_to_voip_notifications_from_pushkit)
- [Pushok Library](https://github.com/edamov/pushok)

## 🎯 Следующие шаги

1. Настройте production сертификаты
2. Добавьте обработку ошибок и retry логику
3. Добавьте мониторинг доставки push уведомлений
4. Настройте fallback на обычные APNs если VoIP не доступен
5. Добавьте аналитику звонков
