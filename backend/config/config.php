<?php
// backend/config/config.php

/**
 * Загрузка переменных окружения из .env файла
 */
if (!function_exists('loadEnv')) {
    function loadEnv($path) {
        if (!file_exists($path)) {
            return;
        }
        
        $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        
        foreach ($lines as $line) {
            // Пропускаем комментарии
            if (strpos(trim($line), '#') === 0) {
                continue;
            }
            
            // Разбираем строку KEY=VALUE
            if (strpos($line, '=') !== false) {
                list($key, $value) = explode('=', $line, 2);
                $key = trim($key);
                $value = trim($value);
                
                // Убираем кавычки если есть
                if ((substr($value, 0, 1) === '"' && substr($value, -1) === '"') ||
                    (substr($value, 0, 1) === "'" && substr($value, -1) === "'")) {
                    $value = substr($value, 1, -1);
                }
                
                // Устанавливаем в $_ENV и putenv для совместимости
                $_ENV[$key] = $value;
                putenv("$key=$value");
            }
        }
    }
}

// Загружаем .env из родительской директории
loadEnv(dirname(__DIR__) . '/.env');

/**
 * Вспомогательная функция для получения значений из ENV
 */
if (!function_exists('env')) {
    function env($key, $default = null) {
        $value = $_ENV[$key] ?? getenv($key);
        
        if ($value === false) {
            return $default;
        }
        
        // Преобразуем строковые значения true/false в boolean
        if (strtolower($value) === 'true') {
            return true;
        }
        if (strtolower($value) === 'false') {
            return false;
        }
        
        return $value;
    }
}

return [
    'database' => [
        'host' => env('DB_HOST'),
        'port' => env('DB_PORT'),
        'database' => env('DB_NAME'),
        'username' => env('DB_USER'),
        'password' => env('DB_PASSWORD')
    ],
    
    'jwt' => [
        'secret' => env('JWT_SECRET'),
        'expiration' => env('JWT_EXPIRATION', 86400) // 24 часа по умолчанию
    ],
    
    'websocket' => [
        'port' => env('WEBSOCKET_PORT', 8080)
    ]
];