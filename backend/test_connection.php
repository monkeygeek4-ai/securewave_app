<?php
// backend/test_user.php
// Скрипт для создания/обновления пользователей с правильными паролями

require_once __DIR__ . '/lib/Database.php';

$db = Database::getInstance();

echo "=== Тест подключения к базе данных ===\n";

try {
    // Проверяем подключение
    if ($db->isConnected()) {
        echo "✅ Подключение к базе данных успешно\n\n";
    } else {
        echo "❌ Не удалось подключиться к базе данных\n";
        exit(1);
    }
    
    // Показываем существующих пользователей
    echo "=== Существующие пользователи ===\n";
    $users = $db->fetchAll("SELECT id, username, email, created_at FROM users ORDER BY id");
    
    if (empty($users)) {
        echo "В базе данных нет пользователей\n\n";
    } else {
        foreach ($users as $user) {
            echo "ID: {$user['id']}, Username: {$user['username']}, Email: {$user['email']}, Created: {$user['created_at']}\n";
        }
        echo "\n";
    }
    
    // Создаем/обновляем пользователей с правильными паролями
    echo "=== Создание/обновление пользователей ===\n";
    
    $testUsers = [
        [
            'username' => 'админ',
            'email' => 'admin@example.com',
            'password' => 'Админ123!',
            'full_name' => 'Администратор'
        ],
        [
            'username' => 'тест',
            'email' => 'test@example.com', 
            'password' => 'Тест123!',
            'full_name' => 'Тестовый пользователь'
        ],
        // Добавим также английские варианты для совместимости
        [
            'username' => 'admin',
            'email' => 'admin2@example.com',
            'password' => 'Admin123!',
            'full_name' => 'Administrator'
        ],
        [
            'username' => 'test',
            'email' => 'test2@example.com',
            'password' => 'Test123!',
            'full_name' => 'Test User'
        ]
    ];
    
    foreach ($testUsers as $userData) {
        // Проверяем, существует ли пользователь
        $existing = $db->fetchOne(
            "SELECT id, username FROM users WHERE username = :username",
            ['username' => $userData['username']]
        );
        
        if ($existing) {
            echo "⚠️  Пользователь '{$userData['username']}' уже существует (ID: {$existing['id']})\n";
            
            // Обновляем пароль для существующего пользователя
            $passwordHash = password_hash($userData['password'], PASSWORD_DEFAULT);
            $db->execute(
                "UPDATE users SET 
                    password_hash = :password_hash,
                    email = :email,
                    full_name = :full_name
                WHERE username = :username",
                [
                    'password_hash' => $passwordHash,
                    'email' => $userData['email'],
                    'full_name' => $userData['full_name'],
                    'username' => $userData['username']
                ]
            );
            echo "   ✅ Пароль обновлен на: {$userData['password']}\n";
            echo "   Email: {$userData['email']}\n\n";
        } else {
            // Создаем нового пользователя
            $passwordHash = password_hash($userData['password'], PASSWORD_DEFAULT);
            
            // Проверяем, не занят ли email
            $emailExists = $db->fetchOne(
                "SELECT id FROM users WHERE email = :email",
                ['email' => $userData['email']]
            );
            
            if ($emailExists) {
                echo "⚠️  Email {$userData['email']} уже используется, пропускаем создание пользователя {$userData['username']}\n\n";
                continue;
            }
            
            $userId = $db->insert(
                "INSERT INTO users (username, email, password_hash, full_name, created_at) 
                 VALUES (:username, :email, :password_hash, :full_name, NOW())
                 RETURNING id",
                [
                    'username' => $userData['username'],
                    'email' => $userData['email'],
                    'password_hash' => $passwordHash,
                    'full_name' => $userData['full_name']
                ]
            );
            
            if ($userId) {
                echo "✅ Создан пользователь '{$userData['username']}' (ID: $userId)\n";
                echo "   Email: {$userData['email']}\n";
                echo "   Пароль: {$userData['password']}\n\n";
            } else {
                echo "❌ Не удалось создать пользователя {$userData['username']}\n\n";
            }
        }
    }
    
    echo "=== Проверка авторизации ===\n";
    
    // Проверяем авторизацию для основных пользователей
    $testLogins = [
        ['username' => 'админ', 'password' => 'Админ123!'],
        ['username' => 'тест', 'password' => 'Тест123!'],
        ['username' => 'admin', 'password' => 'Admin123!'],
        ['username' => 'test', 'password' => 'Test123!']
    ];
    
    foreach ($testLogins as $login) {
        $user = $db->fetchOne(
            "SELECT id, username, password_hash FROM users WHERE username = :username",
            ['username' => $login['username']]
        );
        
        if ($user) {
            if (password_verify($login['password'], $user['password_hash'])) {
                echo "✅ Логин: '{$login['username']}', Пароль: '{$login['password']}' - РАБОТАЕТ\n";
            } else {
                echo "❌ Логин: '{$login['username']}', Пароль: '{$login['password']}' - НЕ РАБОТАЕТ\n";
                
                // Пересоздаем хеш
                $newHash = password_hash($login['password'], PASSWORD_DEFAULT);
                $db->execute(
                    "UPDATE users SET password_hash = :password_hash WHERE id = :id",
                    ['password_hash' => $newHash, 'id' => $user['id']]
                );
                echo "   🔄 Хеш пароля обновлен, попробуйте снова\n";
            }
        } else {
            echo "⚠️  Пользователь '{$login['username']}' не существует\n";
        }
    }
    
    echo "\n=== ГОТОВО ===\n";
    echo "Вы можете войти в приложение с:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "Логин: админ    Пароль: Админ123!\n";
    echo "Логин: тест     Пароль: Тест123!\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    echo "Или с английскими вариантами:\n";
    echo "Логин: admin    Пароль: Admin123!\n";
    echo "Логин: test     Пароль: Test123!\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    
} catch (Exception $e) {
    echo "❌ Ошибка: " . $e->getMessage() . "\n";
    echo "Trace: " . $e->getTraceAsString() . "\n";
    exit(1);
}