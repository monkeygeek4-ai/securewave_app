# 🔑 Создание .p8 Auth Key для VoIP Push (ПРОСТОЙ СПОСОБ)

## Почему .p8 лучше чем .p12?

- ✅ НЕ НУЖЕН CSR
- ✅ Не истекает (работает вечно)
- ✅ Один ключ для всех ваших приложений
- ✅ Нет ошибок импорта в Keychain
- ✅ Проще настраивать на backend

## 📝 Пошаговая инструкция

### Шаг 1: Откройте Apple Developer Portal

Перейдите по ссылке:
https://developer.apple.com/account/resources/authkeys/list

### Шаг 2: Создайте новый ключ

1. Нажмите **➕** (большой синий плюс вверху справа)

2. Заполните форму:
   - **Key Name:** `SecureWave APNs Key` (или любое имя)
   - Отметьте галочку: ✅ **Apple Push Notifications service (APNs)**

3. Нажмите **Continue**

4. Нажмите **Register**

### Шаг 3: ВАЖНО - Скачайте ключ

⚠️ **ВНИМАНИЕ:** Файл можно скачать ТОЛЬКО ОДИН РАЗ!

1. Нажмите **Download**
   - Скачается файл: `AuthKey_XXXXXXXXXX.p8`

2. **ЗАПИШИТЕ** (скриншот или скопируйте):
   - **Key ID:** `AB12CD34EF` (10 символов)
   - **Team ID:** `XYZ123ABC4` (находится в правом верхнем углу)

3. Сохраните файл в безопасное место:
   ```bash
   # Создайте папку для сертификатов
   mkdir -p ~/SecureWave_Certificates

   # Переместите скачанный файл
   mv ~/Downloads/AuthKey_*.p8 ~/SecureWave_Certificates/
   ```

### Шаг 4: Готово!

Теперь у вас есть:
- ✅ Файл `AuthKey_XXXXXXXXXX.p8`
- ✅ Key ID
- ✅ Team ID

## 🖥️ Использование на Backend

### В файле `/utils/VoIPPush.php` используйте:

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
        // Используем .p8 файл
        $authProvider = AuthProvider\Token::create([
            'key_id' => 'AB12CD34EF',        // ← ЗАМЕНИТЕ на ваш Key ID
            'team_id' => 'XYZ123ABC4',       // ← ЗАМЕНИТЕ на ваш Team ID
            'app_bundle_id' => 'com.securewavenew.app.voip',
            'private_key_path' => __DIR__ . '/../certificates/AuthKey_XXXXXXXXXX.p8' // ← путь к .p8
        ]);

        // false = development, true = production
        $this->client = new Client($authProvider, $production = false);
    }

    public function sendIncomingCall($voipToken, $callId, $callerName, $callType = 'audio') {
        error_log("[VoIP] Sending push: callId=$callId, caller=$callerName");

        $payload = Payload::create()
            ->setCustomValue('callId', $callId)
            ->setCustomValue('callerName', $callerName)
            ->setCustomValue('callType', $callType)
            ->setCustomValue('timestamp', time());

        $notification = new Notification($payload, $voipToken);
        $notification->setTopic('com.securewavenew.app.voip');

        try {
            $responses = $this->client->push([$notification]);

            foreach ($responses as $response) {
                if ($response->getStatusCode() === 200) {
                    error_log("[VoIP] ✅ Push sent successfully");
                    return true;
                } else {
                    error_log("[VoIP] ❌ Failed: " . $response->getReasonPhrase());
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

### Загрузите .p8 на сервер:

```bash
# Загрузите файл на ваш backend сервер
scp ~/SecureWave_Certificates/AuthKey_*.p8 user@your-server.com:/path/to/backend/certificates/

# Установите правильные права доступа
ssh user@your-server.com "chmod 600 /path/to/backend/certificates/AuthKey_*.p8"
```

## ✅ Готово!

Теперь:
1. ✅ У вас есть .p8 ключ
2. ✅ Никаких ошибок импорта
3. ✅ Ключ работает вечно (не нужно обновлять)
4. ✅ Один ключ для VoIP, FCM и всех push уведомлений

## 📋 Что дальше?

1. Сохраните .p8 файл в надёжное место (он нужен для backend)
2. Запишите Key ID и Team ID
3. Переходите к настройке backend: [SETUP_CHECKLIST.md](SETUP_CHECKLIST.md#шаг-5-создать-класс-для-отправки-voip-push-5-минут)

## ⚠️ Важно!

- Файл .p8 можно скачать ТОЛЬКО ОДИН РАЗ
- Если потеряли - придётся создавать новый ключ
- Храните .p8 в безопасном месте (это как пароль)
- Не коммитьте .p8 в Git!

## 🆘 Проблемы?

### "Не могу найти скачанный файл"
```bash
# Поиск файла
find ~/Downloads -name "AuthKey_*.p8" -mtime -1

# Или посмотрите в папку Downloads
ls -la ~/Downloads/AuthKey_*.p8
```

### "Забыл Key ID"
Зайдите снова на https://developer.apple.com/account/resources/authkeys/list - там указан Key ID

### "Забыл Team ID"
Любая страница Apple Developer → правый верхний угол → ваше имя → там указан Team ID
