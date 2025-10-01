<?php
// backend/config/config.php

// Загружаем переменные окружения если есть файл .env
if (file_exists(dirname(__DIR__) . '/.env')) {
    $envFile = dirname(__DIR__) . '/.env';
    $lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    
    foreach ($lines as $line) {
        // Пропускаем комментарии
        if (strpos(trim($line), '#') === 0) {
            continue;
        }
        
        // Разбираем строку
        if (strpos($line, '=') !== false) {
            list($key, $value) = explode('=', $line, 2);
            $key = trim($key);
            $value = trim($value);
            
            // Убираем кавычки если есть
            if ((substr($value, 0, 1) === '"' && substr($value, -1) === '"') ||
                (substr($value, 0, 1) === "'" && substr($value, -1) === "'")) {
                $value = substr($value, 1, -1);
            }
            
            $_ENV[$key] = $value;
        }
    }
}

return [
    // Конфигурация базы данных
    'database' => [
        'host' => $_ENV['DB_HOST'] ?? 'localhost',
        'port' => $_ENV['DB_PORT'] ?? 5432,
        'database' => $_ENV['DB_NAME'] ?? 'securewave_base',
        'username' => $_ENV['DB_USER'] ?? 'securewave_usr',
        'password' => $_ENV['DB_PASSWORD'] ?? 'Rjhjkm432!'
    ],
    
    // Конфигурация JWT
    'jwt' => [
        'secret' => $_ENV['JWT_SECRET'] ?? 'your-secret-key-change-this-in-production',
        'algorithm' => 'HS256',
        'expire_days' => 7
    ],
    
    // Конфигурация WebSocket
    'websocket' => [
        'host' => $_ENV['WS_HOST'] ?? '0.0.0.0',
        'port' => $_ENV['WS_PORT'] ?? 8085,
        'auth_timeout' => 10, // секунды
    ],
    
    // Конфигурация приложения
    'app' => [
        'name' => 'SecureWave',
        'debug' => $_ENV['APP_DEBUG'] ?? true,
        'timezone' => 'Europe/Moscow',
        'locale' => 'ru_RU'
    ],
    
    // CORS настройки
    'cors' => [
        'allowed_origins' => [
            'http://localhost:8080',
            'http://localhost:3000',
            'https://securewave.sbk-19.ru'
        ],
        'allowed_methods' => ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
        'allowed_headers' => ['Content-Type', 'Authorization', 'X-Requested-With'],
        'max_age' => 3600
    ]
];