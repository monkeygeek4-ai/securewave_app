<?php
// backend/config/config.php

/**
 * Загрузка переменных окружения из .env файла
 */
<<<<<<< HEAD
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
=======
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
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
        }
    }
}

// Загружаем .env из родительской директории
loadEnv(dirname(__DIR__) . '/.env');

/**
 * Вспомогательная функция для получения значений из ENV
 */
<<<<<<< HEAD
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
=======
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
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
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
<<<<<<< HEAD
        'secret' => env('JWT_SECRET'),
        'expiration' => env('JWT_EXPIRATION', 86400) // 24 часа по умолчанию
    ],
    
    'websocket' => [
        'port' => env('WEBSOCKET_PORT', 8080)
=======
        'secret' => env('JWT_SECRET'),  // БЕЗ дефолта - ОБЯЗАТЕЛЬНО должен быть в .env!
        'algorithm' => env('JWT_ALGORITHM', 'HS256'),
        'expire_days' => (int)env('JWT_EXPIRE_DAYS', 7)
    ],
    
    'websocket' => [
        'host' => env('WS_HOST', '0.0.0.0'),
        'port' => (int)env('WS_PORT', 8085),
        'auth_timeout' => (int)env('WS_AUTH_TIMEOUT', 10)
    ],
    
    'app' => [
        'name' => env('APP_NAME', 'SecureWave'),
        'debug' => env('APP_DEBUG', false),
        'timezone' => env('APP_TIMEZONE', 'Europe/Moscow'),
        'locale' => env('APP_LOCALE', 'ru_RU')
    ],
    
    'cors' => [
        'allowed_origins' => array_filter(explode(',', env('CORS_ALLOWED_ORIGINS', 'http://localhost:8080,http://localhost:3000,https://securewave.sbk-19.ru'))),
        'allowed_methods' => array_filter(explode(',', env('CORS_ALLOWED_METHODS', 'GET,POST,PUT,DELETE,OPTIONS'))),
        'allowed_headers' => array_filter(explode(',', env('CORS_ALLOWED_HEADERS', 'Content-Type,Authorization,X-Requested-With'))),
        'max_age' => (int)env('CORS_MAX_AGE', 3600)
>>>>>>> 6c0a886a6502e429bdd6288c5188b4477e0387e6
    ]
];