# ✅ Чеклист настройки iOS VoIP Push

## 📱 Приложение: ГОТОВО ✅

Всё уже настроено в коде:
- ✅ iOS PushKit интеграция
- ✅ CallKit для нативного UI
- ✅ Автоматическая регистрация VoIP токена
- ✅ Обработка входящих звонков
- ✅ Bundle ID: `com.securewavenew.app`

## 🍎 Apple Developer Portal

### Шаг 1: Проверить App ID (2 минуты)

1. Откройте [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)
2. Найдите ваш App ID: `com.securewavenew.app`
3. Откройте его и проверьте что включены:
   - ✅ **Push Notifications**
   - ✅ **Background Modes** (если есть такая опция)

Если нет App ID:
- Нажмите ➕
- Выберите App IDs
- Description: SecureWave
- Bundle ID: `com.securewavenew.app`
- Capabilities: отметьте Push Notifications

### Шаг 2: Создать VoIP Certificate (5 минут)

**Вариант A: .p8 Auth Key (РЕКОМЕНДУЕТСЯ - проще)**

1. Перейдите в [Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Нажмите ➕
3. Key Name: "SecureWave VoIP Push"
4. Отметьте: **Apple Push Notifications service (APNs)**
5. Нажмите Continue → Register
6. **СКАЧАЙТЕ `.p8` файл** (можно скачать только один раз!)
7. **ЗАПОМНИТЕ:**
   - Key ID (например: `AB12CD34EF`)
   - Team ID (в правом верхнем углу, например: `XYZ123ABC4`)

**Вариант B: .p12 Certificate (классический способ)**

1. Перейдите в [Certificates](https://developer.apple.com/account/resources/certificates/list)
2. Нажмите ➕
3. Выберите **VoIP Services Certificate**
4. Выберите App ID: `com.securewavenew.app`
5. Создайте CSR:
   ```
   Keychain Access → Certificate Assistant →
   Request a Certificate from a Certificate Authority

   Email: ваш email
   Common Name: SecureWave VoIP Push
   Saved to disk
   ```
6. Загрузите CSR
7. Скачайте сертификат (.cer)
8. Двойной клик на .cer (импортирует в Keychain)
9. Экспортируйте из Keychain:
   ```
   Keychain Access → My Certificates →
   Найдите "VoIP Services: com.securewavenew.app" →
   Правой кнопкой → Export →
   Формат: .p12
   Пароль: установите и запомните
   ```

### Шаг 3: Проверить Provisioning Profile (опционально)

Если запускаете через Xcode - автоматически создаётся.

Если нужен вручную:
1. [Profiles](https://developer.apple.com/account/resources/profiles/list)
2. ➕ → iOS App Development
3. Выберите App ID и устройства
4. Скачайте и откройте (добавится в Xcode)

## 🖥️ Backend

### Шаг 1: Установить PHP библиотеку (1 минута)

На вашем сервере:
```bash
cd /path/to/your/backend
composer require edamov/pushok
```

### Шаг 2: Загрузить сертификат на сервер (2 минуты)

Создайте папку:
```bash
mkdir -p /path/to/backend/certificates
chmod 700 /path/to/backend/certificates
```

Загрузите туда:
- `.p8` файл (если используете Auth Key) **ИЛИ**
- `.p12` файл (если используете Certificate)

```bash
# Пример
scp ~/Downloads/AuthKey_AB12CD34EF.p8 user@server:/path/to/backend/certificates/
# или
scp ~/Downloads/voip_push.p12 user@server:/path/to/backend/certificates/
```

### Шаг 3: Создать endpoint для регистрации VoIP токенов (3 минуты)

Создайте файл `/notifications/register-voip.php`:

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

    // Удаляем старые токены
    $stmt = $pdo->prepare("
        DELETE FROM push_tokens
        WHERE user_id = ? AND platform = ? AND type = 'voip'
    ");
    $stmt->execute([$user['id'], $platform]);

    // Добавляем новый
    $stmt = $pdo->prepare("
        INSERT INTO push_tokens (user_id, token, platform, type, created_at)
        VALUES (?, ?, ?, 'voip', NOW())
    ");
    $stmt->execute([$user['id'], $voipToken, $platform]);

    echo json_encode([
        'success' => true,
        'tokenId' => $pdo->lastInsertId()
    ]);
} catch (Exception $e) {
    error_log("VoIP token error: " . $e->getMessage());
    echo json_encode(['success' => false, 'error' => 'Database error']);
}
```

### Шаг 4: Проверить/Создать таблицу (1 минута)

```sql
CREATE TABLE IF NOT EXISTS push_tokens (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL,
    type VARCHAR(20) DEFAULT 'fcm',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_token (user_id, platform, type),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### Шаг 5: Создать класс для отправки VoIP push (5 минут)

Создайте файл `/utils/VoIPPush.php`:

```php
<?php
require_once __DIR__ . '/../vendor/autoload.php';

use Pushok\AuthProvider;
use Pushok\Client;
use Pushok\Notification;
use Pushok\Payload;

class VoIPPush {
    private $client;

    public function __construct() {
        // ========================================
        // НАСТРОЙКИ - ЗАМЕНИТЕ НА СВОИ!
        // ========================================

        // Вариант 1: .p8 файл (РЕКОМЕНДУЕТСЯ)
        $authProvider = AuthProvider\Token::create([
            'key_id' => 'YOUR_KEY_ID',           // Например: AB12CD34EF
            'team_id' => 'YOUR_TEAM_ID',         // Например: XYZ123ABC4
            'app_bundle_id' => 'com.securewavenew.app.voip',
            'private_key_path' => __DIR__ . '/../certificates/AuthKey_XXXXX.p8'
        ]);

        // Вариант 2: .p12 файл (если используете сертификат)
        // $authProvider = AuthProvider\Certificate::create([
        //     'certificate_path' => __DIR__ . '/../certificates/voip_push.p12',
        //     'certificate_secret' => 'YOUR_P12_PASSWORD'
        // ]);

        // false = development, true = production
        $this->client = new Client($authProvider, $production = false);
    }

    public function sendIncomingCall($voipToken, $callId, $callerName, $callType = 'audio') {
        error_log("[VoIP] Sending push: callId=$callId, caller=$callerName, type=$callType");

        $payload = Payload::create()
            ->setCustomValue('callId', $callId)
            ->setCustomValue('callerName', $callerName)
            ->setCustomValue('callType', $callType)
            ->setCustomValue('timestamp', time());

        $notification = new Notification($payload, $voipToken);
        $notification->setTopic('com.securewavenew.app.voip'); // ВАЖНО!

        try {
            $responses = $this->client->push([$notification]);

            foreach ($responses as $response) {
                if ($response->getStatusCode() === 200) {
                    error_log("[VoIP] ✅ Push sent successfully");
                    return true;
                } else {
                    error_log("[VoIP] ❌ Push failed: " . $response->getReasonPhrase());
                    return false;
                }
            }
        } catch (Exception $e) {
            error_log("[VoIP] ❌ Exception: " . $e->getMessage());
            return false;
        }

        return false;
    }
}
```

### Шаг 6: Интегрировать в WebSocket обработчик (3 минуты)

В вашем файле где обрабатываются звонки, добавьте:

```php
<?php
require_once __DIR__ . '/utils/VoIPPush.php';

// Когда приходит входящий звонок
function handleIncomingCall($callData) {
    $calleeId = $callData['calleeId'];
    $callerId = $callData['callerId'];
    $callerName = $callData['callerName'];
    $callId = $callData['callId'];
    $callType = $callData['callType'] ?? 'audio';

    // ... ваш существующий код ...

    // Отправляем VoIP push на iOS
    try {
        $pdo = getDBConnection();
        $stmt = $pdo->prepare("
            SELECT token FROM push_tokens
            WHERE user_id = ? AND platform = 'ios' AND type = 'voip'
            ORDER BY created_at DESC LIMIT 1
        ");
        $stmt->execute([$calleeId]);
        $tokenData = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($tokenData) {
            $voipPush = new VoIPPush();
            $result = $voipPush->sendIncomingCall(
                $tokenData['token'],
                $callId,
                $callerName,
                $callType
            );

            if ($result) {
                error_log("VoIP push sent to user $calleeId");
            }
        }
    } catch (Exception $e) {
        error_log("VoIP push error: " . $e->getMessage());
    }
}
```

## 📱 Тестирование

### Шаг 1: Запустить на iPhone (1 минута)

```bash
flutter run --release
```

**ВАЖНО:** VoIP работает ТОЛЬКО на реальных устройствах!

### Шаг 2: Проверить регистрацию токена (2 минуты)

Откройте Xcode Console (Window → Devices and Simulators → выберите устройство → Open Console)

Должны увидеть:
```
📱 VoIP Push Token получен!
Token: 1234567890abcdef...
✅ VoIP токен успешно зарегистрирован на backend
```

Проверьте в БД:
```sql
SELECT * FROM push_tokens WHERE type = 'voip';
```

### Шаг 3: Протестировать звонок (3 минуты)

1. **Закройте приложение ПОЛНОСТЬЮ:**
   - Двойной клик Home (или свайп вверх)
   - Смахните приложение вверх (убить из памяти)

2. **Позвоните с другого устройства**

3. **Должно появиться:**
   - Нативный iOS экран звонка (CallKit UI)
   - Кнопки "Принять" и "Отклонить"
   - Имя звонящего

4. **Нажмите "Принять":**
   - Приложение откроется
   - Начнётся звонок через WebRTC

### Альтернатива: Тестовый скрипт

Используйте готовый скрипт:

```bash
# Отредактируйте test_voip_push.php - укажите ваши данные
nano test_voip_push.php

# Запустите
php test_voip_push.php [voip_token] [callId] [callerName] audio
```

## 🐛 Если что-то не работает

### Токен не регистрируется

**Проверьте логи приложения:**
```bash
flutter run --verbose
```

**Проверьте endpoint:**
```bash
curl -X POST https://your-backend.com/notifications/register-voip.php \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"token":"test123","platform":"ios","type":"voip"}'
```

### Push не приходит

1. **Проверьте сертификат** в `/utils/VoIPPush.php`:
   - Правильный ли путь к файлу?
   - Правильный ли Key ID / Team ID?

2. **Проверьте topic:**
   - Должен быть `com.securewavenew.app.voip`

3. **Проверьте environment:**
   - `$production = false` для development
   - `$production = true` для production

4. **Проверьте токен актуален:**
   - Переустановите приложение
   - Проверьте что новый токен в БД

### CallKit не показывается

1. Проверьте payload в VoIPPush.php
2. Проверьте логи в AppDelegate.swift
3. Убедитесь что entitlements настроены

## ✅ Готово!

После настройки у вас будет:
- ✅ Звонки приходят когда приложение закрыто
- ✅ Нативный iOS интерфейс звонков
- ✅ Экономия батареи
- ✅ Профессиональный UX

## 📚 Полезные ссылки

- Подробная документация: [IOS_VOIP_SETUP.md](IOS_VOIP_SETUP.md)
- Быстрый старт: [QUICK_START_IOS.md](QUICK_START_IOS.md)
- Тестовый скрипт: [test_voip_push.php](test_voip_push.php)
