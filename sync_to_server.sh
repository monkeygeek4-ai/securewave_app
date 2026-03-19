#!/bin/bash

# Скрипт для синхронизации файлов с сервером

echo "=========================================="
echo "📤 Синхронизация файлов с сервером"
echo "=========================================="
echo ""

# Настройки
SERVER="sbk_19_ru_usr@securewave.sbk-19.ru"
REMOTE_PATH="~/www/securewave.sbk-19.ru/backend"

# Файлы для загрузки
FILES=(
    "backend/lib/FirebaseAdmin.php"
    "backend/lib/PushNotificationService.php"
)

# Загружаем каждый файл
for file in "${FILES[@]}"; do
    echo "📤 Uploading: $file"
    scp "$file" "$SERVER:$REMOTE_PATH/lib/"
    
    if [ $? -eq 0 ]; then
        echo "✅ Success: $file"
    else
        echo "❌ Failed: $file"
    fi
    echo ""
done

echo "=========================================="
echo "🔄 Перезапуск WebSocket сервера..."
echo "=========================================="
echo ""
echo "Выполните на сервере:"
echo "cd ~/www/securewave.sbk-19.ru/backend"
echo "./start_websocket.sh restart"
echo ""
