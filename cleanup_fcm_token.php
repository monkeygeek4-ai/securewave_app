<?php
// Скрипт для удаления старого FCM токена
// Запустите на сервере: php cleanup_fcm_token.php

require_once __DIR__ . '/backend/config/database.php';

try {
    $db = new Database();

    echo "🔍 Проверяем токены для user_id=1...\n\n";

    $tokens = $db->fetchAll(
        "SELECT id, user_id, LEFT(token, 40) as token_start, platform, created_at
         FROM fcm_tokens
         WHERE user_id = 1
         ORDER BY created_at DESC"
    );

    echo "📋 Найдено токенов: " . count($tokens) . "\n";
    foreach ($tokens as $token) {
        echo "  - ID: {$token['id']}, Token: {$token['token_start']}..., Platform: {$token['platform']}, Created: {$token['created_at']}\n";
    }

    echo "\n🗑️  Удаляем старый токен начинающийся с dRNnA3iPxk9SpH_-CvxGDW...\n";

    $result = $db->execute(
        "DELETE FROM fcm_tokens WHERE user_id = :user_id AND token LIKE :token_pattern",
        [
            'user_id' => 1,
            'token_pattern' => 'dRNnA3iPxk9SpH_-CvxGDW%'
        ]
    );

    echo "✅ Удалено токенов: " . $result . "\n\n";

    echo "📋 Оставшиеся токены:\n";
    $remainingTokens = $db->fetchAll(
        "SELECT id, user_id, LEFT(token, 40) as token_start, platform, created_at
         FROM fcm_tokens
         WHERE user_id = 1"
    );

    if (empty($remainingTokens)) {
        echo "  (нет токенов - ожидаем новый FCM токен от iOS)\n";
    } else {
        foreach ($remainingTokens as $token) {
            echo "  - ID: {$token['id']}, Token: {$token['token_start']}..., Platform: {$token['platform']}\n";
        }
    }

    echo "\n✅ Готово! Теперь перезапустите приложение на iPhone чтобы зарегистрировать новый токен.\n";

} catch (Exception $e) {
    echo "❌ Ошибка: " . $e->getMessage() . "\n";
    exit(1);
}
