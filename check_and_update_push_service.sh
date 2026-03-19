#!/bin/bash
# Скрипт для проверки и обновления PushNotificationService.php на сервере
# Выполните этот скрипт НА СЕРВЕРЕ после загрузки файла

echo "=========================================="
echo "🔍 Проверка PushNotificationService.php"
echo "=========================================="
echo ""

BACKEND_DIR="/var/www/sbk_19_ru_usr/data/www/securewave.sbk-19.ru/backend"
FILE="$BACKEND_DIR/lib/PushNotificationService.php"

# Проверка существования файла
if [ ! -f "$FILE" ]; then
    echo "❌ Файл не найден: $FILE"
    exit 1
fi

echo "✅ Файл найден: $FILE"
echo ""

# Проверка наличия метода getUnreadMessagesCount
if grep -q "getUnreadMessagesCount" "$FILE"; then
    echo "✅ Метод getUnreadMessagesCount найден в файле"
    echo ""
    echo "📋 Строки с методом:"
    grep -n "getUnreadMessagesCount" "$FILE" | head -5
    echo ""
else
    echo "❌ Метод getUnreadMessagesCount НЕ найден в файле"
    echo "   Файл нужно обновить!"
    exit 1
fi

# Проверка прав доступа
echo "📋 Права доступа:"
ls -la "$FILE"
echo ""

# Сброс opcache
echo "=========================================="
echo "🔄 Сброс PHP opcache"
echo "=========================================="
echo ""

PHP_BIN="/var/www/sbk_19_ru_usr/data/bin/php"

if [ -f "$PHP_BIN" ]; then
    echo "Используем PHP: $PHP_BIN"
    $PHP_BIN -r "if (function_exists('opcache_reset')) { opcache_reset(); echo '✅ opcache_reset() выполнен\n'; } else { echo '⚠️ opcache_reset() недоступен\n'; }"
    
    # Инвалидация конкретного файла
    $PHP_BIN -r "if (function_exists('opcache_invalidate')) { opcache_invalidate('$FILE', true); echo '✅ opcache_invalidate() для файла выполнен\n'; }"
else
    echo "⚠️ PHP не найден по пути: $PHP_BIN"
    echo "Попробуем стандартный php:"
    php -r "if (function_exists('opcache_reset')) { opcache_reset(); echo '✅ opcache_reset() выполнен\n'; } else { echo '⚠️ opcache_reset() недоступен\n'; }"
fi

echo ""

# Перезапуск PHP-FPM (если доступен)
echo "=========================================="
echo "🔄 Перезапуск PHP-FPM (опционально)"
echo "=========================================="
echo ""

if command -v systemctl &> /dev/null; then
    echo "Попытка перезапуска через systemctl..."
    sudo systemctl restart php8.3-fpm 2>/dev/null || sudo systemctl restart php-fpm 2>/dev/null || echo "⚠️ Не удалось перезапустить PHP-FPM"
elif command -v service &> /dev/null; then
    echo "Попытка перезапуска через service..."
    sudo service php8.3-fpm restart 2>/dev/null || sudo service php-fpm restart 2>/dev/null || echo "⚠️ Не удалось перезапустить PHP-FPM"
else
    echo "⚠️ systemctl и service недоступны, пропускаем перезапуск PHP-FPM"
fi

echo ""

# Проверка логов
echo "=========================================="
echo "📋 Проверка логов"
echo "=========================================="
echo ""

LOG_DIR="$BACKEND_DIR/logs"
if [ -d "$LOG_DIR" ]; then
    echo "✅ Папка логов найдена: $LOG_DIR"
    echo ""
    echo "📋 Последние логи push-уведомлений:"
    find "$LOG_DIR" -name "push_notifications_*.log" -type f -mtime -1 | head -1 | xargs tail -20 2>/dev/null || echo "   (логи не найдены)"
else
    echo "⚠️ Папка логов не найдена: $LOG_DIR"
    echo "   Создаем папку..."
    mkdir -p "$LOG_DIR"
    chmod 777 "$LOG_DIR"
    echo "✅ Папка создана"
fi

echo ""
echo "=========================================="
echo "✅ Проверка завершена!"
echo "=========================================="
echo ""
echo "📝 Следующие шаги:"
echo "1. Отправьте тестовое сообщение с веб-версии на iOS"
echo "2. Проверьте логи:"
echo "   tail -f $LOG_DIR/push_notifications_*.log"
echo ""
echo "3. Или проверьте error_log:"
echo "   tail -f /var/log/php-fpm/error.log | grep -i 'getUnreadMessagesCount\|unreadCount\|badge'"
echo ""

