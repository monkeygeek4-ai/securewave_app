#!/usr/bin/env php
<?php
/**
 * Тестовый скрипт для отправки VoIP push уведомлений
 *
 * Использование:
 * php test_voip_push.php [voip_token] [callId] [callerName] [callType]
 *
 * Пример:
 * php test_voip_push.php 1234567890abcdef test-call-123 "Иван Иванов" audio
 */

require_once __DIR__ . '/vendor/autoload.php';

use Pushok\AuthProvider;
use Pushok\Client;
use Pushok\Notification;
use Pushok\Payload;

// ========================================
// НАСТРОЙКИ - ЗАМЕНИТЕ НА СВОИ!
// ========================================

// Вариант 1: Token-based (.p8 файл) - РЕКОМЕНДУЕТСЯ
define('USE_TOKEN_AUTH', true);
define('KEY_ID', 'YOUR_KEY_ID');  // Например: 'AB12CD34EF'
define('TEAM_ID', 'YOUR_TEAM_ID'); // Например: 'XYZ123ABC4'
define('BUNDLE_ID', 'com.securewavenew.app.voip');
define('P8_FILE_PATH', __DIR__ . '/certificates/AuthKey_XXXXX.p8');

// Вариант 2: Certificate-based (.p12 файл)
define('P12_FILE_PATH', __DIR__ . '/certificates/voip_push.p12');
define('P12_PASSWORD', 'YOUR_P12_PASSWORD');

// Используйте development или production
define('IS_PRODUCTION', false);

// ========================================

// Проверяем аргументы
if ($argc < 4) {
    echo "❌ Недостаточно аргументов!\n\n";
    echo "Использование:\n";
    echo "  php test_voip_push.php [voip_token] [callId] [callerName] [callType]\n\n";
    echo "Примеры:\n";
    echo "  php test_voip_push.php 1234567890abcdef test-123 \"John Doe\" audio\n";
    echo "  php test_voip_push.php 1234567890abcdef test-456 \"Jane Smith\" video\n\n";
    exit(1);
}

$voipToken = $argv[1];
$callId = $argv[2];
$callerName = $argv[3];
$callType = $argv[4] ?? 'audio';

echo "========================================\n";
echo "📱 ОТПРАВКА VoIP PUSH УВЕДОМЛЕНИЯ\n";
echo "========================================\n";
echo "VoIP Token: " . substr($voipToken, 0, 20) . "...\n";
echo "Call ID: $callId\n";
echo "Caller Name: $callerName\n";
echo "Call Type: $callType\n";
echo "Environment: " . (IS_PRODUCTION ? 'Production' : 'Development') . "\n";
echo "========================================\n\n";

try {
    // Создаем Auth Provider
    if (USE_TOKEN_AUTH) {
        echo "🔐 Используется Token-based аутентификация (.p8)\n";

        if (!file_exists(P8_FILE_PATH)) {
            throw new Exception("Файл .p8 не найден: " . P8_FILE_PATH);
        }

        $authProvider = AuthProvider\Token::create([
            'key_id' => KEY_ID,
            'team_id' => TEAM_ID,
            'app_bundle_id' => BUNDLE_ID,
            'private_key_path' => P8_FILE_PATH
        ]);
    } else {
        echo "🔐 Используется Certificate-based аутентификация (.p12)\n";

        if (!file_exists(P12_FILE_PATH)) {
            throw new Exception("Файл .p12 не найден: " . P12_FILE_PATH);
        }

        $authProvider = AuthProvider\Certificate::create([
            'certificate_path' => P12_FILE_PATH,
            'certificate_secret' => P12_PASSWORD
        ]);
    }

    // Создаем клиента
    $client = new Client($authProvider, IS_PRODUCTION);
    echo "✅ APNs клиент создан\n\n";

    // Создаем payload для VoIP push
    // ВАЖНО: VoIP push не должен содержать alert/sound/badge!
    $payload = Payload::create()
        ->setCustomValue('callId', $callId)
        ->setCustomValue('callerName', $callerName)
        ->setCustomValue('callType', $callType)
        ->setCustomValue('timestamp', time());

    echo "📦 Payload:\n";
    echo json_encode([
        'callId' => $callId,
        'callerName' => $callerName,
        'callType' => $callType,
        'timestamp' => time()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    echo "\n\n";

    // Создаем уведомление
    $notification = new Notification($payload, $voipToken);

    // КРИТИЧНО: Устанавливаем правильный topic для VoIP
    $notification->setTopic(BUNDLE_ID);

    echo "📤 Отправка VoIP push...\n";

    // Отправляем
    $responses = $client->push([$notification]);

    // Обрабатываем ответы
    foreach ($responses as $response) {
        echo "========================================\n";
        echo "📥 ОТВЕТ ОТ APNs\n";
        echo "========================================\n";
        echo "Status Code: " . $response->getStatusCode() . "\n";
        echo "Reason: " . $response->getReasonPhrase() . "\n";
        echo "APNs ID: " . $response->getApnsId() . "\n";

        if ($response->getStatusCode() === 200) {
            echo "\n✅✅✅ УСПЕШНО! VoIP push отправлен!\n";
            echo "========================================\n\n";
            echo "Теперь:\n";
            echo "1. Закройте приложение на iPhone (смахните из App Switcher)\n";
            echo "2. Через несколько секунд должен появиться CallKit UI\n";
            echo "3. Примите звонок через CallKit\n";
            echo "4. Приложение откроется и начнется звонок\n\n";
        } else {
            echo "\n❌ ОШИБКА! Push не отправлен\n";
            echo "========================================\n\n";

            // Расшифровываем типичные ошибки
            $statusCode = $response->getStatusCode();
            $reason = $response->getReasonPhrase();

            echo "Возможные причины:\n";

            if ($statusCode === 400) {
                echo "- Неверный формат payload\n";
                echo "- Неверный device token\n";
                echo "- Topic не соответствует сертификату\n";
            } elseif ($statusCode === 403) {
                echo "- Неверный сертификат или auth key\n";
                echo "- Topic не соответствует bundle ID\n";
            } elseif ($statusCode === 410) {
                echo "- Device token устарел или недействителен\n";
                echo "- Приложение удалено с устройства\n";
            }

            echo "\nОтладка:\n";
            echo "1. Проверьте что токен актуальный (переустановите приложение)\n";
            echo "2. Проверьте что topic = " . BUNDLE_ID . "\n";
            echo "3. Проверьте что сертификат соответствует bundle ID\n";
            echo "4. Проверьте environment (dev/prod)\n\n";
        }
    }

} catch (Exception $e) {
    echo "\n❌❌❌ КРИТИЧЕСКАЯ ОШИБКА!\n";
    echo "========================================\n";
    echo "Ошибка: " . $e->getMessage() . "\n";
    echo "Файл: " . $e->getFile() . "\n";
    echo "Строка: " . $e->getLine() . "\n";
    echo "========================================\n\n";

    echo "Проверьте:\n";
    echo "1. Установлена ли библиотека pushok: composer require edamov/pushok\n";
    echo "2. Существуют ли файлы сертификатов\n";
    echo "3. Правильные ли настройки в начале файла\n\n";

    exit(1);
}

echo "========================================\n";
echo "Скрипт завершен\n";
echo "========================================\n";
